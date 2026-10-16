variable "name_prefix" {
  description = "资源名称前缀"
  type        = string
}

variable "availability_zone" {
  type = string
}

variable "image_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "root_password" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  description = "注入主机的 SSH 公钥列表"
  type        = list(string)
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "private_ip" {
  description = "固定内网 IP,须落在子网范围内"
  type        = string
}

variable "boot_disk_type" {
  type    = string
  default = "cloud_rssd"
}

variable "boot_disk_size" {
  type    = number
  default = 100
}

variable "data_disk_type" {
  type    = string
  default = "cloud_rssd"
}

variable "data_disk_size" {
  type    = number
  default = 100
}

variable "eip_bandwidth" {
  description = "主机外网 EIP 带宽(Mbps)"
  type        = number
  default     = 2
}
