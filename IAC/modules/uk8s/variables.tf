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

variable "image_id" {
  description = "UK8S node 镜像 ID(worker 块与 ucloud_uk8s_node 用)。留空由 UCloud 随机选可用基础镜像"
  type        = string
  default     = ""
}

variable "master_image_id" {
  description = "UK8S master 镜像 ID,覆盖 cluster 级 image_id。留空则 master 与 node 同镜像"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "注入 master/worker 的 SSH 公钥列表"
  type        = list(string)
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

# ---------- CPU worker 节点池(异构,每池独立规格/镜像)----------
# key = 池名,value = 该池规格。每池落在独立的 ucloud_uk8s_node 上(为了保住 init_script)
variable "cpu_node_pools" {
  description = "CPU worker 节点池。每个池独立配置数量/规格/镜像,支持异构"
  type = map(object({
    count          = number
    cpu            = number
    memory         = number            # MB
    machine_type   = optional(string, "O")
    image_id       = optional(string, "") # 留空继承 cluster 级 image_id
    boot_disk_type = optional(string, "cloud_rssd")
    data_disk_type = optional(string, "cloud_rssd")
    data_disk_size = optional(number, 100)
  }))
  default = {}
}

# ---------- GPU 节点池(异构,每池独立规格)----------
# key = 池名,value = 该池规格。落到 cluster 的 worker 块上
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
