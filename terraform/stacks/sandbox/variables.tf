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
  description = "Proxmox node for sandbox VMs"
  default     = "pve-r720"
}

variable "vm_count" {
  type        = number
  description = "Number of sandbox VMs to provision"
  default     = 0
}

variable "cores" {
  type        = number
  description = "CPU cores per sandbox VM"
  default     = 2
}

variable "memory" {
  type        = number
  description = "Memory in MB per sandbox VM"
  default     = 4096
}

variable "disk_size" {
  type        = number
  description = "Disk size in GB per sandbox VM"
  default     = 30
}

variable "vlan_id" {
  type        = number
  description = "VLAN ID for Sandbox network"
  default     = 40
}

variable "gateway" {
  type        = string
  description = "Gateway for Sandbox VLAN"
  default     = "10.0.40.1"
}

variable "ip_base" {
  type        = string
  description = "Base IP for sandbox VMs (e.g., 10.0.40.10)"
  default     = "10.0.40.10"
}

variable "cloud_init_file_id" {
  type        = string
  description = "Proxmox snippet ID for cloud-init"
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
