variable "project" {
  type        = string
  description = "Short project name used in network names and labels."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project must be 2-21 characters, start with a letter, and contain only lowercase letters, digits and hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Environment name. Used in network names and the environment label."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "owner" {
  type        = string
  description = "Owner label applied to both networks."

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._@-]{0,62}$", var.owner))
    error_message = "owner must be 1-63 characters and start with a letter or digit."
  }
}

variable "frontend_cidr" {
  type        = string
  description = "CIDR of the frontend bridge. Must sit in 10.0.0.0/8 so it does not collide with Docker's default 172.17.0.0/16 and 192.168.0.0/16 pools."

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
  description = "CIDR of the internal backend bridge. Same constraints as frontend_cidr, and it must not overlap the frontend."

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
