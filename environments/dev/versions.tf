terraform {
  required_version = ">= 1.8.0, < 2.0.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.5"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
