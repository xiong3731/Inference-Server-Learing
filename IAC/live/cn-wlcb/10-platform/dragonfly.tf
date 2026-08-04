# ---------- Dragonfly(P2P 镜像加速,Helm)----------
# 等价于:
#   helm repo add dragonfly https://dragonflyoss.github.io/helm-charts/
#   helm repo update
#   helm install dragonfly dragonfly/dragonfly \
#     -n dragonfly-system --create-namespace --wait -f values.yaml
#
# Dragonfly 通过 dfinit 改写各节点 containerd 的 config.toml,把镜像拉取
# 走 P2P 代理(依赖 00-infra 里节点已配好 certs.d / config_path)。
# 各子 chart(busybox/mysql/redis)镜像与 PVC 分别走 DaoCloud 代理和
# csi-udisk-rssd 存储类。
resource "helm_release" "dragonfly" {
  count = var.dragonfly_enabled ? 1 : 0

  name       = "dragonfly"
  namespace  = "dragonfly-system"
  repository = "https://dragonflyoss.github.io/helm-charts/"
  chart      = "dragonfly"
  version    = var.dragonfly_chart_version != "" ? var.dragonfly_chart_version : null

  create_namespace = true
  wait             = true

  values = [yamlencode({
    # 一行搞定全部组件镜像的国内加速(含 busybox / mysql / redis 子 chart)
    global = {
      imageRegistry = "docker.m.daocloud.io"
      # 全局存储类,mysql/redis 子 chart 与 seed-client 的 PVC 都用它
      storageClass = var.dragonfly_storage_class
    }

    client = {
      metrics = {
        enable = true
      }
      dfinit = {
        enable = true
        config = {
          containerRuntime = {
            containerd = {
              configPath = "/etc/containerd/config.toml"
              # 代理所有仓库;生产建议按需只代理指定 registry
              proxyAllRegistries = true
            }
          }
        }
      }
    }

    seedClient = {
      metrics = {
        enable = true
      }
    }

    scheduler = {
      metrics = {
        enable = true
      }
    }

    manager = {
      metrics = {
        enable = true
      }
    }
  })]
}
