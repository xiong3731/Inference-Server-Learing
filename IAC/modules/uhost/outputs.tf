output "instance_id" {
  value = ucloud_instance.web.id
}

output "public_ip" {
  description = "主机外网 IP(用私钥 SSH:ssh root@<此IP>)"
  value       = ucloud_eip.web.public_ip
}

output "private_ip" {
  value = ucloud_instance.web.private_ip
}
