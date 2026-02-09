variable "name" {
  type        = string
  description = "VM name"
}

variable "target_node" {
  type        = string
  description = "Proxmox node to deploy on"
}

variable "vm_id" {
  type        = number
  description = "Proxmox VM ID"
  default     = 0
}

variable "description" {
  type        = string
  description = "VM description"
  default     = "Managed by Terraform"
}

variable "tags" {
  type        = list(string)
  description = "Tags for the VM"
  default     = ["terraform"]
}

variable "clone_template_id" {
  type        = number
  description = "VM ID of the template to clone"
  default     = 9000
}

variable "cores" {
  type        = number
  description = "Number of CPU cores"
  default     = 2
}

variable "sockets" {
  type        = number
  description = "Number of CPU sockets"
  default     = 1
}

variable "memory" {
  type        = number
  description = "Memory in MB"
  default     = 4096
}

variable "disk_size" {
  type        = number
  description = "Disk size in GB"
  default     = 30
}

variable "storage_pool" {
  type        = string
  description = "Storage pool for VM disk"
  default     = "local-ssd"
}

variable "vlan_id" {
  type        = number
  description = "VLAN tag for network interface"
}

variable "ip_address" {
  type        = string
  description = "Static IP address in CIDR notation (e.g., 10.0.20.10/24)"
}

variable "gateway" {
  type        = string
  description = "Default gateway"
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS server addresses"
  default     = ["10.0.20.53", "1.1.1.1"]
}

variable "dns_domain" {
  type        = string
  description = "DNS search domain"
  default     = "home.lab"
}

variable "cloud_init_file_id" {
  type        = string
  description = "Proxmox snippet ID for cloud-init user data"
  default     = null
}

variable "ssh_username" {
  type        = string
  description = "Default user account for SSH access"
  default     = "ubuntu"
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "SSH public keys for the default user"
}

variable "on_boot" {
  type        = bool
  description = "Start VM on host boot"
  default     = true
}
