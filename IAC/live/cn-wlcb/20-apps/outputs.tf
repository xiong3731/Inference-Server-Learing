output "namespace" {
  description = "推理服务所在命名空间"
  value       = local.namespace
}

output "service_name" {
  description = "对外 Service 名(只路由到 rank 0)"
  value       = kubernetes_service.sglang.metadata[0].name
}

output "service_cluster_endpoint" {
  description = "集群内访问地址(HTTP API,端口 80 -> 30000)"
  value       = "${kubernetes_service.sglang.metadata[0].name}.${local.namespace}.svc.cluster.local"
}

output "port_forward_hint" {
  description = "本地调试:端口转发到 rank 0 的 30000"
  value       = "kubectl -n ${local.namespace} port-forward svc/${kubernetes_service.sglang.metadata[0].name} 8000:80"
}
