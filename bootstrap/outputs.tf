output "container_name" {
  description = "Docker name of the state database. Used by make locks and make psql."
  value       = docker_container.state.name
}

output "volume_name" {
  description = "Named volume that holds the state database files."
  value       = docker_volume.state.name
}

output "host" {
  description = "Loopback address the state database is bound to."
  value       = "127.0.0.1"
}

output "port" {
  description = "Host port published on 127.0.0.1."
  value       = var.state_db_port
}

output "databases" {
  description = "One database per environment. Advisory locks do not cross databases."
  value = [
    "terraform_state_dev",
    "terraform_state_staging",
    "terraform_state_prod",
  ]
}

output "username" {
  description = "Database role Terraform uses. The password stays in TF_VAR_state_db_password and PG_CONN_STR."
  value       = var.state_db_user
}
