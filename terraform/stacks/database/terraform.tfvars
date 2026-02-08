proxmox_endpoint  = "https://10.0.10.12:8006"

clone_template_id = 9000
target_node       = "pve-r720"

cores     = 4
memory    = 16384
disk_size = 100

vlan_id    = 30
ip_address = "10.0.30.10/24"
gateway    = "10.0.30.1"

storage_pool = "local-ssd"
