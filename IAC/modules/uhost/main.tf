# 云主机
resource "ucloud_instance" "web" {
  availability_zone = var.availability_zone
  image_id          = var.image_id
  instance_type     = var.instance_type

  # root_password 为 UCloud 建机必填;通过 cloud-init 注入公钥后平时用私钥登录
  root_password = var.root_password

  # cloud-init:开机把公钥写入 root 的 authorized_keys
  user_data = <<-EOT
    #cloud-config
    ssh_authorized_keys:
      - ${var.ssh_public_key}
  EOT

  # 网络(不启用安全组)
  vpc_id     = var.vpc_id
  subnet_id  = var.subnet_id
  private_ip = var.private_ip

  name           = "${var.name_prefix}-uhost"
  tag            = var.name_prefix
  charge_type    = "dynamic"
  boot_disk_type = var.boot_disk_type
  boot_disk_size = var.boot_disk_size

  data_disks {
    size = var.data_disk_size
    type = var.data_disk_type
  }
  delete_disks_with_instance = true

  allow_stopping_for_update = false
}

# 主机外网:独立 EIP 并绑定
resource "ucloud_eip" "web" {
  name          = "${var.name_prefix}-web-eip"
  tag           = var.name_prefix
  bandwidth     = var.eip_bandwidth
  internet_type = "bgp"
  charge_mode   = "bandwidth"
  charge_type   = "dynamic"
}

resource "ucloud_eip_association" "web" {
  eip_id      = ucloud_eip.web.id
  resource_id = ucloud_instance.web.id
}
