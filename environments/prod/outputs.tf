output "db_container_name" {
  description = "Database container name. Reachable from nodes as a Docker DNS name, not from the host."
  value       = module.database.container_name
}

output "db_port" {
  description = "Postgres port on the backend network."
  value       = module.database.port
}

output "db_name" {
  description = "Application database name."
  value       = module.database.name
}

output "db_username" {
  description = "Application database role."
  value       = module.database.username
}

output "db_password" {
  description = "Generated database password. Present in state and in the container env. Absent from the Ansible inventory."
  value       = module.database.password
  sensitive   = true
}

output "backup_retention_days" {
  description = "How long scripts/backup-db.sh keeps dumps for this environment."
  value       = module.database.backup_retention_days
}

output "node_container_names" {
  description = "Node container names, in SSH port order."
  value       = module.compute.container_names
}

output "nodes" {
  description = "Loopback SSH endpoints generated for Ansible."
  value       = module.compute.nodes
}

output "lb_url" {
  description = "Load balancer URL on 127.0.0.1, or null when the load balancer is off."
  value       = module.compute.lb_url
}

output "inventory_path" {
  description = "Path of the generated Ansible inventory."
  value       = local_file.inventory.filename
}

output "systemd_privileged" {
  description = "True when nodes run with Docker privileged mode. That mode is lab-only."
  value       = module.compute.systemd_privileged
}
