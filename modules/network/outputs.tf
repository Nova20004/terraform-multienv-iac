output "frontend_network_name" {
  description = "Name of the frontend bridge. Nodes and the optional load balancer join it."
  value       = docker_network.frontend.name
}

output "backend_network_name" {
  description = "Name of the internal backend bridge. Nodes and the database join it. It has no path to the host."
  value       = docker_network.backend.name
}

output "frontend_network_id" {
  description = "Docker network id of the frontend bridge."
  value       = docker_network.frontend.id
}

output "backend_network_id" {
  description = "Docker network id of the backend bridge."
  value       = docker_network.backend.id
}

output "frontend_cidr" {
  description = "CIDR configured on the frontend bridge."
  value       = var.frontend_cidr
}

output "backend_cidr" {
  description = "CIDR configured on the backend bridge."
  value       = var.backend_cidr
}
