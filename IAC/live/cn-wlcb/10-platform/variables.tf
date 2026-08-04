variable "kubeconfig_path" {
  description = "本地 kubeconfig 文件路径(从 UCloud UK8S 集群下载)"
  type        = string
  default     = "../kubeconfig" # 放在地域目录下,与三层同级
}

variable "kubeconfig_context" {
  description = "kubeconfig 中要使用的 context;留空则用 current-context"
  type        = string
  default     = ""
}

# ---------- NVIDIA device-plugin(由 TF 接管启停)----------
variable "device_plugin_enabled" {
  description = "是否启用 nvidia-device-plugin;false 时 DaemonSet 调度 0 个 Pod(禁用)"
  type        = bool
  default     = false
}

variable "device_plugin_image" {
  description = "nvidia-device-plugin 镜像(默认与 UK8S 自带 DS 一致)"
  type        = string
  default     = "uhub.service.ucloud.cn/uk8s/nvidia-k8s-device-plugin:v0.14.1"
}

# ---------- NVIDIA gpu-operator(Helm)----------
variable "gpu_operator_enabled" {
  description = "是否部署 NVIDIA gpu-operator"
  type        = bool
  default     = true
}

variable "gpu_operator_chart_version" {
  description = "gpu-operator Helm chart 版本"
  type        = string
  default     = "v26.3.3"
}

variable "gpu_operator_driver_enabled" {
  description = "由 gpu-operator 安装 NVIDIA driver;节点已预装驱动则设为 false"
  type        = bool
  default     = true
}

# ---------- Prometheus(Helm)----------
variable "prometheus_enabled" {
  description = "是否部署 Prometheus"
  type        = bool
  default     = true
}

variable "prometheus_chart_version" {
  description = "prometheus Helm chart 版本;留空则用 repo 最新版"
  type        = string
  default     = ""
}

variable "prometheus_storage_class" {
  description = "Prometheus / Alertmanager 持久卷的 StorageClass"
  type        = string
  default     = "csi-udisk-rssd"
}

variable "prometheus_server_storage_size" {
  description = "Prometheus server 持久卷大小"
  type        = string
  default     = "20Gi"
}

variable "prometheus_alertmanager_storage_size" {
  description = "Alertmanager 持久卷大小"
  type        = string
  default     = "10Gi"
}

# ---------- Grafana(Helm)----------
variable "grafana_enabled" {
  description = "是否部署 Grafana"
  type        = bool
  default     = true
}

variable "grafana_chart_version" {
  description = "grafana Helm chart 版本;留空则用 repo 最新版"
  type        = string
  default     = ""
}

variable "grafana_storage_class" {
  description = "Grafana 持久卷的 StorageClass(注意 grafana 用 storageClassName)"
  type        = string
  default     = "csi-udisk-rssd"
}

variable "grafana_storage_size" {
  description = "Grafana 持久卷大小"
  type        = string
  default     = "10Gi"
}

variable "grafana_admin_user" {
  description = "Grafana 管理员用户名"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana 管理员密码(生产请改,或改用 existingSecret)"
  type        = string
  default     = "admin123"
  sensitive   = true
}

# ---------- kube-prometheus-stack(Helm)----------
# Prometheus Operator + Prometheus + Alertmanager + Grafana + exporters 一整套,
# 自带 ServiceMonitor / PodMonitor CRD(给 DCGM 等做监控用)。
variable "kps_enabled" {
  description = "是否部署 kube-prometheus-stack"
  type        = bool
  default     = true
}

variable "kps_chart_version" {
  description = "kube-prometheus-stack Helm chart 版本;留空则用 repo 最新版"
  type        = string
  default     = ""
}

variable "kps_storage_class" {
  description = "kps 各组件持久卷的 StorageClass"
  type        = string
  default     = "csi-udisk-rssd"
}

variable "kps_prometheus_retention" {
  description = "Prometheus 数据保留时长"
  type        = string
  default     = "15d"
}

variable "kps_prometheus_retention_size" {
  description = "Prometheus 到达此大小开始淘汰旧数据(留余量,小于 PVC 容量)"
  type        = string
  default     = "45GB"
}

variable "kps_prometheus_storage_size" {
  description = "Prometheus server 持久卷大小"
  type        = string
  default     = "50Gi"
}

variable "kps_alertmanager_storage_size" {
  description = "Alertmanager 持久卷大小"
  type        = string
  default     = "5Gi"
}

variable "kps_grafana_storage_size" {
  description = "Grafana 持久卷大小"
  type        = string
  default     = "10Gi"
}

variable "kps_grafana_admin_user" {
  description = "kps 内 Grafana 管理员用户名"
  type        = string
  default     = "admin"
}

variable "kps_grafana_admin_password" {
  description = "kps 内 Grafana 管理员密码(生产请改,或改用 existingSecret)"
  type        = string
  default     = "admin123"
  sensitive   = true
}

# ---------- DCGM Exporter ServiceMonitor ----------
variable "dcgm_servicemonitor_enabled" {
  description = "是否为 DCGM exporter 创建 ServiceMonitor(需 kps 提供 CRD)"
  type        = bool
  default     = true
}

# ---------- Dragonfly(P2P 镜像加速,Helm)----------
variable "dragonfly_enabled" {
  description = "是否部署 Dragonfly(P2P 镜像加速)"
  type        = bool
  default     = true
}

variable "dragonfly_chart_version" {
  description = "dragonfly Helm chart 版本;留空则用 repo 最新版"
  type        = string
  default     = ""
}

variable "dragonfly_storage_class" {
  description = "Dragonfly 各组件(mysql/redis/seed-client)PVC 的 StorageClass"
  type        = string
  default     = "csi-udisk-rssd"
}

# ---------- 节点拓扑标签 ----------
variable "udisk_topology_zone" {
  description = "打给所有节点的 UDisk CSI 拓扑标签 topology.udisk.csi.ucloud.cn/zone 的值"
  type        = string
  default     = "cn-wlcb-01"
}
