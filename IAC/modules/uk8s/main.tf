locals {
  # containerd 镜像仓库配置:切到 certs.d 的 host 目录式配置(便于配镜像加速/私有仓库)。
  # master 与 CPU worker 统一注入。
  # 已停用:节点改用镜像自带的 containerd 配置。
  # 要恢复:把下面整段取消注释,同时放开 init_script 里标注「containerd」的两行。
  # containerd_registry_setup = <<-EOT
  #   cat > /etc/containerd/config.toml <<EOF
  #   version = 3
  #   imports = ["/etc/containerd/conf.d/*.toml"]
  #
  #   [plugins.'io.containerd.cri.v1.images'.registry]
  #     config_path = "/etc/containerd/certs.d"
  #   EOF
  #   mkdir -p /etc/containerd/certs.d
  # EOT

  # 注入 SSH 公钥的开机脚本(master 与 CPU worker 共用)
  init_script = <<-EOT
    #!/bin/bash
    mkdir -p /root/.ssh
    %{ for key in var.ssh_public_key ~}
    echo "${key}" >> /root/.ssh/authorized_keys
    %{ endfor ~}
    chmod 600 /root/.ssh/authorized_keys
    # containerd:原为 写 config.toml + mkdir certs.d,已停用
    # systemctl restart containerd
  EOT

  # 只有 count > 0 的 GPU 池才生成 worker 块(旧代码里 count=0 等价于不建节点)
  gpu_worker_pools = { for name, pool in var.gpu_node_pools : name => pool if pool.count > 0 }

  # 把 CPU 池展开成"每台节点一个实例"的扁平 map,key 形如 "ubuntu-0" / "centos-2"
  cpu_nodes = merge([
    for pool_name, pool in var.cpu_node_pools : {
      for i in range(pool.count) :
      "${pool_name}-${i}" => merge(pool, { pool = pool_name })
    }
  ]...)
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

# CPU worker 节点:异构,for_each 遍历展开后的每台节点
# 用 ucloud_uk8s_node 而不是 cluster 的 worker 块,是为了保住 init_script:
# 官方 worker 块没有 init_script,而 ucloud_uk8s_node 没有 boot_disk_size(系统盘用 API 默认值)。
resource "ucloud_uk8s_node" "cpu" {
  for_each = local.cpu_nodes

  cluster_id        = ucloud_uk8s_cluster.main.id
  availability_zone = var.availability_zone
  subnet_id         = var.subnet_id
  image_id          = each.value.image_id != "" ? each.value.image_id : var.image_id
  cpu               = each.value.cpu
  memory            = each.value.memory
  machine_type      = each.value.machine_type
  password          = var.password
  charge_type       = "dynamic"
  boot_disk_type    = each.value.boot_disk_type

  data_disk_type             = each.value.data_disk_type
  data_disk_size             = each.value.data_disk_size
  delete_disks_with_instance = true

  init_script = local.init_script
}
