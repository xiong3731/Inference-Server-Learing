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
  description = "注入主机 / UK8S 节点的 SSH 公钥列表,全部追加到 root 的 authorized_keys"
  type        = list(string)
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
  default = "1.26.7"
}

variable "uk8s_master_image_id" {
  description = "UK8S master 镜像 ID(cn-wlcb-01 的 CentOS 7.6 UK8S GPU)。镜像 ID 分分区,换区要改"
  type        = string
  default     = "uimage-f4pwzt"
}

variable "uk8s_node_image_id" {
  description = "UK8S node 池 1(ubuntu)的镜像 ID(cn-wlcb-01 的 Ubuntu 20.04 UK8S GPU),同时作为集群级默认镜像"
  type        = string
  default     = "uimage-16ayzvk7btmf"
}

variable "uk8s_node_image_id_centos" {
  description = "UK8S node 池 2(centos)的镜像 ID(cn-wlcb-01 的 CentOS 7.6 UK8S)"
  type        = string
  default     = "uimage-1wdq0b0l3lpz"
}
