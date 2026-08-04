# ============================================================
# SGLang 跨机张量并行推理服务(Qwen3-VL-4B-Instruct)
# ------------------------------------------------------------
# 用原生 kubernetes_* 资源声明,等价于 kubectl apply 以下清单:
#   - Secret        model-s3-credentials  (UFile S3 凭证)
#   - Service       sglang-headless       (Headless,给 Pod 稳定 DNS)
#   - StatefulSet   sglang                (2 副本,跨 2 节点各占 2 卡)
#   - Service       sglang-service        (只路由到 rank 0,对外提供 API)
#
# 拓扑:replicas=2 + podAntiAffinity(hostname) => 两 Pod 各占一台 GPU 机;
#       每 Pod 2 卡,--tp 4 --nnodes 2 => 跨机 4 卡张量并行。
# ============================================================

# ── UFile(S3 兼容)凭证 ──
# 注意:密钥来自 sensitive 变量,请勿把真实值提交到公共仓库,
# 建议放 terraform.tfvars(已 gitignore)或走密钥管理。
resource "kubernetes_secret" "model_s3" {
  metadata {
    name      = "model-s3-credentials"
    namespace = local.namespace
  }
  type = "Opaque"

  # data 传明文,provider 自动 base64(等价于清单里的 stringData)
  data = {
    AWS_ACCESS_KEY_ID     = var.s3_access_key_id
    AWS_SECRET_ACCESS_KEY = var.s3_secret_access_key
    AWS_ENDPOINT_URL      = var.s3_endpoint_url
    AWS_REGION            = var.s3_region
  }
}

# ── Headless Service:给每个 Pod 稳定 DNS(sglang-0.sglang-headless ...)──
resource "kubernetes_service" "sglang_headless" {
  metadata {
    name      = "sglang-headless"
    namespace = local.namespace
  }
  spec {
    cluster_ip                  = "None" # Headless:直接解析到 Pod IP
    publish_not_ready_addresses = true   # 关键:Pod 未 ready 也发布 DNS,否则跨机建链死锁
    selector = {
      app = "sglang"
    }
    port {
      name = "dist"
      port = 5000 # 分布式初始化端口
    }
  }
}

