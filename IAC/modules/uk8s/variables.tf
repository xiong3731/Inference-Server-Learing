variable "name_prefix" {
  description = "资源名称前缀"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "availability_zone" {
  description = "worker 节点所在可用区"
  type        = string
}

variable "master_zones" {
  description = "master 三节点可用区列表(需 3 个,可重复)"
  type        = list(string)
}

variable "service_cidr" {
  description = "UK8S service 网段(不可与 VPC 重叠)"
  type        = string
  default     = "172.16.0.0/16"
}

variable "password" {
  description = "节点密码,8-30 位,含大小写/数字/特殊字符至少 2 类"
  type        = string
  sensitive   = true
}

variable "k8s_version" {
  type = string
}

variable "image_name_regex" {
  description = "UK8S 节点镜像名称正则(用 ucloud_uk8s_images 查询匹配)"
  type        = string
  default     = "^Ubuntu 24.04"
}

variable "ssh_public_key" {
  description = "注入 master/worker 的 SSH 公钥"
  type        = string
}

# ---------- master 规格(cpu/memory/machine_type 三元组)----------
variable "master_cpu" {
  description = "master CPU 核数"
  type        = number
  default     = 4
}

variable "master_memory" {
  description = "master 内存 MB"
  type        = number
  default     = 8192
}

variable "master_machine_type" {
  description = "master 机器类型:N / C / O / OS"
  type        = string
  default     = "O"
}

variable "master_boot_disk_type" {
  description = "master 系统盘类型"
  type        = string
  default     = "cloud_rssd"
}

variable "master_boot_disk_size" {
  description = "master 系统盘大小 GB(40-500),0 表示用默认"
  type        = number
  default     = 40
}

# ---------- worker 节点规格 ----------
variable "node_count" {
  description = "worker 节点数量"
  type        = number
  default     = 2
}

variable "node_cpu" {
  description = "worker CPU 核数"
  type        = number
  default     = 4
}

variable "node_memory" {
  description = "worker 内存 MB"
  type        = number
  default     = 16384
}

variable "node_machine_type" {
  description = "CPU worker 机器类型:N / C / O / OS"
  type        = string
  default     = "O"
}

variable "node_boot_disk_type" {
  type    = string
  default = "cloud_rssd"
}

variable "node_boot_disk_size" {
  description = "worker 系统盘大小 GB,0 表示用默认"
  type        = number
  default     = 0
}

variable "node_data_disk_type" {
  type    = string
  default = "cloud_rssd"
}

variable "node_data_disk_size" {
  type    = number
  default = 100
}

# ---------- GPU 节点池(异构,每池独立规格)----------
# key = 池名(用于节点命名与 for_each),value = 该池规格
variable "gpu_node_pools" {
  description = "GPU 节点池。每个池独立配置数量/卡数/CPU/内存/磁盘,支持异构"
  type = map(object({
    count          = number
    cpu            = number
    memory         = number # MB
    gpu            = number # 每台卡数
    gpu_type       = string # 如 3090 / 4090 / T4
    boot_disk_type = optional(string, "cloud_rssd")
    boot_disk_size = optional(number, 40) # 0 = 默认
    data_disk_type = optional(string, "cloud_rssd")
    data_disk_size = optional(number, 100)
  }))
  default = {}
}
