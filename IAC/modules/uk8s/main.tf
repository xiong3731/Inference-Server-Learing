locals {
  # containerd 镜像仓库配置:切到 certs.d 的 host 目录式配置(便于配镜像加速/私有仓库)。
  # master 与 CPU worker 统一注入。
  containerd_registry_setup = <<-EOT
    cat > /etc/containerd/config.toml <<EOF
    version = 3
    imports = ["/etc/containerd/conf.d/*.toml"]

    [plugins.'io.containerd.cri.v1.images'.registry]
      config_path = "/etc/containerd/certs.d"
    EOF
    mkdir -p /etc/containerd/certs.d
  EOT

  # 注入 SSH 公钥的开机脚本(master 与 CPU worker 共用)
  init_script = <<-EOT
    #!/bin/bash
    mkdir -p /root/.ssh
    echo "${var.ssh_public_key}" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    ${local.containerd_registry_setup}
    systemctl restart containerd
  EOT

  # 只有 count > 0 的 GPU 池才生成 worker 块(旧代码里 count=0 等价于不建节点)
  gpu_worker_pools = { for name, pool in var.gpu_node_pools : name => pool if pool.count > 0 }
}

resource "ucloud_uk8s_cluster" "main" {
  name         = "${var.name_prefix}-uk8s"
  vpc_id       = var.vpc_id
  subnet_id    = var.subnet_id
  service_cidr = var.service_cidr
  password     = var.password
  charge_type  = "dynamic"
  k8s_version  = var.k8s_version

  # node 镜像(master 单独用 master_image_id 覆盖);留空则由 UCloud 随机选可用基础镜像
  image_id = var.image_id

  # 对外暴露 API server,方便本地 kubectl/helm 连接
  enable_external_api_server = true

  # 用公钥登录 master
  init_script = local.init_script

  master {
    availability_zones = var.master_zones
    cpu                = var.master_cpu
    memory             = var.master_memory
    machine_type       = var.master_machine_type
    boot_disk_type     = var.master_boot_disk_type
    boot_disk_size     = var.master_boot_disk_size != 0 ? var.master_boot_disk_size : null
    image_id           = var.master_image_id != "" ? var.master_image_id : null
  }

  # GPU 池走 cluster 的 worker 块:官方 provider 只有这里支持 gpu/gpu_type。
  # 两个代价:worker 块是 ForceNew,改 GPU 池会重建整个集群;
  # 且 worker 块没有 init_script,GPU 节点拿不到开机脚本(见 IAC/README 已知限制)。
  dynamic "worker" {
    for_each = local.gpu_worker_pools
    content {
      availability_zone = var.availability_zone
      machine_type      = "G"
      count             = worker.value.count
      cpu               = worker.value.cpu
      memory            = worker.value.memory
      gpu               = worker.value.gpu
      gpu_type          = worker.value.gpu_type
      boot_disk_type    = worker.value.boot_disk_type
      boot_disk_size    = worker.value.boot_disk_size != 0 ? worker.value.boot_disk_size : null
      data_disk_type    = worker.value.data_disk_type
      data_disk_size    = worker.value.data_disk_size
    }
  }
}

# CPU worker 节点池:同构,统一规格 + count
# 用 ucloud_uk8s_node 而不是 cluster 的 worker 块,是为了保住 init_script:
# 官方 worker 块没有 init_script,而 ucloud_uk8s_node 没有 boot_disk_size(系统盘用 API 默认值)。
resource "ucloud_uk8s_node" "cpu" {
  count = var.node_count

  cluster_id        = ucloud_uk8s_cluster.main.id
  availability_zone = var.availability_zone
  subnet_id         = var.subnet_id
  image_id          = var.image_id
  cpu               = var.node_cpu
  memory            = var.node_memory
  machine_type      = var.node_machine_type
  password          = var.password
  charge_type       = "dynamic"
  boot_disk_type    = var.node_boot_disk_type

  data_disk_type             = var.node_data_disk_type
  data_disk_size             = var.node_data_disk_size
  delete_disks_with_instance = true

  init_script = local.init_script
}
