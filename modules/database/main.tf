locals {
  name_prefix = "${var.project}-${var.environment}"
  labels = {
    environment = var.environment
    managed-by  = "terraform"
    project     = var.project
    owner       = var.owner
  }
}

resource "random_password" "app" {
  length  = 32
  special = false
}

resource "docker_image" "postgres" {
  name         = var.postgres_image
  keep_locally = true
}

resource "docker_volume" "data" {
  name = "${local.name_prefix}-db-data"

  dynamic "labels" {
    for_each = local.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_container" "db" {
  name         = "${local.name_prefix}-db"
  image        = docker_image.postgres.image_id
  restart      = var.restart_policy
  memory       = var.memory_mb
  must_run     = true
  wait         = true
  wait_timeout = 120

  env = [
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${random_password.app.result}",
    "POSTGRES_DB=${var.db_name}",
  ]

  networks_advanced {
    name = var.backend_network_name
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/var/lib/postgresql/data"
  }

  healthcheck {
    test         = ["CMD-SHELL", "pg_isready -U ${var.db_user} -d ${var.db_name}"]
    interval     = "5s"
    timeout      = "5s"
    start_period = "20s"
    retries      = 15
  }

  dynamic "labels" {
    for_each = local.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}
