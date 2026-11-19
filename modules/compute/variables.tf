variable "project" {
  type        = string
  description = "Short project name used in container names and labels."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project must be 2-21 characters, start with a letter, and contain only lowercase letters, digits and hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Environment name used in container names and labels."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "owner" {
  type        = string
  description = "Owner label applied to nodes, the node image and the optional load balancer."

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._@-]{0,62}$", var.owner))
    error_message = "owner must be 1-63 characters and start with a letter or digit."
  }
}

variable "node_count" {
  type        = number
  description = "How many systemd nodes to run. Dev is 1, staging 2, prod 3."

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 10
    error_message = "node_count must be between 1 and 10."
  }
}

variable "ssh_port_base" {
  type        = number
  description = "First host port published for SSH. Node N listens on 127.0.0.1:(ssh_port_base + N - 1)."

  validation {
    condition     = var.ssh_port_base >= 1025 && var.ssh_port_base <= 64000
    error_message = "ssh_port_base must be between 1025 and 64000."
  }
}

variable "ssh_user" {
  type        = string
  default     = "ansible"
  description = "Unix account created at container start. The matching public key is injected through SSH_PUBLIC_KEY."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}$", var.ssh_user))
    error_message = "ssh_user must be a short lowercase account name."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "Operator public key injected at container start. Never baked into the image."

  validation {
    condition = (
      !strcontains(var.ssh_public_key, "\n")
      && can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh.com) [A-Za-z0-9+/=]+( .+)?$", var.ssh_public_key))
    )
    error_message = "ssh_public_key must be a single-line OpenSSH public key."
  }
}

variable "node_base_image" {
  type        = string
  description = "Ubuntu 24.04 base image, tag plus multi-arch digest, passed as a Docker build-arg."

  validation {
    condition     = can(regex("^ubuntu:24\\.04@sha256:[0-9a-f]{64}$", var.node_base_image))
    error_message = "node_base_image must be ubuntu:24.04@sha256:<64 hex>."
  }
}

variable "memory_mb" {
  type        = number
  description = "Memory limit of each node, in megabytes. systemd needs a few hundred megabytes."

  validation {
    condition     = var.memory_mb >= 384 && var.memory_mb <= 16384
    error_message = "memory_mb must be between 384 and 16384."
  }
}

variable "cpu_shares" {
  type        = number
  description = "Relative CPU weight (Docker --cpu-shares) for each node."

  validation {
    condition     = var.cpu_shares >= 2 && var.cpu_shares <= 262144
    error_message = "cpu_shares must be between 2 and 262144."
  }
}

variable "restart_policy" {
  type        = string
  description = "Docker restart policy. Prod uses unless-stopped. This is not high availability."

  validation {
    condition     = contains(["no", "on-failure", "always", "unless-stopped"], var.restart_policy)
    error_message = "restart_policy must be no, on-failure, always or unless-stopped."
  }
}

variable "restart_max_retries" {
  type        = number
  default     = 5
  description = "Retry cap used when restart_policy is on-failure."

  validation {
    condition     = var.restart_max_retries >= 0 && var.restart_max_retries <= 20
    error_message = "restart_max_retries must be between 0 and 20."
  }
}

variable "enable_lb" {
  type        = bool
  description = "When true, run an nginx container that proxies to the nodes over the frontend network."

  validation {
    condition     = var.enable_lb == true || var.enable_lb == false
    error_message = "enable_lb must be true or false."
  }
}

variable "lb_port" {
  type        = number
  default     = null
  nullable    = true
  description = "Host port bound to 127.0.0.1 for the load balancer. Required when enable_lb is true."

  validation {
    condition     = var.lb_port == null || (var.lb_port > 1024 && var.lb_port <= 65535)
    error_message = "lb_port must be null or a TCP port between 1025 and 65535."
  }
}

variable "nginx_image" {
  type        = string
  description = "Explicit nginx stable image tag and multi-arch digest. Never latest, never the mainline tag."

  validation {
    condition     = can(regex("^nginx:[0-9]+\\.[0-9]+\\.[0-9]+@sha256:[0-9a-f]{64}$", var.nginx_image))
    error_message = "nginx_image must be nginx:<major>.<minor>.<patch>@sha256:<64 hex>."
  }
}

variable "frontend_network_name" {
  type        = string
  description = "Frontend bridge the nodes (and the load balancer) join."

  validation {
    condition     = length(var.frontend_network_name) > 0
    error_message = "frontend_network_name must not be empty."
  }
}

variable "backend_network_name" {
  type        = string
  description = "Internal backend bridge the nodes join so they can reach Postgres."

  validation {
    condition     = length(var.backend_network_name) > 0
    error_message = "backend_network_name must not be empty."
  }
}

variable "systemd_privileged" {
  type        = bool
  default     = false
  description = "Lab-only escape hatch. Leave false unless systemd cannot become PID 1 without --privileged. See the module README."

  validation {
    condition     = var.systemd_privileged == true || var.systemd_privileged == false
    error_message = "systemd_privileged must be true or false."
  }
}

variable "extra_capabilities" {
  type        = list(string)
  default     = []
  description = "Linux capabilities added on top of NET_ADMIN. Empty unless a lab host cannot boot systemd with NET_ADMIN alone."

  validation {
    condition     = alltrue([for cap in var.extra_capabilities : can(regex("^[A-Z0-9_]+$", cap))])
    error_message = "extra_capabilities entries must look like SYS_ADMIN."
  }
}

variable "security_opts" {
  type        = list(string)
  default     = []
  description = "Docker security options, for example seccomp=unconfined, used only when a lab host needs them to boot systemd."

  validation {
    condition     = alltrue([for opt in var.security_opts : length(opt) > 0 && length(opt) < 128])
    error_message = "security_opts entries must be non-empty strings shorter than 128 characters."
  }
}
