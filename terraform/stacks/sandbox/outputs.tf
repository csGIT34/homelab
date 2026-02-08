output "sandbox_vm_ids" {
  value       = module.sandbox_vm[*].vm_id
  description = "VM IDs of sandbox VMs"
}

output "sandbox_names" {
  value       = module.sandbox_vm[*].name
  description = "Names of sandbox VMs"
}
