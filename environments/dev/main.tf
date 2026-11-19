provider "docker" {
  host = var.docker_host
}

locals {
  ssh_private_key_path = coalesce(var.ssh_private_key_path, abspath("${path.module}/../../.ssh/id_ed25519"))
}

module "network" {
  source        = "../../modules/network"
  project       = var.project
  environment   = var.environment
  owner         = var.owner
  frontend_cidr = var.frontend_cidr
  backend_cidr  = var.backend_cidr
}

module "database" {
  source                = "../../modules/database"
  project               = var.project
  environment           = var.environment
  owner                 = var.owner
  backend_network_name  = module.network.backend_network_name
  postgres_image        = var.postgres_image
  db_name               = var.db_name
  db_user               = var.db_user
  memory_mb             = var.db_memory_mb
  backup_retention_days = var.backup_retention_days
  restart_policy        = var.restart_policy
}

module "compute" {
  source                = "../../modules/compute"
  project               = var.project
  environment           = var.environment
  owner                 = var.owner
  node_count            = var.node_count
  ssh_port_base         = var.ssh_port_base
  ssh_user              = var.ssh_user
  ssh_public_key        = var.ssh_public_key
  node_base_image       = var.node_base_image
  memory_mb             = var.node_memory_mb
  cpu_shares            = var.node_cpu_shares
  restart_policy        = var.restart_policy
  enable_lb             = var.enable_lb
  lb_port               = var.lb_port
  nginx_image           = var.nginx_image
  frontend_network_name = module.network.frontend_network_name
  backend_network_name  = module.network.backend_network_name
  systemd_privileged    = var.systemd_privileged
  extra_capabilities    = var.extra_capabilities
  security_opts         = var.security_opts
}

resource "local_file" "inventory" {
  filename        = abspath("${path.module}/../../ansible/inventories/${var.environment}/hosts.ini")
  file_permission = "0644"
  content = templatefile("${path.module}/../../ansible/templates/hosts.ini.tftpl", {
    nodes                = module.compute.nodes
    ssh_user             = var.ssh_user
    ssh_private_key_path = local.ssh_private_key_path
    environment          = var.environment
    project              = var.project
    db_host              = module.database.container_name
    db_port              = module.database.port
    db_user              = module.database.username
    db_name              = module.database.name
  })
}
