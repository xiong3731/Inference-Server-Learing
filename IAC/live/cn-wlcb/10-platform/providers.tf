provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context # 为空则用 kubeconfig 里的 current-context
}

provider "helm" {
  kubernetes = {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}
