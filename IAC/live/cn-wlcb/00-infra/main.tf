# 查询最新 Ubuntu 24.04 基础镜像(给独立主机用)
data "ucloud_images" "ubuntu" {
  availability_zone = var.availability_zone
  name_regex        = "^Ubuntu 24.04"
  image_type        = "base"
}

locals {
  # ---------- UK8S 节点规格(直接写在代码里)----------
  # master:系统盘 40G,无数据盘
  uk8s_master = { cpu = 8, memory = 16384, machine_type = "O", boot_disk_size = 40 }

  # CPU worker 池(同构):数据盘 200G,系统盘用官方默认
  uk8s_cpu_worker = {
    count          = 3, cpu = 4, memory = 16384, machine_type = "O"
    data_disk_size = 200
  }

  # GPU worker 池(异构:每池独立规格,数量可大):系统盘 100G,数据盘 200G
  # 加池就在此 map 加一项;count 控制该池节点数
  uk8s_gpu_pools = {
    rtx3090 = {
      count          = 0, cpu = 32, memory = 65536, gpu = 2, gpu_type = "4090"
      boot_disk_size = 100, data_disk_size = 200
      # G 型 GPU 机器不支持 cloud_rssd,用 cloud_ssd
      boot_disk_type = "cloud_ssd", data_disk_type = "cloud_ssd"
    }
    # 示例:再加一种 GPU 池只需取消下一行注释并调整
    # rtx4090 = { count = 4, cpu = 16, memory = 32768, gpu = 1, gpu_type = "4090", boot_disk_size = 100, data_disk_size = 200, boot_disk_type = "cloud_ssd", data_disk_type = "cloud_ssd" }
  }
}

# ---------- 网络:VPC + 子网 + 安全组 ----------
module "network" {
  source = "../../../modules/network"

  name_prefix = var.name_prefix
  vpc_cidr    = var.vpc_cidr
  subnet_cidr = var.subnet_cidr
}

# ---------- NAT 网关 ----------
module "nat" {
  source = "../../../modules/nat"

  name_prefix       = var.name_prefix
  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.subnet_id
  security_group_id = module.network.security_group_id
}

# ---------- 独立云主机 ----------
module "uhost" {
  source = "../../../modules/uhost"

  name_prefix       = var.name_prefix
  availability_zone = var.availability_zone
  image_id          = data.ucloud_images.ubuntu.images[0].id
  instance_type     = var.instance_type
  root_password     = var.root_password
  ssh_public_key    = var.ssh_public_key
  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.subnet_id
  private_ip        = var.uhost_private_ip
}

# ---------- UK8S 集群 ----------
module "uk8s" {
  source = "../../../modules/uk8s"

  name_prefix       = var.name_prefix
  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.subnet_id
  availability_zone = var.availability_zone
  master_zones      = [for _ in range(3) : var.availability_zone] # master 三节点同区
  service_cidr      = var.uk8s_service_cidr
  password          = var.uk8s_password
  k8s_version       = var.uk8s_k8s_version
  image_id          = var.uk8s_node_image_id
  master_image_id   = var.uk8s_master_image_id
  ssh_public_key    = var.ssh_public_key

  # master 规格
  master_cpu            = local.uk8s_master.cpu
  master_memory         = local.uk8s_master.memory
  master_machine_type   = local.uk8s_master.machine_type
  master_boot_disk_size = local.uk8s_master.boot_disk_size

  # CPU worker 池
  node_count          = local.uk8s_cpu_worker.count
  node_cpu            = local.uk8s_cpu_worker.cpu
  node_memory         = local.uk8s_cpu_worker.memory
  node_machine_type   = local.uk8s_cpu_worker.machine_type
  node_data_disk_size = local.uk8s_cpu_worker.data_disk_size

  # GPU worker 池(异构 map)
  gpu_node_pools = local.uk8s_gpu_pools
}
