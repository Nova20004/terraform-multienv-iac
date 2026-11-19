output "nodes" {
  description = "SSH endpoints. ansible_host is always 127.0.0.1 because the port is published on loopback only."
  value = [
    for index in range(var.node_count) : {
      name = "${local.name_prefix}-node-${index + 1}"
      port = var.ssh_port_base + index
    }
  ]
}

output "container_names" {
  description = "Docker names of the nodes, in order."
  value       = [for index in range(var.node_count) : "${local.name_prefix}-node-${index + 1}"]
}

output "lb_url" {
  description = "Loopback URL of the nginx load balancer, or null when enable_lb is false."
  value       = var.enable_lb ? "http://127.0.0.1:${var.lb_port}" : null
}

output "systemd_privileged" {
  description = "Whether the nodes were started with Docker's privileged flag. True means lab-only."
  value       = var.systemd_privileged
}