resource "kubernetes_stateful_set_v1" "sglang" {
  metadata {
    name      = "sglang"
    namespace = local.namespace
    labels = {
      app = "sglang"
    }
  }

  # 跨机加载模型 + 建链慢,默认 10min create 超时不够,拉长到 20min
  # (与 startup_probe 最长 ~15min 容忍度对齐,留余量)
  timeouts {
    create = "20m"
    update = "20m"
    delete = "10m"
  }

  spec {
    service_name          = kubernetes_service.sglang_headless.metadata[0].name
    pod_management_policy = "Parallel" # 关键:两 Pod 并行创建;OrderedReady 会等 sglang-0 ready 才建 sglang-1,跨机建链死锁
    replicas              = var.replicas

    selector {
      match_labels = {
        app = "sglang"
      }
    }

    template {
      metadata {
        labels = {
          app = "sglang"
        }
      }

      spec {
        # 反亲和:两个 Pod 必须分散到不同节点,各占一台机器的 2 张卡
        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_labels = {
                  app = "sglang"
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }

        # ① InitContainer:每个 Pod 各自从 UFile 拉权重到自己的 SSD 云盘
        init_container {
          name  = "model-downloader"
          image = var.downloader_image
          command = [
            "/bin/sh",
            "-c",
            <<-EOT
              set -e
              MODEL_DIR=/models/Qwen3-VL-4B-Instruct
              if [ -f "$MODEL_DIR/.download_complete" ]; then
                echo "模型已存在,跳过下载"
                exit 0
              fi
              echo "开始从 UFile 同步模型..."
              aws s3 sync \
                ${var.model_s3_uri} \
                "$MODEL_DIR/" \
                --endpoint-url "$AWS_ENDPOINT_URL"
              touch "$MODEL_DIR/.download_complete"
              echo "下载完成"
            EOT
          ]
          env_from {
            secret_ref {
              name = kubernetes_secret.model_s3.metadata[0].name
            }
          }
          volume_mount {
            name       = "models"
            mount_path = "/models"
          }
        }

        # ② 主容器:从 hostname 解析 node-rank,跨机启动 SGLang
        container {
          name  = "sglang"
          image = var.sglang_image
          command = [
            "/bin/sh",
            "-c",
            # StatefulSet Pod 名形如 sglang-0 / sglang-1,取末尾数字作为 node-rank。
            # 注意:$${HOSTNAME##*-} 的 $$ 是转义,渲染到容器里是单个 $(shell 变量展开)。
            <<-EOT
              NODE_RANK="$${HOSTNAME##*-}"
              echo "本 Pod node-rank=$NODE_RANK"
              exec python3 -m sglang.launch_server \
                --model-path /models/Qwen3-VL-4B-Instruct \
                --tp ${var.tp_size} \
                --nnodes ${var.replicas} \
                --node-rank "$NODE_RANK" \
                --dist-init-addr sglang-0.sglang-headless:5000 \
                --host 0.0.0.0 \
                --port 30000 \
                --trust-remote-code
            EOT
          ]

          # 跨机 NCCL/GLOO 通信选对网卡(UCloud 是 eth0)
          env {
            name  = "GLOO_SOCKET_IFNAME"
            value = var.socket_ifname
          }
          env {
            name  = "NCCL_SOCKET_IFNAME"
            value = var.socket_ifname
          }

          port {
            container_port = 30000
            name           = "http"
          }

          resources {
            limits = {
              "nvidia.com/gpu" = var.gpu_per_pod # 每个 Pod 占本节点 N 张卡
            }
          }

          volume_mount {
            name       = "models"
            mount_path = "/models"
            read_only  = true # 主容器只读挂载
          }
          volume_mount {
            name       = "dshm"
            mount_path = "/dev/shm" # 跨机 TP 的 NCCL 通信依赖大共享内存
          }

          # /health 会跑一次真实生成,耗时数秒;httpGet 默认 timeout=1s 会误判失败,必须调大。
          readiness_probe {
            http_get {
              path = "/health"
              port = 30000
            }
            initial_delay_seconds = 90 # 跨机加载 + 建链慢,给足时间
            period_seconds        = 10
            timeout_seconds       = 10 # 关键:/health 触发生成,1s 不够
            failure_threshold     = 60
          }
          startup_probe {
            http_get {
              path = "/health"
              port = 30000
            }
            initial_delay_seconds = 90
            period_seconds        = 15
            timeout_seconds       = 10
            failure_threshold     = 60 # 最长容忍 ~15 分钟启动
          }
        }

        volume {
          name = "dshm"
          empty_dir {
            medium     = "Memory"
            size_limit = var.shm_size # 等价于 docker --shm-size
          }
        }
      }
    }

    # 每个 Pod 独立申请一块 SSD 云盘(RWO 不可共享)
    volume_claim_template {
      metadata {
        name = "models"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.storage_class
        resources {
          requests = {
            storage = var.model_storage_size
          }
        }
      }
    }
  }
}

# ── 对外 Service:只把流量路由到 rank 0(sglang-0),它才提供 API ──
resource "kubernetes_service" "sglang" {
  metadata {
    name      = "sglang-service"
    namespace = local.namespace
  }
  spec {
    selector = {
      app                                  = "sglang"
      "statefulset.kubernetes.io/pod-name" = "sglang-0" # 精确选中 Master Pod
    }
    port {
      name        = "http"
      port        = 80
      target_port = 30000
    }
    type = "ClusterIP"
  }
}

# ── 对外 LoadBalancer:云厂商分配公网/内网 LB IP,把流量路由到 rank 0 ──
resource "kubernetes_service" "sglang_lb" {
  metadata {
    name      = "sglang-lb"
    namespace = local.namespace
  }
  spec {
    selector = {
      app                                  = "sglang"
      "statefulset.kubernetes.io/pod-name" = "sglang-0" # 只选中 Master Pod,rank>0 不提供 API
    }
    port {
      name        = "http"
      port        = 80
      target_port = 30000
    }
    type = "LoadBalancer"
  }

  # LB 由云控制器异步分配,首次 apply 可能等 IP 较久
  wait_for_load_balancer = true
}
