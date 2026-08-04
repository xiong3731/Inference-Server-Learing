variable "kubeconfig_path" {
  description = "本地 kubeconfig 文件路径"
  type        = string
  default     = "../kubeconfig"
}

variable "kubeconfig_context" {
  description = "kubeconfig context;留空用 current-context"
  type        = string
  default     = ""
}

variable "namespace" {
  description = "推理服务部署的命名空间(由本层创建)"
  type        = string
  default     = "inference"
}

# ---------- 镜像 ----------
variable "sglang_image" {
  description = "SGLang 推理镜像"
  type        = string
  default     = "uhub.service.ucloud.cn/xiong/sglang:v0.5.15.post1"
}

variable "downloader_image" {
  description = "从 UFile 拉模型的 aws-cli 镜像(initContainer)"
  type        = string
  default     = "uhub.service.ucloud.cn/xiong/aws-cli:2.15.0"
}

# ---------- 规模 / 并行 ----------
variable "replicas" {
  description = "副本数,同时作为 SGLang 的 --nnodes(每副本一个节点)"
  type        = number
  default     = 2
}

variable "tp_size" {
  description = "SGLang 张量并行度 --tp(= 总卡数 = replicas * gpu_per_pod)"
  type        = number
  default     = 4
}

variable "gpu_per_pod" {
  description = "每个 Pod 申请的 GPU 卡数(nvidia.com/gpu)"
  type        = number
  default     = 2
}

variable "socket_ifname" {
  description = "跨机 NCCL/GLOO 通信网卡名(UCloud 默认 eth0)"
  type        = string
  default     = "eth0"
}

# ---------- 存储 ----------
variable "storage_class" {
  description = "模型权重 PVC 的 StorageClass"
  type        = string
  default     = "ssd-csi-udisk"
}

variable "model_storage_size" {
  description = "每个 Pod 模型权重卷大小"
  type        = string
  default     = "100Gi"
}

variable "shm_size" {
  description = "/dev/shm 共享内存大小(跨机 TP 的 NCCL 依赖)"
  type        = string
  default     = "32Gi"
}

# ---------- 模型 ----------
variable "model_s3_uri" {
  description = "UFile 上模型权重的 S3 路径(结尾带 /)"
  type        = string
  default     = "s3://xiong3731/llm_model/Qwen/Qwen3-VL-4B-Instruct/"
}

# ---------- UFile(S3 兼容)凭证 ----------
# 安全提示:生产请通过 terraform.tfvars(已 gitignore)或环境变量
# TF_VAR_s3_access_key_id / TF_VAR_s3_secret_access_key 注入,勿提交明文。
variable "s3_access_key_id" {
  description = "UFile Access Key(TOKEN)"
  type        = string
  default     = "TOKEN_04f46c16-332b-45ef-9f81-eb62db8273c1"
  sensitive   = true
}

variable "s3_secret_access_key" {
  description = "UFile Secret Key"
  type        = string
  default     = "804805d5-723b-4aa4-ab6e-d872a5d7899a"
  sensitive   = true
}

variable "s3_endpoint_url" {
  description = "UFile S3 兼容端点(乌兰察布内网)"
  type        = string
  default     = "http://internal.s3-cn-wlcb.ufileos.com"
}

variable "s3_region" {
  description = "UFile 区域"
  type        = string
  default     = "cn-wlcb"
}
