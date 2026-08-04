# ---------- 给所有节点打 UDisk 拓扑标签 ----------
# UDisk CSI 依赖节点带 topology 标签才能正确调度 PVC 到对应可用区。
# 用 data 动态列出所有节点(节点是动态的,勿硬编码节点名),
# 再逐节点用 kubernetes_labels 打标签(server-side apply,只管这一个
# label,不影响节点上其它已有标签)。
data "kubernetes_nodes" "all" {}

resource "kubernetes_labels" "udisk_zone" {
  for_each = toset([
    for node in data.kubernetes_nodes.all.nodes : node.metadata[0].name
  ])

  api_version = "v1"
  kind        = "Node"
  metadata {
    name = each.value
  }
  labels = {
    "topology.udisk.csi.ucloud.cn/zone" = var.udisk_topology_zone
  }

  # 节点若已被别的客户端(如 CSI driver 自身)写过同名 label,强制覆盖。
  force = true
}
