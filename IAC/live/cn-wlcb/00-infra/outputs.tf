output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_id" {
  value = module.network.subnet_id
}

output "security_group_id" {
  value = module.network.security_group_id
}

output "nat_public_ip" {
  value = module.nat.nat_public_ip
}

output "uhost_public_ip" {
  value = module.uhost.public_ip
}

output "uhost_private_ip" {
  value = module.uhost.private_ip
}

output "uk8s_cluster_id" {
  value = module.uk8s.cluster_id
}

output "uk8s_cluster_name" {
  value = module.uk8s.cluster_name
}

output "uk8s_external_api_server" {
  value = module.uk8s.external_api_server
}

# platform / apps 层通过 remote state 读取,拼 kubeconfig 路径、打标签用
output "region" {
  value = var.region
}
