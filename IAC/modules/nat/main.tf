# NAT 网关的出口公网 IP
resource "ucloud_eip" "nat" {
  name          = "${var.name_prefix}-nat-eip"
  tag           = var.name_prefix
  bandwidth     = var.eip_bandwidth
  internet_type = "bgp"
  charge_mode   = "bandwidth"
  charge_type   = "dynamic"
}

# NAT 网关:让子网内主机能主动访问外网
resource "ucloud_nat_gateway" "main" {
  name              = "${var.name_prefix}-nat"
  tag               = var.name_prefix
  vpc_id            = var.vpc_id
  subnet_ids        = [var.subnet_id]
  eip_id            = ucloud_eip.nat.id
  security_group    = var.security_group_id
  enable_white_list = false
}
