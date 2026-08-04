# 本层自建推理命名空间(不依赖 10-platform,避免耦合不存在的 output)
resource "kubernetes_namespace" "inference" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      purpose                        = "inference"
    }
  }
}

locals {
  namespace = kubernetes_namespace.inference.metadata[0].name
}
