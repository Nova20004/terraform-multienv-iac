locals {
  name_prefix = "${var.project}-${var.environment}"
  labels = {
    environment = var.environment
    managed-by  = "terraform"
    project     = var.project
    owner       = var.owner
  }

  # Terraform 1.17 has no cidrcontains. Compare the address ranges as integers.
  frontend_start = parseint(join("", formatlist("%02x", [
    for octet in split(".", cidrhost(var.frontend_cidr, 0)) : tonumber(octet)
  ])), 16)
  frontend_end = parseint(join("", formatlist("%02x", [
    for octet in split(".", cidrhost(var.frontend_cidr, -1)) : tonumber(octet)
  ])), 16)
  backend_start = parseint(join("", formatlist("%02x", [
    for octet in split(".", cidrhost(var.backend_cidr, 0)) : tonumber(octet)
  ])), 16)
  backend_end = parseint(join("", formatlist("%02x", [
    for octet in split(".", cidrhost(var.backend_cidr, -1)) : tonumber(octet)
  ])), 16)
}

resource "terraform_data" "cidr_guard" {
  input = {
    frontend = var.frontend_cidr
    backend  = var.backend_cidr
  }

  lifecycle {
    precondition {
      condition = (
        local.frontend_end < local.backend_start
        || local.backend_end < local.frontend_start
      )
      error_message = "frontend_cidr and backend_cidr must not overlap."
    }
  }
}

resource "docker_network" "frontend" {
  name     = "${local.name_prefix}-frontend"
  driver   = "bridge"
  internal = false
  ipv6     = false

  ipam_config {
    subnet  = var.frontend_cidr
    gateway = cidrhost(var.frontend_cidr, 1)
  }

  dynamic "labels" {
    for_each = local.labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  depends_on = [terraform_data.cidr_guard]
}

resource "docker_network" "backend" {
  name     = "${local.name_prefix}-backend"
  driver   = "bridge"
  internal = true
  ipv6     = false

  ipam_config {
    subnet  = var.backend_cidr
    gateway = cidrhost(var.backend_cidr, 1)
  }

  dynamic "labels" {
    for_each = local.labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  depends_on = [terraform_data.cidr_guard]
}
