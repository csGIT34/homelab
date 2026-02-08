variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint URL"
}

variable "proxmox_api_token" {
  type        = string
  description = "Proxmox API token"
  sensitive   = true
}

variable "clone_template_id" {
  type        = number
  description = "VM ID of the Ubuntu template to clone"
  default     = 9000
}

variable "target_node" {
  type        = string
  description = "Proxmox node for PostgreSQL VM"
  default     = "pve-r720"
}

variable "cores" {
  type        = number
  description = "CPU cores"
  default     = 4
}

variable "memory" {
  type        = number
  description = "Memory in MB"
  default     = 16384
}

variable "disk_size" {
  type        = number
  description = "Disk size in GB"
  default     = 100
}

variable "vlan_id" {
  type        = number
  description = "VLAN ID for Database network"
  default     = 30
}

variable "ip_address" {
  type        = string
  description = "Static IP for PostgreSQL VM"
  default     = "10.0.30.10/24"
}

variable "gateway" {
  type        = string
  description = "Gateway for Database VLAN"
  default     = "10.0.30.1"
}

variable "cloud_init_file_id" {
  type        = string
  description = "Proxmox snippet ID for postgres cloud-init"
  default     = null
}

variable "storage_pool" {
  type        = string
  description = "Storage pool for VM disk"
  default     = "local-ssd"
}
