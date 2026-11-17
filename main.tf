# The cloud-config shared by every GlueKube machine on every platform: cluster nodes and bastions,
# on AWS and Proxmox. Built as an HCL object and rendered with yamlencode, so the output is a
# single plain `#cloud-config` document -- what Proxmox's cicustom snippets and EC2 user_data both
# take as-is, with no MIME multipart and no reliance on cloud-init's merge rules.
#
# Everything here is first-boot policy that has to be identical everywhere:
#   - automatic updates are off, before anything touches apt
#   - packages are upgraded once, and the machine always reboots afterwards
#   - GlueKube's Ansible (playbooks/wait-for-cloud-init.yaml) waits for that reboot by looking for
#     `power_state` in the cloud-config; drop it and that wait stops recognising the node.

locals {
  apt_units = [
    "apt-daily.timer",
    "apt-daily-upgrade.timer",
    "apt-daily.service",
    "apt-daily-upgrade.service",
    "unattended-upgrades.service",
  ]

  # Only platform-specific keys (e.g. rp_filter for a named interface). The Kubernetes sysctls --
  # bridge-nf-call, ip_forward and the node tuning -- belong to GlueKube's prepare-node.yaml, which
  # writes /etc/sysctl.d/99-kubernetes.conf and also reaches nodes that already exist. Do not
  # repeat a key here: two files setting it only work out by filename sort order.
  sysctls = var.extra_sysctls

  write_files = concat(
    length(local.sysctls) > 0 ? [{
      path    = "/etc/sysctl.d/k8s.conf"
      content = join("", [for k, v in local.sysctls : "${k} = ${v}\n"])
    }] : [],
    [{
      # Belt and braces with the masked units below: even if a later package run unmasks a
      # timer, apt.systemd.daily reads these and does nothing.
      path = "/etc/apt/apt.conf.d/20auto-upgrades"
      content = join("", [
        "APT::Periodic::Update-Package-Lists \"0\";\n",
        "APT::Periodic::Download-Upgradeable-Packages \"0\";\n",
        "APT::Periodic::AutocleanInterval \"0\";\n",
        "APT::Periodic::Unattended-Upgrade \"0\";\n",
      ])
    }],
  )

  # Unset permissions are dropped rather than rendered as `permissions: null`.
  extra_write_files = [
    for f in var.extra_write_files : { for k, v in f : k => v if v != null }
  ]

  runcmd = concat(
    length(local.sysctls) > 0 ? ["sysctl --system"] : [],
    var.extra_runcmd,
  )

  cloud_config = merge(
    {
      # bootcmd runs on every boot, in the init stage -- before the config stage where
      # package_upgrade runs -- so the apt-daily timers can neither race cloud-init for the dpkg
      # lock nor upgrade packages on their own later. mask is idempotent; --no-block keeps the
      # stop from waiting on units ordered after cloud-init.
      bootcmd = [
        "systemctl mask ${join(" ", local.apt_units)}",
        "systemctl stop --no-block ${join(" ", local.apt_units)}",
      ]

      package_update  = true
      package_upgrade = true
      packages        = distinct(concat(["curl"], var.extra_packages))

      hostname   = var.hostname
      ssh_pwauth = false
      users = [{
        name                = "cluster"
        groups              = "sudo"
        ssh_authorized_keys = [var.public_key]
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
        shell               = "/bin/bash"
      }]

      write_files = concat(local.write_files, local.extra_write_files)

      # Always reboot once cloud-init has finished, so the machine comes up on the upgraded kernel
      # and libraries. power_state is per-instance (first boot only) and waits for cloud-init,
      # runcmd included, to complete. Deliberately not package_reboot_if_required, which reboots
      # mid-run and only when a package asks for it.
      power_state = {
        mode      = "reboot"
        message   = "cloud-init finished, rebooting after package upgrade"
        timeout   = 30
        condition = true
      }
    },
    # Omitted rather than rendered as `runcmd: []` when there is nothing to run.
    { for k, v in { runcmd = local.runcmd } : k => v if length(v) > 0 },
    var.extra_cloud_config,
  )
}
