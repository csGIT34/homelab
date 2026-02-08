module "sandbox_vm" {
  source   = "../../modules/proxmox-vm"
  count    = var.vm_count

  name        = "sandbox-${format("%02d", count.index + 1)}"
  target_node = var.target_node
  vm_id       = 400 + count.index

  clone_template_id = var.clone_template_id
  cores             = var.cores
  memory            = var.memory
  disk_size         = var.disk_size
  storage_pool      = var.storage_pool

  vlan_id    = var.vlan_id
  ip_address = "${cidrhost("10.0.40.0/24", 10 + count.index)}/24"
  gateway    = var.gateway

  cloud_init_file_id = var.cloud_init_file_id
  on_boot            = false

  tags = ["terraform", "sandbox"]
}
