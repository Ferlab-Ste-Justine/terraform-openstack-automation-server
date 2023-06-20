variable "name" {
  description = "Name of the vm"
  type = string
}

variable "network_port" {
  description = "Network port to assign to the node. Should be of type openstack_networking_port_v2"
  type        = any
}

variable "server_group" {
  description = "Server group to assign to the node. Should be of type openstack_compute_servergroup_v2"
  type        = any
}

variable "image_id" {
    description = "ID of the vm image used to provision the node"
    type = string
}

variable "flavor_id" {
  description = "ID of the VM flavor"
  type = string
}

variable "keypair_name" {
  description = "Name of the keypair that will be used by admins to ssh to the node"
  type = string
}

variable "ssh_host_key_rsa" {
  type = object({
    public = string
    private = string
  })
  default = {
    public = ""
    private = ""
  }
}

variable "ssh_host_key_ecdsa" {
  type = object({
    public = string
    private = string
  })
  default = {
    public = ""
    private = ""
  }
}

variable "chrony" {
  description = "Chrony configuration for ntp. If enabled, chrony is installed and configured, else the default image ntp settings are kept"
  type        = object({
    enabled = bool,
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server
    servers = list(object({
      url = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool
    pools = list(object({
      url = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep
    makestep = object({
      threshold = number,
      limit = number
    })
  })
  default = {
    enabled = false
    servers = []
    pools = []
    makestep = {
      threshold = 0,
      limit = 0
    }
  }
}

variable "install_dependencies" {
  description = "Whether to install all dependencies in cloud-init"
  type = bool
  default = true
}

variable "terraform_backend_etcd" {
  description = "Optional terraform backend service using etcd as a backend"
  type        = object({
    enabled = bool
    server = object({
      port = number
      address = string
      tls = object({
        ca_certificate = string
        server_certificate = string
        server_key = string
      })
      auth = object({
        username = string
        password = string
      })
    })
    etcd = object({
      endpoints = list(string)
      ca_certificate = string
      client = object({
        certificate = string
        key = string
        username = string
        password = string
      })
    })
  })
  default = {
    enabled = false
    server = {
      port = 0
      address = ""
      tls = {
        ca_certificate = ""
        server_certificate = ""
        server_key = ""
      }
      auth = {
        username = ""
        password = ""
      }
    }
    etcd = {
      key_prefix = ""
      endpoints = []
      ca_certificate = ""
      client = {
        certificate = ""
        key = ""
        username = ""
        password = ""
      }
    }
  }
}

variable "systemd_remote" {
  description = "Parameters for systemd-remote service. Certs are used by client and server for mtls communication"
  type        = object({
    server = object({
      port = number
      address = string
      tls = object({
        ca_certificate = string
        server_certificate = string
        server_key = string
      })
    })
    client = object({
      tls = object({
        ca_certificate     = string
        client_certificate = string
        client_key         = string
      })
    })
    sync_directory = string
  })
}

variable "systemd_remote_source" {
  description = "Parameters for systemd-remote source service."
  type        = object({
    source = string
    etcd = object({
      key_prefix = string
      endpoints = list(string)
      ca_certificate = string
      client = object({
        certificate = string
        key = string
        username = string
        password = string
      })
    })
    git = object({
      repo = string
      ref  = string
      path = string
      auth = object({
        client_ssh_key         = string
        server_ssh_fingerprint = string
      })
      trusted_gpg_keys = list(string)
    })
  })

  validation {
    condition     = contains(["etcd", "git"], var.systemd_remote_source.source)
    error_message = "systemd_remote_source.source must be 'etcd' or 'git'."
  }
}

variable "bootstrap_secrets" {
  description = "Secrets that boostrap the orchestration"
  sensitive = true
  type = list(object({
    path  = string
    content = string
  }))
  default = []
}

variable "bootstrap_configs" {
  description = "Configs to bootstrap the orchestration"
  type = list(object({
    path  = string
    content = string
  }))
  default = []
}

variable "bootstrap_services" {
  description = "Systemd services to enable and start"
  type = list(string)
    default = []
}

variable "fluentbit" {
  description = "Fluent-bit configuration"
  type = object({
    enabled = bool
    systemd_remote_source_tag = string
    systemd_remote_tag = string
    terraform_backend_etcd_tag = string
    node_exporter_tag = string
    metrics = object({
      enabled = bool
      port    = number
    })
    forward = object({
      domain = string
      port = number
      hostname = string
      shared_key = string
      ca_cert = string
    })
  })
  default = {
    enabled = false
    systemd_remote_source_tag = ""
    systemd_remote_tag = ""
    terraform_backend_etcd_tag = ""
    node_exporter_tag = ""
    metrics = {
      enabled = false
      port = 0
    }
    forward = {
      domain = ""
      port = 0
      hostname = ""
      shared_key = ""
      ca_cert = ""
    }
  }
}

variable "fluentbit_dynamic_config" {
  description = "Parameters for fluent-bit dynamic config if it is enabled"
  type = object({
    enabled = bool
    source  = string
    etcd    = object({
      key_prefix     = string
      endpoints      = list(string)
      ca_certificate = string
      client         = object({
        certificate = string
        key         = string
        username    = string
        password    = string
      })
    })
    git     = object({
      repo             = string
      ref              = string
      path             = string
      trusted_gpg_keys = list(string)
      auth             = object({
        client_ssh_key         = string
        server_ssh_fingerprint = string
      })
    })
  })
  default = {
    enabled = false
    source = "etcd"
    etcd = {
      key_prefix     = ""
      endpoints      = []
      ca_certificate = ""
      client         = {
        certificate = ""
        key         = ""
        username    = ""
        password    = ""
      }
    }
    git  = {
      repo             = ""
      ref              = ""
      path             = ""
      trusted_gpg_keys = []
      auth             = {
        client_ssh_key         = ""
        server_ssh_fingerprint = ""
      }
    }
  }

  validation {
    condition     = contains(["etcd", "git"], var.fluentbit_dynamic_config.source)
    error_message = "fluentbit_dynamic_config.source must be 'etcd' or 'git'."
  }
}