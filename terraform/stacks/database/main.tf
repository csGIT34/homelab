module "postgres" {
  source = "../../modules/proxmox-vm"

  name        = "postgres-01"
  target_node = var.target_node
  vm_id       = 300

  clone_template_id = var.clone_template_id
  cores             = var.cores
  memory            = var.memory
  disk_size         = var.disk_size
  storage_pool      = var.storage_pool

  vlan_id    = var.vlan_id
  ip_address = var.ip_address
  gateway    = var.gateway

  ssh_public_keys    = var.ssh_public_keys
  cloud_init_file_id = var.cloud_init_file_id

  tags = ["terraform", "database", "postgres"]
}
