module "prometheus_node_exporter_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//prometheus-node-exporter?ref=v0.10.0"
  install_dependencies = var.install_dependencies
}

module "fluentbit_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//fluent-bit?ref=v0.10.0"
  install_dependencies = var.install_dependencies
  fluentbit = {
    metrics = var.fluentbit.metrics
    systemd_services = concat(
      [{
        tag = var.fluentbit.systemd_remote_source_tag
        service = "systemd-remote-source.service"
      },
      {
        tag = var.fluentbit.systemd_remote_tag
        service = "systemd-remote.service"
      },
      {
        tag = var.fluentbit.node_exporter_tag
        service = "node-exporter.service"
      }],
      var.terraform_backend_etcd.enabled ? [{
        tag = var.fluentbit.terraform_backend_etcd_tag
        service = "terraform-backend-etcd.service"
      }] : []
    )
    forward = var.fluentbit.forward
  }
  etcd = var.fluentbit.etcd
}

module "systemd_remote_source_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//configurations-auto-updater?ref=v0.10.0"
  install_dependencies = var.install_dependencies
  filesystem = {
    path = var.systemd_remote.sync_directory
    files_permission = "700"
    directories_permission = "700"
  }
  etcd = {
    key_prefix = var.systemd_remote.client.etcd.key_prefix
    endpoints = var.systemd_remote.client.etcd.endpoints
    connection_timeout = "60s"
    request_timeout = "60s"
    retry_interval = "4s"
    retries = 15
    auth = {
      ca_certificate = var.systemd_remote.client.etcd.ca_certificate
      client_certificate = var.systemd_remote.client.etcd.client.certificate
      client_key = var.systemd_remote.client.etcd.client.key
      username = var.systemd_remote.client.etcd.client.username
      password = var.systemd_remote.client.etcd.client.password
    }
  }
  grpc_notifications = [{
    endpoint = "${var.systemd_remote.server.address}:${var.systemd_remote.server.port}"
    filter   = "^(.*[.]service)|(.*[.]timer)|(units.yml)$"
    trim_key_path = true
    max_chunk_size = 1048576
    retries = 15
    retry_interval = "4s"
    connection_timeout = "60s"
    request_timeout = "60s"
    auth = {
      ca_cert = var.systemd_remote.client.tls.ca_certificate
      client_cert = var.systemd_remote.client.tls.client_certificate
      client_key = var.systemd_remote.client.tls.client_key
    }
  }]
  naming = {
    binary = "systemd-remote-source"
    service = "systemd-remote-source"
  }
  user = "root"
}

module "systemd_remote_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//systemd-remote?ref=v0.10.0"
  server = var.systemd_remote.server
  install_dependencies = var.install_dependencies
}

module "terraform_backend_etcd_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//terraform-backend-etcd?ref=v0.10.0"
  server = var.terraform_backend_etcd.server
  etcd = var.terraform_backend_etcd.etcd
  install_dependencies = var.install_dependencies
}

module "chrony_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//chrony?ref=v0.7.0"
  install_dependencies = var.install_dependencies
  chrony = {
    servers  = var.chrony.servers
    pools    = var.chrony.pools
    makestep = var.chrony.makestep
  }
}

locals {
  cloudinit_templates = concat([
      {
        filename     = "base.cfg"
        content_type = "text/cloud-config"
        content = templatefile(
          "${path.module}/files/user_data.yaml.tpl", 
          {
            hostname = var.name
            ssh_host_key_rsa = var.ssh_host_key_rsa
            ssh_host_key_ecdsa = var.ssh_host_key_ecdsa
            install_dependencies = var.install_dependencies
            bootstrap_secrets = var.bootstrap_secrets
            bootstrap_configs = var.bootstrap_configs
            bootstrap_services = var.bootstrap_services
          }
        )
      },
      {
        filename     = "node_exporter.cfg"
        content_type = "text/cloud-config"
        content      = module.prometheus_node_exporter_configs.configuration
      },
      {
        filename     = "system_remote.cfg"
        content_type = "text/cloud-config"
        content      = module.systemd_remote_configs.configuration
      },
      {
        filename     = "system_remote_source.cfg"
        content_type = "text/cloud-config"
        content      = module.systemd_remote_source_configs.configuration
      }
    ],
    var.terraform_backend_etcd.enabled ? [{
      filename     = "terraform_backend_etcd.cfg"
      content_type = "text/cloud-config"
      content      = module.terraform_backend_etcd_configs.configuration
    }] : [],
    var.chrony.enabled ? [{
      filename     = "chrony.cfg"
      content_type = "text/cloud-config"
      content      = module.chrony_configs.configuration
    }] : [],
    var.fluentbit.enabled ? [{
      filename     = "fluent_bit.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_configs.configuration
    }] : []
  )
}

data "cloudinit_config" "user_data" {
  gzip = false
  base64_encode = false
  dynamic "part" {
    for_each = local.cloudinit_templates
    content {
      filename     = part.value["filename"]
      content_type = part.value["content_type"]
      content      = part.value["content"]
    }
  }
}

resource "openstack_compute_instance_v2" "automation_server" {
  name            = var.name
  image_id        = var.image_id
  flavor_id       = var.flavor_id
  key_pair        = var.keypair_name
  user_data = data.cloudinit_config.user_data.rendered

  network {
    port = var.network_port.id
  }

  scheduler_hints {
    group = var.server_group.id
  }

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
}