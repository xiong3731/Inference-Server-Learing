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

variable "security_group_id" {
  description = "NAT 网关绑定的安全组 ID(NAT 网关必填)"
  type        = string
}

variable "eip_bandwidth" {
  description = "NAT 出口 EIP 带宽(Mbps)"
  type        = number
  default     = 2
}
