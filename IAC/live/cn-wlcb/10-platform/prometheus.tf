# ---------- Prometheus(Helm)----------
# 等价于:
#   helm install prometheus prometheus-community/prometheus \
#     -n prometheus --create-namespace \
#     -f prometheus-values.yaml
#
# 各镜像走 DaoCloud 代理(国内必配);server / alertmanager 开持久卷。
resource "helm_release" "prometheus" {
  count = var.prometheus_enabled ? 1 : 0

  # 排在 dragonfly 之后,镜像拉取走 P2P 加速。
  depends_on = [helm_release.dragonfly]

  name       = "prometheus"
  namespace  = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = var.prometheus_chart_version != "" ? var.prometheus_chart_version : null

  create_namespace = true
  wait             = false # 对齐原始 helm 命令(未带 --wait)

  values = [yamlencode({
    # ===== 主 chart =====
    server = {
      image = {
        repository = "quay.m.daocloud.io/prometheus/prometheus"
      }
      persistentVolume = {
        enabled      = true
        size         = var.prometheus_server_storage_size
        storageClass = var.prometheus_storage_class
      }
    }
    configmapReload = {
      prometheus = {
        image = {
          repository = "quay.m.daocloud.io/prometheus-operator/prometheus-config-reloader"
        }
      }
    }
    alertmanager = {
      image = {
        repository = "quay.m.daocloud.io/prometheus/alertmanager"
      }
      persistence = {
        enabled      = true
        size         = var.prometheus_alertmanager_storage_size
        storageClass = var.prometheus_storage_class
      }
    }
    "prometheus-node-exporter" = {
      image = {
        registry = "quay.m.daocloud.io"
      }
    }
    "kube-state-metrics" = {
      image = {
        registry = "k8s.m.daocloud.io"
      }
    }
    "prometheus-pushgateway" = {
      image = {
        repository = "quay.m.daocloud.io/prometheus/pushgateway"
      }
    }
  })]
}
