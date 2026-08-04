# ---------- Grafana(Helm)----------
# 等价于:
#   helm upgrade --install grafana grafana/grafana \
#     -n prometheus --create-namespace \
#     -f grafana-values.yaml
#
# 与 Prometheus 同 namespace(prometheus);各镜像走 DaoCloud 代理;
# 自动把 Prometheus 配成默认数据源。
resource "helm_release" "grafana" {
  count = var.grafana_enabled ? 1 : 0

  # dragonfly 提速;prometheus 先起,grafana 才能把它配成默认数据源。
  depends_on = [
    helm_release.dragonfly,
    helm_release.prometheus,
  ]

  name       = "grafana"
  namespace  = "prometheus"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = var.grafana_chart_version != "" ? var.grafana_chart_version : null

  create_namespace = true

  values = [yamlencode({
    image = {
      registry = "docker.m.daocloud.io" # grafana/grafana(DaoCloud 代理 docker.io)
    }

    # initChownData 等 sidecar 用的 busybox 也走代理,否则可能卡在拉 busybox
    initChownData = {
      image = {
        registry = "docker.m.daocloud.io" # library/busybox
      }
    }
    sidecar = {
      image = {
        registry = "quay.m.daocloud.io" # kiwigrid/k8s-sidecar(在 quay,不是 docker)
      }
    }

    persistence = {
      enabled          = true
      size             = var.grafana_storage_size
      storageClassName = var.grafana_storage_class # 注意 grafana 用的是 storageClassName
    }

    adminUser     = var.grafana_admin_user
    adminPassword = var.grafana_admin_password # 生产请改,或用 existingSecret

    # 自动把上面装的 Prometheus 配成数据源
    datasources = {
      "datasources.yaml" = {
        apiVersion = 1
        datasources = [
          {
            name      = "Prometheus"
            type      = "prometheus"
            access    = "proxy"
            url       = "http://prometheus-server.prometheus.svc.cluster.local"
            isDefault = true
          },
        ]
      }
    }
  })]
}
