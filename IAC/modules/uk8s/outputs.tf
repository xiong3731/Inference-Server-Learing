output "cluster_id" {
  value = ucloud_uk8s_cluster.main.id
}

output "cluster_name" {
  value = ucloud_uk8s_cluster.main.name
}

output "api_server" {
  description = "内网 API server"
  value       = ucloud_uk8s_cluster.main.api_server
}

output "external_api_server" {
  description = "外网 API server(本地 kubectl 连这个)"
  value       = ucloud_uk8s_cluster.main.external_api_server
}

output "node_ids" {
  description = "CPU worker 节点 ID(按 池名-序号 索引)"
  value       = { for k, n in ucloud_uk8s_node.cpu : k => n.id }
}
