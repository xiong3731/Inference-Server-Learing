output "vpc_id" {
  value = ucloud_vpc.main.id
}

output "subnet_id" {
  value = ucloud_subnet.main.id
}

output "security_group_id" {
  value = ucloud_security_group.main.id
}
