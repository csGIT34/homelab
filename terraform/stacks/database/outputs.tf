output "postgres_vm_id" {
  value       = module.postgres.vm_id
  description = "VM ID of the PostgreSQL server"
}

output "postgres_name" {
  value       = module.postgres.name
  description = "Name of the PostgreSQL VM"
}

output "postgres_ip" {
  value       = module.postgres.ipv4_address
  description = "IPv4 address of the PostgreSQL VM"
}
