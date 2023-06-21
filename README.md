# About

This terraform module is used to provision an automation server running terraform workflows that is easily editable via etcd configurations.

It is meant to be espescially useful in an on-prem setup where you start with very little and would prefer to minimize the number of terraform workflows you need to manage by hand (to ideally just this server and only when bootstrapping automation, if etcd is down or when performing routine updates on the automation server).

It has two kinds of workflows:
  - Static workflow defined via cloud-init that can be used to bootstrap (and change by reprovisioning the server) the etcd cluster that the server will take its configurations from. Note that these jobs maybe be overwriten dynamically once you have a running etcd cluster that you can read dynamic configurations from.
  - Dynamic workflows defined in either in a git repo or in an etcd key prefix. Systemd unit files, units on/off status, other dependent configuration files as well as optional fluent-bit output redirection are editable this way.

The server has the following tools integrated to support terraform jobs:
- terraform: https://www.terraform.io/
- terracd: https://github.com/Ferlab-Ste-Justine/terracd
- terraform-backend-etcd (optional): https://github.com/Ferlab-Ste-Justine/terraform-backend-etcd

# Usage

## Inputs

This module takes the following variables as input:

- **name**: Name to give to the vm.
- **network_port**: Resource of type **openstack_networking_port_v2** to assign to the vm for network connectivity.
- **server_group**: Server group to assign to the node. Should be of type **openstack_compute_servergroup_v2**.
- **image_id**: Id of the vm image used to provision the node
- **flavor_id**: Id of the VM flavor
- **keypair_name**: Name of the keypair that will be used to ssh to the node
- **ssh_host_key_rsa**: Rsa host key that will be used by the vm's ssh server. If omitted, a random key will be generated. Expects the following 2 properties:
  - **public**: Public part of the key, in "authorized keys" format.
  - **private**: Private part of the key, in openssh pem format.
- **ssh_host_key_ecdsa**: Ecdsa host key that will be used by the vm's ssh server. If omitted, a random key will be generated. Expects the following 2 properties:
  - **public**: Public part of the key, in "authorized keys" format.
  - **private**: Private part of the key, in openssh pem format.
- **chrony**: Optional chrony configuration for when you need a more fine-grained ntp setup on your vm. It is an object with the following fields:
  - **enabled**: If set the false (the default), chrony will not be installed and the vm ntp settings will be left to default.
  - **servers**: List of ntp servers to sync from with each entry containing two properties, **url** and **options** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server)
  - **pools**: A list of ntp server pools to sync from with each entry containing two properties, **url** and **options** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool)
  - **makestep**: An object containing remedial instructions if the clock of the vm is significantly out of sync at startup. It is an object containing two properties, **threshold** and **limit** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep)
- **fluentbit**: Optional fluent-bit configuration to securely route logs to a fluend/fluent-bit node using the forward plugin. Alternatively, configuration can be 100% dynamic by specifying the parameters of an etcd store or git repo to fetch the configuration from. It has the following keys:
  - **enabled**: If set the false (the default), fluent-bit will not be installed.
  - **systemd_remote_source_tag**: Tag to assign to logs coming from the process that reads configuration from etcd and forwards systemd unit changes to **systemd-remote**.
  - **systemd_remote_tag**: Tag to assign to logs coming from **systemd-remote**
  - **terraform_backend_etcd_tag**: Tag to assign to logs coming from the **terraform-etcd-backend** service, if it is running.
  - **node_exporter_tag** Tag to assign to logs coming from the prometheus node exporter
  - **forward**: Configuration for the forward plugin that will talk to the external fluend/fluent-bit node. It has the following keys:
    - **domain**: Ip or domain name of the remote fluend node.
    - **port**: Port the remote fluend node listens on
    - **hostname**: Unique hostname identifier for the vm
    - **shared_key**: Secret shared key with the remote fluentd node to authentify the client
    - **ca_cert**: CA certificate that signed the remote fluentd node's server certificate (used to authentify it)
