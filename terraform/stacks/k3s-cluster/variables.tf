variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint URL"
}

variable "proxmox_api_token" {
  type        = string
  description = "Proxmox API token (user@realm!token=secret)"
  sensitive   = true
}

variable "server_template_id" {
  type        = number
  description = "VM ID of the template to clone for server nodes"
  default     = 9001
}

variable "agent_template_id" {
  type        = number
  description = "VM ID of the template to clone for agent nodes"
  default     = 9000
}

variable "server_node" {
  type        = string
  description = "Proxmox node for k3s server (control plane)"
  default     = "pve-desktop"
}

variable "agent_node" {
  type        = string
  description = "Proxmox node for k3s agents (workers)"
  default     = "pve-r720"
}

variable "server_count" {
  type        = number
  description = "Number of k3s server (control plane) nodes"
  default     = 1
}

variable "agent_count" {
  type        = number
  description = "Number of k3s agent (worker) nodes"
  default     = 3
}

variable "server_cores" {
  type        = number
  description = "CPU cores for server nodes"
  default     = 4
}

variable "server_memory" {
  type        = number
  description = "Memory in MB for server nodes"
  default     = 8192
}

variable "server_disk_size" {
  type        = number
  description = "Disk size in GB for server nodes"
  default     = 50
}

variable "agent_cores" {
  type        = number
  description = "CPU cores for agent nodes"
  default     = 4
}

variable "agent_memory" {
  type        = number
  description = "Memory in MB for agent nodes"
  default     = 16384
}

variable "agent_disk_size" {
  type        = number
  description = "Disk size in GB for agent nodes"
  default     = 100
}

variable "k3s_vlan_id" {
  type        = number
  description = "VLAN ID for Kubernetes network"
  default     = 20
}

variable "k3s_gateway" {
  type        = string
  description = "Gateway for Kubernetes VLAN"
  default     = "10.0.20.1"
}

variable "server_ip_base" {
  type        = string
  description = "Base IP for server nodes (e.g., 10.0.20.10)"
  default     = "10.0.20.10"
}

variable "agent_ip_base" {
  type        = string
  description = "Base IP for agent nodes (e.g., 10.0.20.21)"
  default     = "10.0.20.21"
}

variable "cloud_init_file_id" {
  type        = string
  description = "Proxmox snippet ID for k8s cloud-init"
  default     = null
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "SSH public keys for VM access"
}

variable "storage_pool" {
  type        = string
  description = "Storage pool for VM disks"
  default     = "local-ssd"
}
