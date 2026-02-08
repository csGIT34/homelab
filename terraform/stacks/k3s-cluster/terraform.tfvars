proxmox_endpoint  = "https://10.0.10.12:8006"

clone_template_id = 9000

server_node  = "pve-desktop"
agent_node   = "pve-r720"
server_count = 1
agent_count  = 3

server_cores     = 4
server_memory    = 4096
server_disk_size = 50

agent_cores     = 4
agent_memory    = 16384
agent_disk_size = 100

k3s_vlan_id  = 20
k3s_gateway  = "10.0.20.1"
server_ip_base = "10.0.20.10"
agent_ip_base  = "10.0.20.21"

storage_pool = "local-ssd"
