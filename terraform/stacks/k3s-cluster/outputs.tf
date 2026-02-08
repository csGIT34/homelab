output "k3s_server_ids" {
  value       = module.k3s_server[*].vm_id
  description = "VM IDs of k3s server nodes"
}

output "k3s_server_names" {
  value       = module.k3s_server[*].name
  description = "Names of k3s server nodes"
}

output "k3s_agent_ids" {
  value       = module.k3s_agent[*].vm_id
  description = "VM IDs of k3s agent nodes"
}

output "k3s_agent_names" {
  value       = module.k3s_agent[*].name
  description = "Names of k3s agent nodes"
}
