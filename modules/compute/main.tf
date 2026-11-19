locals {
  name_prefix  = "${var.project}-${var.environment}"
  node_context = abspath("${path.module}/../../docker/node")
  labels = {
    environment = var.environment
    managed-by  = "terraform"
    project     = var.project
    owner       = var.owner
  }
  capabilities     = distinct(concat(["NET_ADMIN"], var.extra_capabilities))
  lb_external_port = coalesce(var.lb_port, 65535)
}

resource "terraform_data" "shape_guard" {
  lifecycle {
    precondition {
      condition     = var.ssh_port_base + var.node_count - 1 <= 65535
      error_message = "ssh_port_base + node_count - 1 must not exceed 65535."
    }
    precondition {
      condition     = !var.enable_lb || var.lb_port != null
      error_message = "lb_port is required when enable_lb is true."
    }
    precondition {
      condition = (
        !var.enable_lb
        || var.lb_port < var.ssh_port_base
        || var.lb_port >= var.ssh_port_base + var.node_count
      )
      error_message = "lb_port must not collide with the SSH ports of the nodes."
    }
  }
}

resource "docker_image" "node" {
  name         = "${local.name_prefix}-node:24.04"
  keep_locally = true

  build {
    context     = local.node_context
    dockerfile  = "Dockerfile"
    pull_parent = true
    remove      = true
    tag         = ["${local.name_prefix}-node:24.04"]
    build_args = {
      UBUNTU_IMAGE = var.node_base_image
      PROJECT      = var.project
      ENVIRONMENT  = var.environment
      OWNER        = var.owner
    }
  }

  triggers = {
    dockerfile = filesha256("${local.node_context}/Dockerfile")
    entrypoint = filesha256("${local.node_context}/entrypoint.sh")
    sshd       = filesha256("${local.node_context}/sshd-container.conf")
    base       = var.node_base_image
  }
}

resource "docker_container" "node" {
  count           = var.node_count
  name            = "${local.name_prefix}-node-${count.index + 1}"
  image           = docker_image.node.image_id
  hostname        = "${local.name_prefix}-node-${count.index + 1}"
  restart         = var.restart_policy
  max_retry_count = var.restart_max_retries
  memory          = var.memory_mb
  cpu_shares      = var.cpu_shares
  must_run        = true
  init            = false
  privileged      = var.systemd_privileged
  cgroupns_mode   = "host"
  stop_signal     = "SIGRTMIN+3"
  wait            = true
  wait_timeout    = 180

  env = [
    "SSH_PUBLIC_KEY=${var.ssh_public_key}",
    "SSH_USER=${var.ssh_user}",
  ]

  capabilities {
    add = local.capabilities
  }

  security_opts = var.security_opts

  tmpfs = {
    "/run"      = "rw,nosuid,nodev,mode=755,size=64m"
    "/run/lock" = "rw,nosuid,nodev,noexec,mode=755,size=16m"
    "/tmp"      = "rw,nosuid,nodev,mode=1777,size=64m"
  }

  # rprivate matches `docker run -v /sys/fs/cgroup:/sys/fs/cgroup:rw`.
  # rslave is rejected when the daemon's cgroup mount is private, which is
  # the case on Docker Desktop.
  mounts {
    type   = "bind"
    source = "/sys/fs/cgroup"
    target = "/sys/fs/cgroup"

    bind_options {
      propagation = "rprivate"
    }
  }

  ports {
    internal = 22
    external = var.ssh_port_base + count.index
    ip       = "127.0.0.1"
    protocol = "tcp"
  }

  networks_advanced {
    name = var.frontend_network_name
  }

  networks_advanced {
    name = var.backend_network_name
  }

  healthcheck {
    test         = ["CMD-SHELL", "python3 -c 'import socket; s=socket.create_connection((\"127.0.0.1\",22),3); s.close()'"]
    interval     = "5s"
    timeout      = "5s"
    start_period = "25s"
    retries      = 20
  }

  dynamic "labels" {
    for_each = local.labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  depends_on = [docker_image.node, terraform_data.shape_guard]
}

resource "docker_image" "lb" {
  count        = var.enable_lb ? 1 : 0
  name         = var.nginx_image
  keep_locally = true
}

resource "docker_container" "lb" {
  count        = var.enable_lb ? 1 : 0
  name         = "${local.name_prefix}-lb"
  image        = docker_image.lb[0].image_id
  restart      = var.restart_policy
  memory       = 128
  must_run     = true
  init         = false
  wait         = true
  wait_timeout = 60

  networks_advanced {
    name = var.frontend_network_name
  }

  ports {
    internal = 80
    external = local.lb_external_port
    ip       = "127.0.0.1"
    protocol = "tcp"
  }

  upload {
    file = "/etc/nginx/conf.d/default.conf"
    content = templatefile("${path.module}/templates/lb.conf.tftpl", {
      upstreams = [for index in range(var.node_count) : "${local.name_prefix}-node-${index + 1}"]
    })
  }

  healthcheck {
    test         = ["CMD-SHELL", "test -s /var/run/nginx.pid"]
    interval     = "5s"
    timeout      = "3s"
    start_period = "5s"
    retries      = 10
  }

  dynamic "labels" {
    for_each = local.labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  depends_on = [docker_container.node]
}
