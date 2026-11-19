output "container_name" {
  description = "Docker DNS name of the database. Nodes on the backend network use this as the hostname. No host port is published."
  value       = docker_container.db.name
}

output "port" {
  description = "Port Postgres listens on inside the backend network."
  value       = 5432
}

output "name" {
  description = "Application database name."
  value       = var.db_name
}

output "username" {
  description = "Application database role. Not a secret."
  value       = var.db_user
}

output "password" {
  description = "Generated database password. Stored in Terraform state and in the container environment because the official image requires POSTGRES_PASSWORD. Not written to the Ansible inventory."
  value       = random_password.app.result
  sensitive   = true
}

output "backup_retention_days" {
  description = "Retention passed to scripts/backup-db.sh."
  value       = var.backup_retention_days
}

output "volume_name" {
  description = "Named volume that holds the database files."
  value       = docker_volume.data.name
}
