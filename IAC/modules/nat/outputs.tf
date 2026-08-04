output "nat_gateway_id" {
  value = ucloud_nat_gateway.main.id
}

output "nat_public_ip" {
  value = ucloud_eip.nat.public_ip
}
