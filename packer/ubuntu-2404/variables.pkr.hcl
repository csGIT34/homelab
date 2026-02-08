variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL"
  default     = "https://10.0.10.12:8006/api2/json"
}

variable "proxmox_token_id" {
  type        = string
  description = "Proxmox API token ID (user@realm!token-name)"
  sensitive   = true
}

variable "proxmox_token_secret" {
  type        = string
  description = "Proxmox API token secret"
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build on"
  default     = "pve-r720"
}

variable "vm_id" {
  type        = number
  description = "VM ID for the template"
  default     = 9000
}

variable "template_name" {
  type        = string
  description = "Name for the VM template"
  default     = "ubuntu-2404-template"
}

variable "iso_file" {
  type        = string
  description = "Path to Ubuntu ISO on Proxmox storage"
  default     = "local-hdd:iso/ubuntu-24.04.3-live-server-amd64.iso"
}

variable "storage_pool" {
  type        = string
  description = "Storage pool for VM disks"
  default     = "local-ssd"
}

variable "ssh_username" {
  type        = string
  description = "SSH username for provisioning"
  default     = "ubuntu"
}

variable "ssh_password" {
  type        = string
  description = "SSH password for provisioning (replaced by cloud-init keys post-build)"
  sensitive   = true
  default     = "ubuntu"
}
