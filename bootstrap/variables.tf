variable "docker_host" {
  type        = string
  default     = null
  nullable    = true
  description = "Docker daemon URL. Null uses DOCKER_HOST or the local socket, which covers Docker Desktop, Colima and rootless Docker."

  validation {
    condition     = var.docker_host == null || can(regex("^(unix|tcp|npipe|ssh)://", var.docker_host))
    error_message = "docker_host must be null or a URL starting with unix://, tcp://, npipe:// or ssh://."
  }
}

variable "project" {
  type        = string
  default     = "lab"
  description = "Project label applied to the state database container and volume."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project must be 2-21 characters, start with a letter, and contain only lowercase letters, digits and hyphens."
  }
}

variable "owner" {
  type        = string
  default     = "local"
  description = "Owner label applied to the state database resources."

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._@-]{0,62}$", var.owner))
    error_message = "owner must be 1-63 characters and start with a letter or digit."
  }
}

variable "state_db_user" {
  type        = string
  default     = "terraform"
  description = "Role that owns terraform_state_dev, terraform_state_staging and terraform_state_prod."

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,30}$", var.state_db_user))
    error_message = "state_db_user must be a lowercase Postgres identifier."
  }
}

variable "state_db_password" {
  type        = string
  sensitive   = true
  description = "Password for the state database role. Read from TF_VAR_state_db_password. Restricted to characters that do not need URL encoding inside PG_CONN_STR."

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{16,128}$", var.state_db_password)) && var.state_db_password != "change-me-please-16"
    error_message = "state_db_password must be 16-128 characters from [A-Za-z0-9_-] and must not be the .env.example placeholder."
  }
}

variable "state_db_port" {
  type        = number
  default     = 55432
  description = "Host port bound only to 127.0.0.1. Must match the port inside PG_CONN_STR."

  validation {
    condition     = var.state_db_port > 1024 && var.state_db_port <= 65535
    error_message = "state_db_port must be between 1025 and 65535."
  }
}

variable "container_name" {
  type        = string
  default     = "tfstate-postgres"
  description = "Name of the Postgres container that holds Terraform state."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}$", var.container_name))
    error_message = "container_name must be a Docker container name."
  }
}

variable "volume_name" {
  type        = string
  default     = "tfstate-postgres-data"
  description = "Named volume that persists the state database across container restarts."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}$", var.volume_name))
    error_message = "volume_name must be a Docker volume name."
  }
}

variable "postgres_image" {
  type        = string
  default     = "postgres:17.12@sha256:b60e90042aa6b8dbecd58e224b3e36114dbf8ad754465264c2476ad58a86e45c"
  description = "Explicit Postgres 17 image tag and multi-arch digest. Resolved 2026-11-19. Never latest."

  validation {
    condition     = can(regex("^postgres:17\\.[0-9]+@sha256:[0-9a-f]{64}$", var.postgres_image))
    error_message = "postgres_image must be postgres:17.<minor>@sha256:<64 hex>. The floating tag 17 and latest are rejected."
  }
}

variable "memory_mb" {
  type        = number
  default     = 256
  description = "Memory limit of the state database container, in megabytes."

  validation {
    condition     = var.memory_mb >= 128 && var.memory_mb <= 8192
    error_message = "memory_mb must be between 128 and 8192."
  }
}
