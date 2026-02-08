module "k3s_server" {
  source   = "../../modules/proxmox-vm"
  count    = var.server_count

  name        = "k3s-server-${format("%02d", count.index + 1)}"
  target_node = var.server_node
  vm_id       = 200 + count.index

  clone_template_id = var.clone_template_id
  cores             = var.server_cores
  memory            = var.server_memory
  disk_size         = var.server_disk_size
  storage_pool      = var.storage_pool

  vlan_id    = var.k3s_vlan_id
  ip_address = "${var.server_ip_base}/24"
  gateway    = var.k3s_gateway

  cloud_init_file_id = var.cloud_init_file_id

  tags = ["terraform", "k3s", "server"]
}

module "k3s_agent" {
  source   = "../../modules/proxmox-vm"
  count    = var.agent_count

  name        = "k3s-agent-${format("%02d", count.index + 1)}"
  target_node = var.agent_node
  vm_id       = 210 + count.index

  clone_template_id = var.clone_template_id
  cores             = var.agent_cores
  memory            = var.agent_memory
  disk_size         = var.agent_disk_size
  storage_pool      = var.storage_pool

  vlan_id    = var.k3s_vlan_id
  ip_address = "${cidrhost("10.0.20.0/24", 21 + count.index)}/24"
  gateway    = var.k3s_gateway

  cloud_init_file_id = var.cloud_init_file_id

  tags = ["terraform", "k3s", "agent"]
}
