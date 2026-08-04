# ---------- 认证 ----------
variable "ucloud_public_key" {
  description = "UCloud API 公钥"
  type        = string
  sensitive   = true
}

variable "ucloud_private_key" {
  description = "UCloud API 私钥"
  type        = string
  sensitive   = true
}

variable "ucloud_project_id" {
  description = "UCloud 项目 ID"
  type        = string
}

# ---------- 地域 ----------
variable "region" {
  description = "地域"
  type        = string
  default     = "cn-wlcb"
}

variable "availability_zone" {
  description = "可用区"
  type        = string
  default     = "cn-wlcb-01"
}

variable "name_prefix" {
  description = "资源名称前缀"
  type        = string
  default     = "tf"
}

# ---------- 网络 ----------
variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

# ---------- 主机 ----------
variable "instance_type" {
  type    = string
  default = "o-standard-4"
}

variable "root_password" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  description = "注入主机 / UK8S 节点的 SSH 公钥"
  type        = string
}

variable "uhost_private_ip" {
  description = "主机固定内网 IP"
  type        = string
  default     = "10.10.0.100"
}

# ---------- UK8S ----------
variable "uk8s_password" {
  type      = string
  sensitive = true
}

variable "uk8s_service_cidr" {
  type    = string
  default = "172.16.0.0/16"
}

variable "uk8s_k8s_version" {
  type    = string
  default = "1.34.5"
}

variable "uk8s_image_name_regex" {
  description = "UK8S 节点镜像名称正则(用 ucloud_uk8s_images 查询)"
  type        = string
  default     = "^Ubuntu 24.04"
}
