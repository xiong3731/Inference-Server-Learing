# VPC:隔离的私有网络
resource "ucloud_vpc" "main" {
  name        = "${var.name_prefix}-vpc"
  tag         = var.name_prefix
  cidr_blocks = [var.vpc_cidr]
}

# 子网:VPC 内的一段地址
resource "ucloud_subnet" "main" {
  name       = "${var.name_prefix}-subnet"
  tag        = var.name_prefix
  vpc_id     = ucloud_vpc.main.id
  cidr_block = var.subnet_cidr
}

# 安全组:规则由 var.sg_rules 控制(默认放行 TCP/UDP、拒绝 ICMP)
resource "ucloud_security_group" "main" {
  name = "${var.name_prefix}-sg"
  tag  = var.name_prefix

  dynamic "rules" {
    for_each = var.sg_rules
    content {
      port_range = rules.value.port_range
      protocol   = rules.value.protocol
      cidr_block = rules.value.cidr_block
      policy     = rules.value.policy
      priority   = rules.value.priority
    }
  }
}
