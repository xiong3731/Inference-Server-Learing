# ---------- NVIDIA gpu-operator(Helm)----------
# 等价于:
#   helm install gpu-operator nvidia/gpu-operator \
#     -n gpu-operator --create-namespace \
#     --version=v26.3.3 --wait -f values.yaml
#
# 注:原始 values.yaml 里 driver:/toolkit: 各出现两次(YAML 后者覆盖前者,
# 会丢掉 enabled 等字段)。这里把同名键合并成一个,行为/镜像代理都保留。
resource "helm_release" "gpu_operator" {
  count = var.gpu_operator_enabled ? 1 : 0

  # 先禁用 UK8S 自带的 device-plugin,再安装/更新 gpu-operator,
  # 避免两个 device-plugin 同时注册 nvidia.com/gpu 冲突。
  # 同时排在 dragonfly 之后:让 gpu-operator 的一堆大镜像走 P2P 加速。
  depends_on = [
    kubernetes_daemonset.nvidia_device_plugin,
    helm_release.dragonfly,
  ]

  name       = "gpu-operator"
  namespace  = "gpu-operator"
  repository = "https://helm.ngc.nvidia.com/nvidia"
  chart      = "gpu-operator"
  version    = var.gpu_operator_chart_version

  create_namespace = true
  wait             = true

  values = [yamlencode({
    # ---- 组件开关与行为 + DaoCloud 镜像代理(国内必配)----
    operator = {
      repository = "nvcr.m.daocloud.io/nvidia"
    }
    validator = {
      repository = "nvcr.m.daocloud.io/nvidia"
    }
    driver = {
      enabled          = var.gpu_operator_driver_enabled # 宿主机没装驱动就 true,预装驱动改 false
      repository       = "nvcr.m.daocloud.io/nvidia"
      version          = "595.71.05" # 需要指定数据中心驱动版本时打开
      kernelModuleType = "open"      # auto / proprietary / open
      # usePrecompiled   = false       # 预编译内核模块,起得更快,需匹配内核
      manager = {
        repository = "nvcr.m.daocloud.io/nvidia/cloud-native"
      }
    }
    toolkit = {
      enabled    = true # 预装 toolkit / 已配好 nvidia runtime 就 false
      repository = "nvcr.m.daocloud.io/nvidia/k8s"
    }
    cdi = {
      enabled = true # 用 CDI 注入 GPU(新版默认开)
    }
    mig = {
      strategy = "single" # MIG 上报策略:single / mixed
    }
    migManager = {
      enabled    = true
      repository = "nvcr.m.daocloud.io/nvidia/cloud-native"
    }
    dcgmExporter = {
      enabled    = true # 部署 DCGM Exporter 做监控
      repository = "nvcr.m.daocloud.io/nvidia/k8s"
    }
    nfd = {
      enabled = true # 集群已有 NFD 就 false
    }
    devicePlugin = {
      repository = "nvcr.m.daocloud.io/nvidia"
    }
    gfd = {
      repository = "nvcr.m.daocloud.io/nvidia"
    }
    "node-feature-discovery" = {
      image = {
        repository = "k8s.m.daocloud.io/nfd/node-feature-discovery"
      }
    }
  })]
}
