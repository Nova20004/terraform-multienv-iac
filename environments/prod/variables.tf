variable "docker_host" {
  type        = string
  default     = null
  nullable    = true
  description = "Docker daemon URL. Null uses DOCKER_HOST or the local socket."

  validation {
    condition     = var.docker_host == null || can(regex("^(unix|tcp|npipe|ssh)://", var.docker_host))
    error_message = "docker_host must be null or a URL starting with unix://, tcp://, npipe:// or ssh://."
  }
}

variable "project" {
  type        = string
  default     = "lab"
  description = "Project name used in resource names and labels."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project must be 2-21 characters, start with a letter, and contain only lowercase letters, digits and hyphens."
  }
}

variable "owner" {
  type        = string
  default     = "local"
  description = "Owner label applied to every Docker resource in this environment."

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._@-]{0,62}$", var.owner))
    error_message = "owner must be 1-63 characters and start with a letter or digit."
  }
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Fixed to prod for this root module."

  validation {
    condition     = var.environment == "prod"
    error_message = "This root module is prod. environment must be \"prod\"."
  }
}

variable "frontend_cidr" {
  type        = string
  default     = "10.30.0.0/24"
  description = "Frontend bridge CIDR. Dev, staging and prod use distinct 10/8 ranges so they can run together."

  validation {
    condition = (
      can(cidrhost(var.frontend_cidr, 0))
      && tonumber(split("/", var.frontend_cidr)[1]) >= 16
      && tonumber(split("/", var.frontend_cidr)[1]) <= 28
      && split(".", cidrhost(var.frontend_cidr, 0))[0] == "10"
      && var.frontend_cidr == cidrsubnet(var.frontend_cidr, 0, 0)
    )
    error_message = "frontend_cidr must be an IPv4 CIDR inside 10.0.0.0/8 with a prefix between 16 and 28."
  }
}

variable "backend_cidr" {
  type        = string
  default     = "10.30.1.0/24"
  description = "Internal backend bridge CIDR."

  validation {
    condition = (
      can(cidrhost(var.backend_cidr, 0))
      && tonumber(split("/", var.backend_cidr)[1]) >= 16
      && tonumber(split("/", var.backend_cidr)[1]) <= 28
      && split(".", cidrhost(var.backend_cidr, 0))[0] == "10"
      && var.backend_cidr == cidrsubnet(var.backend_cidr, 0, 0)
    )
    error_message = "backend_cidr must be an IPv4 CIDR inside 10.0.0.0/8 with a prefix between 16 and 28."
  }
}

variable "node_count" {
  type        = number
  default     = 3
  description = "Number of systemd nodes. Prod default is 3. This is still a single Docker host, not high availability."

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 10
    error_message = "node_count must be between 1 and 10."
  }
}

variable "ssh_port_base" {
  type        = number
  default     = 2401
  description = "First loopback SSH port. Prod uses 2401 so it does not collide with dev (2201) or staging (2301)."

  validation {
    condition     = var.ssh_port_base >= 1025 && var.ssh_port_base <= 64000
    error_message = "ssh_port_base must be between 1025 and 64000."
  }
}

variable "ssh_user" {
  type        = string
  default     = "ansible"
  description = "Unix account Ansible logs in as."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}$", var.ssh_user))
    error_message = "ssh_user must be a short lowercase account name."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "Operator public key injected into each node at start. make plan exports TF_VAR_ssh_public_key from the .pub file. It is not stored in tfvars and not baked into the image."

  validation {
    condition = (
      !strcontains(var.ssh_public_key, "\n")
      && can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh.com) [A-Za-z0-9+/=]+( .+)?$", var.ssh_public_key))
    )
    error_message = "ssh_public_key must be a single-line OpenSSH public key. make ssh-key writes one under .ssh/."
  }
}

variable "ssh_private_key_path" {
  type        = string
  default     = null
  nullable    = true
  description = "Private key Ansible uses. Null resolves to <repo>/.ssh/id_ed25519, created by make ssh-key. The public key is the same path plus .pub."

  validation {
    condition     = var.ssh_private_key_path == null || (length(var.ssh_private_key_path) > 0 && !endswith(var.ssh_private_key_path, ".pub"))
    error_message = "ssh_private_key_path must be null or the private key path, not the .pub file."
  }
}

variable "node_base_image" {
  type        = string
  default     = "ubuntu:24.04@sha256:73b999393d07f2bf65a40373778a44dc9a6d54ad7718d29247d8ff9413c4d6a8"
  description = "Ubuntu 24.04 base image digest for the node Dockerfile. Resolved 2026-11-19."

  validation {
    condition     = can(regex("^ubuntu:24\\.04@sha256:[0-9a-f]{64}$", var.node_base_image))
    error_message = "node_base_image must be ubuntu:24.04@sha256:<64 hex>."
  }
}

