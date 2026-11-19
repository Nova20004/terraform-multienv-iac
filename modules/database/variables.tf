variable "project" {
  type        = string
  description = "Short project name used in the database container name and labels."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project must be 2-21 characters, start with a letter, and contain only lowercase letters, digits and hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Environment name used in the container name and labels."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "owner" {
  type        = string
  description = "Owner label applied to the database container and volume."

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._@-]{0,62}$", var.owner))
    error_message = "owner must be 1-63 characters and start with a letter or digit."
  }
}

variable "backend_network_name" {
  type        = string
  description = "Name of the internal backend network. The database joins only this network and publishes no port."

  validation {
    condition     = length(var.backend_network_name) > 0
    error_message = "backend_network_name must not be empty."
  }
}

variable "postgres_image" {
  type        = string
  description = "Explicit Postgres 17 image tag and multi-arch digest. Never latest."

  validation {
    condition     = can(regex("^postgres:17\\.[0-9]+@sha256:[0-9a-f]{64}$", var.postgres_image))
    error_message = "postgres_image must be postgres:17.<minor>@sha256:<64 hex>."
  }
}

variable "db_name" {
  type        = string
  default     = "app"
  description = "Application database created by the official Postgres image."

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,30}$", var.db_name))
    error_message = "db_name must be a lowercase Postgres identifier."
  }
}

variable "db_user" {
  type        = string
  default     = "app"
  description = "Application role created by the official Postgres image. The password is a random_password, not a variable."

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,30}$", var.db_user))
    error_message = "db_user must be a lowercase Postgres identifier."
  }
}

variable "memory_mb" {
  type        = number
  description = "Memory limit of the database container, in megabytes."

  validation {
    condition     = var.memory_mb >= 128 && var.memory_mb <= 16384
    error_message = "memory_mb must be between 128 and 16384."
  }
}

variable "backup_retention_days" {
  type        = number
  description = "How many days scripts/backup-db.sh keeps pg_dump archives. The container itself does not upload backups."

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 3650
    error_message = "backup_retention_days must be between 1 and 3650."
  }
}

variable "restart_policy" {
  type        = string
  description = "Docker restart policy for the database container."

  validation {
    condition     = contains(["no", "on-failure", "always", "unless-stopped"], var.restart_policy)
    error_message = "restart_policy must be no, on-failure, always or unless-stopped."
  }
}
