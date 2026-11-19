# Plan-only, no providers. Decodes the rendered document and checks the policy every GlueKube
# machine depends on, so a refactor here cannot quietly drop it.

variables {
  hostname   = "worker-a-0"
  public_key = "ssh-ed25519 AAAAtest test"
}

run "defaults" {
  command = plan

  assert {
    condition     = startswith(output.user_data, "#cloud-config\n")
    error_message = "user_data must start with the #cloud-config header."
  }

  assert {
    condition     = yamldecode(output.user_data).package_upgrade == true
    error_message = "package_upgrade must be on."
  }

  assert {
    condition     = yamldecode(output.user_data).power_state.mode == "reboot"
    error_message = "power_state must reboot: GlueKube's wait-for-cloud-init.yaml keys off it."
  }

  assert {
    condition     = yamldecode(output.user_data).power_state.condition == "/usr/local/sbin/gluekube-first-boot-marker"
    error_message = "power_state.condition must run the first-boot marker script."
  }

  # GlueKube's wait-for-cloud-init.yaml recognises new nodes by this path in the cloud-config,
  # and reads boot 1's result from it after the reboot.
  assert {
    condition = anytrue([
      for f in yamldecode(output.user_data).write_files :
      f.path == "/usr/local/sbin/gluekube-first-boot-marker" && f.permissions == "0755" && strcontains(f.content, "/var/lib/cloud/instance/first-boot.json")
    ])
    error_message = "The first-boot marker script must be written, executable, and write /var/lib/cloud/instance/first-boot.json."
  }

  # Same mirror as GlueKube's roles/apt_sources, so first boot's update/upgrade goes through it.
  assert {
    condition     = yamldecode(output.user_data).apt.preserve_sources_list == false
    error_message = "cloud-init must write the apt sources, not keep the image's."
  }

  assert {
    condition = alltrue([
      for suffix in ["", "-updates", "-security"] :
      strcontains(yamldecode(output.user_data).apt.sources_list, "URIs: https://repo.gpkg.io/repository/ubuntu-$RELEASE${suffix}\nSuites: $RELEASE${suffix}\n")
    ])
    error_message = "apt.sources_list must point every Ubuntu suite at the mirror."
  }

  assert {
    condition     = !strcontains(yamldecode(output.user_data).apt.sources_list, "deb ")
    error_message = "apt.sources_list must be deb822, so cloud-init writes ubuntu.sources and stubs sources.list."
  }

  assert {
    condition     = !can(yamldecode(output.user_data).package_reboot_if_required)
    error_message = "package_reboot_if_required must not be set alongside power_state."
  }

  assert {
    condition     = strcontains(yamldecode(output.user_data).bootcmd[0], "systemctl mask") && strcontains(yamldecode(output.user_data).bootcmd[0], "unattended-upgrades.service")
    error_message = "bootcmd must mask the automatic update units."
  }

  assert {
    condition     = contains([for f in yamldecode(output.user_data).write_files : f.path], "/etc/apt/apt.conf.d/20auto-upgrades")
    error_message = "20auto-upgrades must be written."
  }

  assert {
    condition     = yamldecode(output.user_data).users[0].ssh_authorized_keys == ["ssh-ed25519 AAAAtest test"]
    error_message = "The cluster user must carry public_key."
  }

  # The Kubernetes sysctls are GlueKube's (prepare-node.yaml); none are built in here.
  assert {
    condition     = !contains([for f in yamldecode(output.user_data).write_files : f.path], "/etc/sysctl.d/k8s.conf")
    error_message = "No sysctl file without extra_sysctls."
  }

  assert {
    condition     = !can(yamldecode(output.user_data).runcmd)
    error_message = "runcmd is omitted when there is nothing to run."
  }
}

run "platform_extras" {
  command = plan

  variables {
    extra_sysctls      = { "net.ipv4.conf.all.rp_filter" = "0" }
    extra_packages     = ["qemu-guest-agent", "curl"]
    extra_write_files  = [{ path = "/etc/glueops/public-interface", content = "eth1\n", permissions = "0644" }]
    extra_runcmd       = ["passwd -d root"]
    extra_cloud_config = { mounts = [["swap", null]] }
  }

  assert {
    condition     = strcontains([for f in yamldecode(output.user_data).write_files : f.content if f.path == "/etc/sysctl.d/k8s.conf"][0], "net.ipv4.conf.all.rp_filter = 0")
    error_message = "extra_sysctls must land in k8s.conf."
  }

  assert {
    condition     = yamldecode(output.user_data).packages == ["curl", "qemu-guest-agent"]
    error_message = "extra_packages are appended and de-duplicated."
  }

  assert {
    condition     = [for f in yamldecode(output.user_data).write_files : f.permissions if f.path == "/etc/glueops/public-interface"] == ["0644"]
    error_message = "extra_write_files keep their permissions."
  }

  assert {
    condition     = yamldecode(output.user_data).runcmd == ["sysctl --system", "passwd -d root"]
    error_message = "extra_runcmd runs after the base commands."
  }

  assert {
    condition     = yamldecode(output.user_data).mounts[0][0] == "swap"
    error_message = "extra_cloud_config keys are merged in."
  }
}

run "managed_keys_are_protected" {
  command = plan

  variables {
    extra_cloud_config = { power_state = { mode = "poweroff" } }
  }

  expect_failures = [var.extra_cloud_config]
}

run "apt_mirror_is_protected" {
  command = plan

  variables {
    extra_cloud_config = { apt = { preserve_sources_list = true } }
  }

  expect_failures = [var.extra_cloud_config]
}