**fluentbit_dynamic_config**: Optional configuration to update fluent-bit configuration dynamically either from an etcd key prefix or a path in a git repo.
  - **enabled**: Boolean flag to indicate whether dynamic configuration is enabled at all. If set to true, configurations will be set dynamically. The default configurations can still be referenced as needed by the dynamic configuration. They are at the following paths:
    - **Global Service Configs**: /etc/fluent-bit-customization/default-config/fluent-bit-service.conf
    - **Systemd Inputs**: /etc/fluent-bit-customization/default-config/fluent-bit-inputs.conf
    - **Forward Output**: /etc/fluent-bit-customization/default-config/fluent-bit-output.conf
  - **source**: Indicates the source of the dynamic config. Can be either **etcd** or **git**.
  - **etcd**: Parameters to fetch fluent-bit configurations dynamically from an etcd cluster. It has the following keys:
    - **key_prefix**: Etcd key prefix to search for fluent-bit configuration
    - **endpoints**: Endpoints of the etcd cluster. Endpoints should have the format `<ip>:<port>`
    - **ca_certificate**: CA certificate against which the server certificates of the etcd cluster will be verified for authenticity
    - **client**: Client authentication. It takes the following keys:
      - **certificate**: Client tls certificate to authentify with. To be used for certificate authentication.
      - **key**: Client private tls key to authentify with. To be used for certificate authentication.
      - **username**: Client's username. To be used for username/password authentication.
      - **password**: Client's password. To be used for username/password authentication.
  - **git**: Parameters to fetch fluent-bit configurations dynamically from an git repo. It has the following keys:
    - **repo**: Url of the git repository. It should have the ssh format.
    - **ref**: Git reference (usually branch) to checkout in the repository
    - **path**: Path to sync from in the git repository. If the empty string is passed, syncing will happen from the root of the repository.
    - **trusted_gpg_keys**: List of trusted gpp keys to verify the signature of the top commit. If an empty list is passed, the commit signature will not be verified.
    - **auth**: Authentication to the git server. It should have the following keys:
      - **client_ssh_key** Private client ssh key to authentication to the server.
      - **server_ssh_fingerprint**: Public ssh fingerprint of the server that will be used to authentify it.
- **install_dependencies**: Whether cloud-init should install external dependencies (should be set to false if you already provide an image with the external dependencies built-in).
- **bootstrap_secrets**: List of static secrets to pass to the server. Each entry should have the following keys:
  - **path**: Filesystem path of the secret on the server.
  - **content**: Content of the secret on the server
- **bootstrap_configs**: List of static configuration files to pass to the server. Each entry should have the following keys:
  - **path**: Filesystem path of the configuration on the server.
  - **content**: Content of the configuration on the server
- **bootstrap_services**: List of systemd unit files to enable and start when the server is initialized. 
- **systemd_remote**: Parameters for the dynamically configuration systemd units. It should have the following keys:
  - **server**: Configuration for the **systemd-remote** server. It should have the following keys:
    - **port**: Port that **systemd-remote** will listen on.
    - **address**: Address that **systemd-remote** will bind on.
    - **tls**: Tls parameters for **systemd-remote**. It should have the folllowing keys:
      - **ca_certificate**: CA cert that will be used to authentify local client requests.
      - **server_certificate**: Server certificate that will authentify **systemd-remote** to the local client.
      - **server-key**: Requisite private key that accompanies the server certificate.
  - **client**: Parameters for the client that will synchronize the server's filesystem with configuration changes in the etcd keyspace and notify **systemd-remote** of changes impacting systemd units directly. It should have the following keys:
    - **tls**: Tls parameters for the connection with **systemd-remote**. It should have the following keys:
      - **ca_certificate**: CA certificate that will authentify the server's certificate.
      - **client_certificate**: Client certificate to authentify with the server.
      - **client_key**: Client's private key that accompanies the certificate.
  - **sync_directory**: Directory on the server's filesystem where the dynamic configuration will be synchronized. Note that additionally to this directory, **systemd-remote** will forward unit files changes to the **/etc/systemd/system** directory.
