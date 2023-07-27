locals {
  fluentbit_updater_etcd = var.fluentbit.enabled && var.fluentbit_dynamic_config.enabled && var.fluentbit_dynamic_config.source == "etcd"
  fluentbit_updater_git = var.fluentbit.enabled && var.fluentbit_dynamic_config.enabled && var.fluentbit_dynamic_config.source == "git"
  block_devices = var.image_source.volume_id != "" ? [{
    uuid                  = var.image_source.volume_id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = false
  }] : []
}

module "prometheus_node_exporter_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//prometheus-node-exporter?ref=v0.12.0"
  install_dependencies = var.install_dependencies
}

module "fluentbit_updater_etcd_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//configurations-auto-updater?ref=v0.12.0"
  install_dependencies = var.install_dependencies
  filesystem = {
    path = "/etc/fluent-bit-customization/dynamic-config"
    files_permission = "700"
    directories_permission = "700"
  }
  etcd = {
    key_prefix = var.fluentbit_dynamic_config.etcd.key_prefix
    endpoints = var.fluentbit_dynamic_config.etcd.endpoints
    connection_timeout = "60s"
    request_timeout = "60s"
    retry_interval = "4s"
    retries = 15
    auth = {
      ca_certificate = var.fluentbit_dynamic_config.etcd.ca_certificate
      client_certificate = var.fluentbit_dynamic_config.etcd.client.certificate
      client_key = var.fluentbit_dynamic_config.etcd.client.key
      username = var.fluentbit_dynamic_config.etcd.client.username
      password = var.fluentbit_dynamic_config.etcd.client.password
    }
  }
  notification_command = {
    command = ["/usr/local/bin/reload-fluent-bit-configs"]
    retries = 30
  }
  naming = {
    binary = "fluent-bit-config-updater"
    service = "fluent-bit-config-updater"
  }
  user = "fluentbit"
}

module "fluentbit_updater_git_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//gitsync?ref=v0.12.0"
  install_dependencies = var.install_dependencies
  filesystem = {
    path = "/etc/fluent-bit-customization/dynamic-config"
    files_permission = "700"
    directories_permission = "700"
  }
  git = var.fluentbit_dynamic_config.git
  notification_command = {
    command = ["/usr/local/bin/reload-fluent-bit-configs"]
    retries = 30
  }
  naming = {
    binary = "fluent-bit-config-updater"
    service = "fluent-bit-config-updater"
  }
  user = "fluentbit"
}

module "fluentbit_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//fluent-bit?ref=v0.12.0"
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
  dynamic_config = {
    enabled = var.fluentbit_dynamic_config.enabled
    entrypoint_path = "/etc/fluent-bit-customization/dynamic-config/index.conf"
  }
}

module "systemd_remote_source_etcd_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//configurations-auto-updater?ref=v0.12.0"
  install_dependencies = var.install_dependencies
  filesystem = {
    path = var.systemd_remote.sync_directory
    files_permission = "700"
    directories_permission = "700"
  }
  etcd = {
    key_prefix = var.systemd_remote_source.etcd.key_prefix
    endpoints = var.systemd_remote_source.etcd.endpoints
    connection_timeout = "60s"
    request_timeout = "60s"
    retry_interval = "4s"
    retries = 15
    auth = {
      ca_certificate = var.systemd_remote_source.etcd.ca_certificate
      client_certificate = var.systemd_remote_source.etcd.client.certificate
      client_key = var.systemd_remote_source.etcd.client.key
      username = var.systemd_remote_source.etcd.client.username
      password = var.systemd_remote_source.etcd.client.password
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

module "systemd_remote_source_git_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//gitsync?ref=v0.12.0"
  install_dependencies = var.install_dependencies
  filesystem = {
    path = var.systemd_remote.sync_directory
    files_permission = "700"
    directories_permission = "700"
  }
  git = var.systemd_remote_source.git
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
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//systemd-remote?ref=v0.12.0"
  server = var.systemd_remote.server
  install_dependencies = var.install_dependencies
}

module "terraform_backend_etcd_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//terraform-backend-etcd?ref=v0.12.0"
  server = var.terraform_backend_etcd.server
  etcd = var.terraform_backend_etcd.etcd
  install_dependencies = var.install_dependencies
}

module "chrony_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//chrony?ref=v0.12.0"
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
      }
    ],
    var.systemd_remote_source.source == "etcd" ? [{
      filename     = "system_remote_source.cfg"
      content_type = "text/cloud-config"
      content      = module.systemd_remote_source_etcd_configs.configuration
    }]: [],
    var.systemd_remote_source.source == "git" ? [{
      filename     = "system_remote_source.cfg"
      content_type = "text/cloud-config"
      content      = module.systemd_remote_source_git_configs.configuration
    }]: [],
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
    local.fluentbit_updater_etcd ? [{
      filename     = "fluent_bit_updater.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_updater_etcd_configs.configuration
    }] : [],
    local.fluentbit_updater_git ? [{
      filename     = "fluent_bit_updater.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_updater_git_configs.configuration
    }] : [],
    var.fluentbit.enabled ? [{
      filename     = "fluent_bit.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_configs.configuration
    }] : []
  )
}

data "cloudinit_config" "user_data" {
  gzip = true
  base64_encode = true
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
  image_id        = var.image_source.image_id != "" ? var.image_source.image_id : null
  flavor_id       = var.flavor_id
  key_pair        = var.keypair_name
  user_data = data.cloudinit_config.user_data.rendered

  network {
    port = var.network_port.id
  }

  dynamic "block_device" {
    for_each = local.block_devices
    content {
      uuid                  = block_device.value["uuid"]
      source_type           = block_device.value["source_type"]
      boot_index            = block_device.value["boot_index"]
      destination_type      = block_device.value["destination_type"]
      delete_on_termination = block_device.value["delete_on_termination"]
    }
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