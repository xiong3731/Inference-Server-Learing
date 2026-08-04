locals {
  # containerd 镜像仓库配置:切到 certs.d 的 host 目录式配置(便于配镜像加速/私有仓库)。
  # 所有节点(master / CPU worker / GPU worker)统一注入。
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

  # GPU 节点开机脚本:在注入公钥的基础上,卸载镜像自带的 NVIDIA driver
  # (交给 10-platform 的 gpu-operator 统一安装/管理),然后重启使其生效。
  gpu_init_script = <<-EOT
    #!/bin/bash
    mkdir -p /root/.ssh
    echo "${var.ssh_public_key}" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    ${local.containerd_registry_setup}
    nvidia-uninstall -s
    rm /etc/containerd/conf.d/90-nvidia.toml
    apt purge -y nvidia-container-toolkit nvidia-container-runtime libnvidia-container-tools libnvidia-container1
    reboot
  EOT

  # 把 GPU 节点池 map 展开成"每台节点一个实例"的扁平 map。
  # key 形如 "a100-0" / "a100-1"(池名-序号),value 为该池规格 + 序号。
  gpu_nodes = merge([
    for pool_name, pool in var.gpu_node_pools : {
      for i in range(pool.count) :
      "${pool_name}-${i}" => merge(pool, { pool = pool_name, index = i })
    }
  ]...)
}

# 查询 UK8S 节点镜像(按名字正则匹配),取第一个
data "ucloud_uk8s_images" "selected" {
  availability_zone = var.availability_zone
  name_regex        = var.image_name_regex
}

resource "ucloud_uk8s_cluster" "main" {
  name         = "${var.name_prefix}-uk8s"
  vpc_id       = var.vpc_id
  subnet_id    = var.subnet_id
  service_cidr = var.service_cidr
  password     = var.password
  charge_type  = "dynamic"
  k8s_version  = var.k8s_version
  image_id     = data.ucloud_uk8s_images.selected.images[0].id

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
  }
}

# CPU worker 节点池:同构,统一规格 + count
resource "ucloud_uk8s_node" "cpu" {
  count = var.node_count

  cluster_id        = ucloud_uk8s_cluster.main.id
  availability_zone = var.availability_zone
  subnet_id         = var.subnet_id
  image_id          = data.ucloud_uk8s_images.selected.images[0].id
  cpu               = var.node_cpu
  memory            = var.node_memory
  machine_type      = var.node_machine_type
  password          = var.password
  charge_type       = "dynamic"
  boot_disk_type    = var.node_boot_disk_type
  boot_disk_size    = var.node_boot_disk_size != 0 ? var.node_boot_disk_size : null

  data_disk_type             = var.node_data_disk_type
  data_disk_size             = var.node_data_disk_size
  delete_disks_with_instance = true

  init_script = local.init_script
}

# GPU worker 节点:异构,for_each 遍历展开后的每台节点
resource "ucloud_uk8s_node" "gpu" {
  for_each = local.gpu_nodes

  cluster_id        = ucloud_uk8s_cluster.main.id
  availability_zone = var.availability_zone
  subnet_id         = var.subnet_id
  image_id          = data.ucloud_uk8s_images.selected.images[0].id
  cpu               = each.value.cpu
  memory            = each.value.memory
  machine_type      = "G"
  gpu               = each.value.gpu
  gpu_type          = each.value.gpu_type
  password          = var.password
  charge_type       = "dynamic"
  boot_disk_type    = each.value.boot_disk_type
  boot_disk_size    = each.value.boot_disk_size != 0 ? each.value.boot_disk_size : null

  data_disk_type             = each.value.data_disk_type
  data_disk_size             = each.value.data_disk_size
  delete_disks_with_instance = true

  init_script = local.gpu_init_script
}