variable "node_memory_mb" {
  type        = number
  default     = 1024
  description = "Memory limit of each node, in megabytes."

  validation {
    condition     = var.node_memory_mb >= 384 && var.node_memory_mb <= 16384
    error_message = "node_memory_mb must be between 384 and 16384."
  }
}

variable "node_cpu_shares" {
  type        = number
  default     = 1024
  description = "Relative CPU weight of each node."

  validation {
    condition     = var.node_cpu_shares >= 2 && var.node_cpu_shares <= 262144
    error_message = "node_cpu_shares must be between 2 and 262144."
  }
}

variable "restart_policy" {
  type        = string
  default     = "unless-stopped"
  description = "Restart policy for nodes and the database. Prod uses unless-stopped. This is not high availability."

  validation {
    condition     = contains(["no", "on-failure", "always", "unless-stopped"], var.restart_policy)
    error_message = "restart_policy must be no, on-failure, always or unless-stopped."
  }
}

variable "enable_lb" {
  type        = bool
  default     = true
  description = "Prod runs the nginx load balancer. One container is not a highly available load balancer."

  validation {
    condition     = var.enable_lb == true || var.enable_lb == false
    error_message = "enable_lb must be true or false."
  }
}

variable "lb_port" {
  type        = number
  default     = 8081
  nullable    = true
  description = "Loopback port for the prod load balancer."

  validation {
    condition     = var.lb_port == null || (var.lb_port > 1024 && var.lb_port <= 65535)
    error_message = "lb_port must be null or a TCP port between 1025 and 65535."
  }
}

variable "nginx_image" {
  type        = string
  default     = "nginx:1.30.7@sha256:7fad6c0dff97965adbddf28027d934b111fc0221a554315dc274712f3fba24d3"
  description = "nginx stable image. 1.30.7 is the stable line published on nginx.org on 2026-11-19. 1.31.9 is mainline and is not used."

  validation {
    condition     = can(regex("^nginx:[0-9]+\\.[0-9]+\\.[0-9]+@sha256:[0-9a-f]{64}$", var.nginx_image))
    error_message = "nginx_image must be nginx:<major>.<minor>.<patch>@sha256:<64 hex>."
  }
}

variable "postgres_image" {
  type        = string
  default     = "postgres:17.12@sha256:b60e90042aa6b8dbecd58e224b3e36114dbf8ad754465264c2476ad58a86e45c"
  description = "Postgres 17 image. 17.12 is the newest 17.x tag on Docker Hub on 2026-11-19."

  validation {
    condition     = can(regex("^postgres:17\\.[0-9]+@sha256:[0-9a-f]{64}$", var.postgres_image))
    error_message = "postgres_image must be postgres:17.<minor>@sha256:<64 hex>."
  }
}

variable "db_name" {
  type        = string
  default     = "app"
  description = "Application database name."

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,30}$", var.db_name))
    error_message = "db_name must be a lowercase Postgres identifier."
  }
}

variable "db_user" {
  type        = string
  default     = "app"
  description = "Application database role. The password is generated inside the database module."

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,30}$", var.db_user))
    error_message = "db_user must be a lowercase Postgres identifier."
  }
}

variable "db_memory_mb" {
  type        = number
  default     = 1024
  description = "Memory limit of the database container, in megabytes."

  validation {
    condition     = var.db_memory_mb >= 128 && var.db_memory_mb <= 16384
    error_message = "db_memory_mb must be between 128 and 16384."
  }
}

variable "backup_retention_days" {
  type        = number
  default     = 30
  description = "How many days backup-db.sh keeps dumps. Prod keeps thirty days."

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 3650
    error_message = "backup_retention_days must be between 1 and 3650."
  }
}

variable "systemd_privileged" {
  type        = bool
  default     = false
  description = "Lab-only. Set true only if systemd cannot start on this Docker host without --privileged."

  validation {
    condition     = var.systemd_privileged == true || var.systemd_privileged == false
    error_message = "systemd_privileged must be true or false."
  }
}

variable "extra_capabilities" {
  type        = list(string)
  default     = []
  description = "Extra Linux capabilities beyond NET_ADMIN. Leave empty unless the lab host needs them."

  validation {
    condition     = alltrue([for cap in var.extra_capabilities : can(regex("^[A-Z0-9_]+$", cap))])
    error_message = "extra_capabilities entries must look like SYS_ADMIN."
  }
}

variable "security_opts" {
  type        = list(string)
  default     = []
  description = "Docker security options for the nodes. Empty unless the lab host needs them to boot systemd."

  validation {
    condition     = alltrue([for opt in var.security_opts : length(opt) > 0 && length(opt) < 128])
    error_message = "security_opts entries must be non-empty strings shorter than 128 characters."
  }
}
