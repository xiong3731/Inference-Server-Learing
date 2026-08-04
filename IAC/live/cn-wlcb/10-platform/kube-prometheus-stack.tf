# ---------- kube-prometheus-stack(Helm)----------
# 等价于:
#   helm install kps prometheus-community/kube-prometheus-stack \
#     -n monitoring --create-namespace \
#     -f values-daocloud.yaml
#
# 一整套:Prometheus Operator + Prometheus + Alertmanager + Grafana + exporters,
# 自带 ServiceMonitor / PodMonitor CRD(DCGM 等靠它做监控)。
# 各镜像走 DaoCloud 代理(国内必配)。
resource "helm_release" "kps" {
  count = var.kps_enabled ? 1 : 0

  # dragonfly 提速镜像拉取;gpu_operator 先起,DCGM exporter 才存在,
  # 下方 additionalServiceMonitors 抓的就是它。
  depends_on = [
    helm_release.dragonfly,
    helm_release.gpu_operator,
  ]

  name       = "kps"
  namespace  = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kps_chart_version != "" ? var.kps_chart_version : null

  create_namespace = true

  # 首次安装要拉大量代理镜像 + 创建 3 个 PVC(50Gi+10Gi+10Gi),
  # 默认 5m 超时不够,调大到 15m,避免"慢但成功"被误报为 failed。
  timeout = 900
  wait    = true

  values = [yamlencode({
    # ---------------- Prometheus Operator ----------------
    prometheusOperator = {
      image = {
        registry = "quay.m.daocloud.io"
      }
      admissionWebhooks = {
        patch = {
          image = {
            registry   = "uhub.service.ucloud.cn"
            repository = "xiong/kube-webhook-certgen"
            tag        = "1.8.4"
          }
        }
      }
      prometheusConfigReloader = {
        image = {
          registry = "quay.m.daocloud.io"
        }
      }
      thanosImage = {
        registry = "quay.m.daocloud.io"
      }
    }

    # ---------------- Prometheus Server ----------------
    prometheus = {
      prometheusSpec = {
        image = {
          registry = "quay.m.daocloud.io"
        }
        retention     = var.kps_prometheus_retention      # 数据保留时长
        retentionSize = var.kps_prometheus_retention_size # 到达此大小开始淘汰旧数据
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = var.kps_storage_class
              accessModes      = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = var.kps_prometheus_storage_size
                }
              }
            }
          }
        }
      }

      # 由 chart 渲染的额外 ServiceMonitor(自动带 release=kps label,
      # 且随 kps release 一起管理,规避 kubernetes_manifest 在 plan 阶段
      # 查询 CRD 的时序问题)。这里抓 gpu-operator 里的 DCGM exporter。
      additionalServiceMonitors = var.dcgm_servicemonitor_enabled ? [
        {
          name = "nvidia-dcgm-exporter"
          # 跨命名空间选中 gpu-operator 里的 DCGM service
          namespaceSelector = {
            matchNames = ["gpu-operator"]
          }
          selector = {
            matchLabels = {
              app = "nvidia-dcgm-exporter"
            }
          }
          endpoints = [
            {
              port     = "gpu-metrics" # DCGM service 的端口名(9400)
              interval = "30s"
              path     = "/metrics"
            },
          ]
        },
      ] : []
    }

    # ---------------- Alertmanager ----------------
    alertmanager = {
      alertmanagerSpec = {
        image = {
          registry = "quay.m.daocloud.io"
        }
        storage = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = var.kps_storage_class
              accessModes      = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = var.kps_alertmanager_storage_size
                }
              }
            }
          }
        }
      }
    }

    # ---------------- Grafana(子 chart)----------------
    grafana = {
      adminUser     = var.kps_grafana_admin_user
      adminPassword = var.kps_grafana_admin_password # 生产请改,或用 existingSecret
      image = {
        registry = "docker.m.daocloud.io"
      }
      # Grafana 的 initContainer / sidecar(下载 dashboard 用)
      initChownData = {
        image = {
          registry = "docker.m.daocloud.io"
        }
      }
      sidecar = {
        image = {
          registry = "quay.m.daocloud.io"
        }
      }
      imageRenderer = {
        image = {
          registry = "docker.m.daocloud.io"
        }
      }
      # 下载 gnetId 看板的 init 镜像(curl),走代理避免直连 docker.io
      downloadDashboardsImage = {
        registry = "docker.m.daocloud.io"
      }

      # ---- 通过 gnetId 自动导入 grafana.com 上的看板 ----
      # dashboardProviders 定义 file 方式的 provider,名字(default)要与
      # dashboards 下的一级 key 对应,否则看板 ConfigMap 建了但不会被加载。
      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [
            {
              name            = "default"
              orgId           = 1
              folder          = ""
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            },
          ]
        }
      }
      dashboards = {
        default = {
          # Node Exporter Full 类看板;init 容器会从 grafana.com 下载对应 JSON
          node = {
            gnetId     = 22515
            revision   = 1
            datasource = "Prometheus" # kps 里 Prometheus 数据源默认就叫 Prometheus
          }
        }
      }

      persistence = {
        enabled          = true
        type             = "pvc"
        storageClassName = var.kps_storage_class
        accessModes      = ["ReadWriteOnce"]
        size             = var.kps_grafana_storage_size
      }
    }

    # ---------------- node-exporter(子 chart)----------------
    "prometheus-node-exporter" = {
      image = {
        registry = "quay.m.daocloud.io"
      }
    }

    # ---------------- kube-state-metrics(子 chart)----------------
    "kube-state-metrics" = {
      image = {
        registry = "k8s.m.daocloud.io"
      }
    }
  })]
}