- **systemd_remote_source**: Configuration for the source of files that will be forwared to **systemd-remote** and otherwise synchronized to the filesystem. Either an etcd or git source should be specified. It has the following keys:
  - **source**: Indicates the source of the dynamic config. Can be either **etcd** or **git**.
  - **etcd**: Parameters for an etcd source. It should have the following keys:
    - **key_prefix**: Key prefix that should be scanned for configuration files
    - **endpoints**: Endpoints of the etcd cluster. The format of each endpoint should be `<ip>:<port>`.
    - **ca_certificate**: CA certificate used to authentify the etcd servers' certificates
    - **client**: Client authentication parameters to authentify to the etcd cluster. It should have the following keys:
      - **certificate**: Client's certificate if certificate authentication is used.
      - **key**: Client's private key if certificate authentication is used.
      - **username**: Client's username if username/password authentication is used.
      - **password**: Client's password is username/password authentication is used.
  - **git**: Parameters for a git repository source. It has the following keys:
    - **repo**: Url of the git repository. It should have the ssh format.
    - **ref**: Git reference (usually branch) to checkout in the repository
    - **path**: Path to sync from in the git repository. If the empty string is passed, syncing will happen from the root of the repository.
    - **trusted_gpg_keys**: List of trusted gpp keys to verify the signature of the top commit. If an empty list is passed, the commit signature will not be verified.
    - **auth**: Authentication to the git server. It should have the following keys:
      - **client_ssh_key** Private client ssh key to authentication to the server.
      - **server_ssh_fingerprint**: Public ssh fingerprint of the server that will be used to authentify it.
- **terraform_backend_etcd**: Parameters to setup an optional http service acting as an etcd backend for terraform. It should have the following keys:
  - **enabled**: If true, the service will be setup and enabled.
  - **server**: Terraform-facing parameters for the http server.
    - **port**: Port the server should listen on.
    - **address**: Ip address the server should bind to.
    - **tls**: Tls parameters the server should use for a secure connection. It should have the following keys.
      - **ca_certificate**: CA certificate that was used to sign the server's certificate. It will be installed in the os which will allow local terraform workflows to trust it.
      - **server_certificate**: Server certificate that will be presented to clients to authenticate the server.
      - **server_key**: Server's private key that will accompany its certificate.
    - **auth**: Username/password authentication parameters that the server will expect from terraform clients.
      - **username**: Username that clients should present.
      - **password**: Password that clients should present.
  - **etcd**: Parameters the server will use to connect against the etcd backend and persist the terraform state presented by terraform clients.
    - **endpoints**: Endpoints of the etcd cluster. The format of each endpoint should be `<ip>:<port>`.
    - **ca_certificate**: CA certificate used to authentify the etcd servers' certificates
    - **client**: Client authentication parameters to authentify to the etcd cluster. It should have the following keys:
      - **certificate**: Client's certificate if certificate authentication is used.
      - **key**: Client's private key if certificate authentication is used.
      - **username**: Client's username if username/password authentication is used.
      - **password**: Client's password is username/password authentication is used.

## Example

An example that can be run locally can be found here:

https://github.com/Ferlab-Ste-Justine/kvm-dev-orchestrations/tree/main/automation-server

https://github.com/Ferlab-Ste-Justine/kvm-dev-orchestrations/tree/main/automation-server-configurations

The example runs harmless mock workflows that are safe to run locally. You should follow the README instructions in the project to setup your environment.

## Dynamic Configuration Worflow

All configuration files in the etcd key prefix or git repository (at the given path of the given reference) will be sychronized with **systemd_remote.sync_directory** on the server.

All changes addition/update/deletion to files with a **.service** suffix, files with a **.timer** suffix or to a file named **units.yml** will additionally be pushed to **systemd-remote** which will adjust systemd units accordingly.

How **systemd-remote** reconciles the system with file changes is best read in the project's README documentation: https://github.com/Ferlab-Ste-Justine/systemd-remote

Additionally, if fluent-bit is enabled dynamically (**fluentbit.etcd.enabled**), the content of the directory **/etc/fluent-bit-customization/dynamic-config** will be synchronized (and fluentbit will receive a reload signal on change) with the content of an etcd key prefix or git repository (at the given path of the given reference). Fluent-bit will use **/etc/fluent-bit-customization/dynamic-config/index.conf** as its entrypoint configuration.

## Dependency Considerations

Given its intended role as the origin of orchestration, care should be taken not to couple the provisioning of the server with some of the dependencies being provisioned.

In particular, any etcd resources used to setup the dynamic configuration of the server (if an etcd source is used instead of a git repo for dynamic configuration retrieval) should be done in a terraform orchestration that is separate from the server, that way if ever etcd is down and needs to be restored, you'll be able to orchestrate it in a static workflow.