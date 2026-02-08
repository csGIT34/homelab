proxmox_endpoint  = "https://10.0.10.12:8006"

clone_template_id = 9000
target_node       = "pve-r720"

vm_count  = 0
cores     = 2
memory    = 4096
disk_size = 30

vlan_id  = 40
gateway  = "10.0.40.1"
ip_base  = "10.0.40.10"

storage_pool = "local-ssd"
