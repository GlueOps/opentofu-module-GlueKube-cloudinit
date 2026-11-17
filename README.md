# opentofu-module-GlueKube-cloudinit

The cloud-init (`#cloud-config`) shared by every GlueKube machine: the cluster nodes and bastions
of [opentofu-module-GlueKube-AWS](https://github.com/GlueOps/opentofu-module-GlueKube-AWS) and
[opentofu-module-GlueKube-Proxmox](https://github.com/GlueOps/opentofu-module-GlueKube-Proxmox).

Pure HCL, no providers. The document is built as an HCL object and rendered with `yamlencode`, so
the output is one plain `#cloud-config` YAML document that EC2 `user_data` and Proxmox `cicustom`
snippets both take as-is.

## What every machine gets

- **Automatic updates off.** `bootcmd` masks `apt-daily{,-upgrade}.{timer,service}` and
  `unattended-upgrades.service` on every boot, before `package_upgrade` runs, and
  `/etc/apt/apt.conf.d/20auto-upgrades` sets every `APT::Periodic` knob to `0`.
- **One upgrade, then a reboot.** `package_update` + `package_upgrade`, then `power_state` reboots
  once cloud-init has finished (first boot only).
- The `cluster` user with passwordless sudo and the given SSH key; SSH password auth off.
- Any platform-specific sysctls passed in `extra_sysctls`, in `/etc/sysctl.d/k8s.conf`.

The Kubernetes sysctls (bridge-nf-call, `ip_forward` and node tuning) are not set here. GlueKube's
`ansible/roles/common/tasks/prepare-node.yaml` owns them, so they also reach existing nodes. Don't
pass those keys in `extra_sysctls`.

GlueKube's `ansible/playbooks/wait-for-cloud-init.yaml` waits for the reboot by finding
`power_state` in the node's cloud-config, and fails the run if cloud-init did not succeed. Keep
`power_state` here, or that wait stops recognising new nodes.

Platform differences are passed in with the `extra_*` inputs. Keys this module manages cannot be
overridden through `extra_cloud_config`.

## Usage

```hcl
module "cloud_init" {
  source = "git::https://github.com/GlueOps/opentofu-module-GlueKube-cloudinit.git?ref=v0.1.0" # x-release-please-version

  hostname   = "worker-pool-0"
  public_key = autoglue_ssh_key.ssh_key.public_key

  extra_sysctls  = { "net.ipv4.conf.all.rp_filter" = "0" }
  extra_packages = ["qemu-guest-agent"]
  extra_write_files = [{
    path        = "/etc/glueops/public-interface"
    content     = "eth1\n"
    permissions = "0644"
  }]
  extra_runcmd       = ["systemctl enable --now qemu-guest-agent"]
  extra_cloud_config = { mounts = [["swap", null]] }
}

# EC2
resource "aws_instance" "node" {
  user_data_base64 = base64encode(module.cloud_init.user_data)
  # ...
}

# Proxmox
resource "proxmox_virtual_environment_file" "node" {
  source_raw {
    data      = module.cloud_init.user_data
    file_name = "node-cloud-init.yaml"
  }
  # ...
}
```

## Development

```sh
tofu fmt -check -recursive
tofu init -backend=false && tofu validate
tofu test
```

<!-- BEGIN_TF_DOCS -->
# opentofu-module-GlueKube-cloudinit

The cloud-init (`#cloud-config`) shared by every GlueKube machine: the cluster nodes and bastions
of [opentofu-module-GlueKube-AWS](https://github.com/GlueOps/opentofu-module-GlueKube-AWS) and
[opentofu-module-GlueKube-Proxmox](https://github.com/GlueOps/opentofu-module-GlueKube-Proxmox).

Pure HCL, no providers. The document is built as an HCL object and rendered with `yamlencode`, so
the output is one plain `#cloud-config` YAML document that EC2 `user_data` and Proxmox `cicustom`
snippets both take as-is.

## What every machine gets

- **Automatic updates off.** `bootcmd` masks `apt-daily{,-upgrade}.{timer,service}` and
  `unattended-upgrades.service` on every boot, before `package_upgrade` runs, and
  `/etc/apt/apt.conf.d/20auto-upgrades` sets every `APT::Periodic` knob to `0`.
- **One upgrade, then a reboot.** `package_update` + `package_upgrade`, then `power_state` reboots
  once cloud-init has finished (first boot only).
- The `cluster` user with passwordless sudo and the given SSH key; SSH password auth off.
- Any platform-specific sysctls passed in `extra_sysctls`, in `/etc/sysctl.d/k8s.conf`.

The Kubernetes sysctls (bridge-nf-call, `ip_forward` and node tuning) are not set here. GlueKube's
`ansible/roles/common/tasks/prepare-node.yaml` owns them, so they also reach existing nodes. Don't
pass those keys in `extra_sysctls`.

GlueKube's `ansible/playbooks/wait-for-cloud-init.yaml` waits for the reboot by finding
`power_state` in the node's cloud-config, and fails the run if cloud-init did not succeed. Keep
`power_state` here, or that wait stops recognising new nodes.

Platform differences are passed in with the `extra_*` inputs. Keys this module manages cannot be
overridden through `extra_cloud_config`.

## Usage

```hcl
module "cloud_init" {
  source = "git::https://github.com/GlueOps/opentofu-module-GlueKube-cloudinit.git?ref=v0.1.0" # x-release-please-version

  hostname   = "worker-pool-0"
  public_key = autoglue_ssh_key.ssh_key.public_key

  extra_sysctls  = { "net.ipv4.conf.all.rp_filter" = "0" }
  extra_packages = ["qemu-guest-agent"]
  extra_write_files = [{
    path        = "/etc/glueops/public-interface"
    content     = "eth1\n"
    permissions = "0644"
  }]
  extra_runcmd       = ["systemctl enable --now qemu-guest-agent"]
  extra_cloud_config = { mounts = [["swap", null]] }
}

# EC2
resource "aws_instance" "node" {
  user_data_base64 = base64encode(module.cloud_init.user_data)
  # ...
}

# Proxmox
resource "proxmox_virtual_environment_file" "node" {
  source_raw {
    data      = module.cloud_init.user_data
    file_name = "node-cloud-init.yaml"
  }
  # ...
}
```

## Development

```sh
tofu fmt -check -recursive
tofu init -backend=false && tofu validate
tofu test
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_extra_cloud_config"></a> [extra\_cloud\_config](#input\_extra\_cloud\_config) | Additional top-level cloud-config keys merged into the document, for anything the inputs above<br/>do not cover (e.g. `mounts`). Keys this module manages cannot be set here -- use the matching<br/>extra\_* input instead -- so a caller cannot silently drop the update policy or the reboot. | `any` | `{}` | no |
| <a name="input_extra_packages"></a> [extra\_packages](#input\_extra\_packages) | Packages installed in addition to the base set (curl). | `list(string)` | `[]` | no |
| <a name="input_extra_runcmd"></a> [extra\_runcmd](#input\_extra\_runcmd) | Commands appended to runcmd, after the base ones. They run as root in the final stage, before the power\_state reboot. | `list(string)` | `[]` | no |
| <a name="input_extra_sysctls"></a> [extra\_sysctls](#input\_extra\_sysctls) | Platform-specific sysctls (key => value) written to /etc/sysctl.d/k8s.conf, e.g. rp\_filter for a named interface. Nothing is written when empty. Kubernetes sysctls (bridge-nf-call, ip\_forward, node tuning) are set by GlueKube's Ansible, not here. | `map(string)` | `{}` | no |
| <a name="input_extra_write_files"></a> [extra\_write\_files](#input\_extra\_write\_files) | Files written in addition to the base set (apt auto-upgrade disable, and k8s.conf when extra\_sysctls is set). | <pre>list(object({<br/>    path        = string<br/>    content     = string<br/>    permissions = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | Hostname the machine sets on first boot. | `string` | n/a | yes |
| <a name="input_public_key"></a> [public\_key](#input\_public\_key) | SSH public key authorised for the `cluster` user. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_user_data"></a> [user\_data](#output\_user\_data) | The rendered `#cloud-config` document. Pass it to EC2 with base64encode(), or to a Proxmox snippet as-is. |
<!-- END_TF_DOCS -->
