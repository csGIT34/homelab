proxmox_endpoint  = "https://10.0.10.12:8006"

server_template_id = 9001
agent_template_id  = 9000

server_node  = "pve-desktop"
agent_node   = "pve-r720"
server_count = 1
agent_count  = 3

server_cores     = 4
server_memory    = 8192
server_disk_size = 50

agent_cores     = 4
agent_memory    = 16384
agent_disk_size = 100

k3s_vlan_id  = 20
k3s_gateway  = "10.0.20.1"
server_ip_base = "10.0.20.10"
agent_ip_base  = "10.0.20.21"

storage_pool = "local-ssd"

ssh_public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDbnmCZMMU6BMdMdSxpVyaG13sD0QSd+63VUECrV/Kt6 zerocool@cachyos"]
