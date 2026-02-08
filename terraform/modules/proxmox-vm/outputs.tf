output "vm_id" {
  value       = proxmox_virtual_environment_vm.vm.vm_id
  description = "The VM ID"
}

output "name" {
  value       = proxmox_virtual_environment_vm.vm.name
  description = "The VM name"
}

output "ipv4_address" {
  value       = proxmox_virtual_environment_vm.vm.ipv4_addresses
  description = "The IPv4 addresses assigned to the VM"
}

output "mac_address" {
  value       = proxmox_virtual_environment_vm.vm.network_interface_names
  description = "The network interface names"
}
