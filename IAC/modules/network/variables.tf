variable "name_prefix" {
  description = "资源名称前缀"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "subnet_cidr" {
  description = "子网 CIDR"
  type        = string
}

variable "sg_rules" {
  description = "安全组规则列表。默认放行所有 TCP/UDP、拒绝所有 ICMP"
  type = list(object({
    port_range = optional(string)
    protocol   = string
    cidr_block = string
    policy     = string
    priority   = string
  }))
  default = [
    { port_range = "1-65535", protocol = "tcp", cidr_block = "0.0.0.0/0", policy = "accept", priority = "high" },
    { port_range = "1-65535", protocol = "udp", cidr_block = "0.0.0.0/0", policy = "accept", priority = "high" },
    { protocol = "icmp", cidr_block = "0.0.0.0/0", policy = "drop", priority = "high" },
  ]
}
