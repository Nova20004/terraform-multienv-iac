# One-time local state. This root creates the Postgres container that every
# environment then uses as a remote backend. Do not point this root at the pg
# backend: it would need the database it is creating.
#
# Destroying this root deletes every environment's state. Use
# `make bootstrap-destroy CONFIRM=yes` and destroy the environments first.

provider "docker" {
  host = var.docker_host
}

locals {
  labels = {
    environment = "bootstrap"
    managed-by  = "terraform"
    project     = var.project
    owner       = var.owner
  }
}

resource "docker_image" "postgres" {
  name         = var.postgres_image
  keep_locally = true
}

resource "docker_volume" "state" {
  name = var.volume_name

  dynamic "labels" {
    for_each = local.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_container" "state" {
  name         = var.container_name
  image        = docker_image.postgres.image_id
  restart      = "unless-stopped"
  memory       = var.memory_mb
  must_run     = true
  wait         = true
  wait_timeout = 120

  env = [
    "POSTGRES_USER=${var.state_db_user}",
    "POSTGRES_PASSWORD=${var.state_db_password}",
  ]

  # Bind-mounted, not uploaded: the entrypoint reads this directory before
  # the server is healthy, and upload runs too late for that.
  mounts {
    type      = "bind"
    source    = abspath("${path.module}/initdb/01-create-state-databases.sql")
    target    = "/docker-entrypoint-initdb.d/01-create-state-databases.sql"
    read_only = true
  }

  ports {
    internal = 5432
    external = var.state_db_port
    ip       = "127.0.0.1"
    protocol = "tcp"
  }

  volumes {
    volume_name    = docker_volume.state.name
    container_path = "/var/lib/postgresql/data"
  }

  healthcheck {
    test         = ["CMD-SHELL", "pg_isready -U ${var.state_db_user} -d terraform_state_dev && pg_isready -U ${var.state_db_user} -d terraform_state_staging && pg_isready -U ${var.state_db_user} -d terraform_state_prod"]
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
