output "ollama_vm_id" {
  value       = module.ollama.vm_id
  description = "VM ID of the Ollama server"
}

output "ollama_name" {
  value       = module.ollama.name
  description = "Name of the Ollama VM"
}

output "ollama_ip" {
  value       = module.ollama.ipv4_address
  description = "IPv4 address of the Ollama VM"
}
