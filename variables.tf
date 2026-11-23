variable "hostname" {
  description = "Hostname the machine sets on first boot."
  type        = string

  validation {
    condition     = length(var.hostname) > 0
    error_message = "hostname must not be empty."
  }
}

variable "public_key" {
  description = "SSH public key authorised for the `cluster` user."
  type        = string

  validation {
    condition     = length(trimspace(var.public_key)) > 0
    error_message = "public_key must not be empty."
  }
}

variable "extra_sysctls" {
  description = "Platform-specific sysctls (key => value) written to /etc/sysctl.d/k8s.conf, e.g. rp_filter for a named interface. Nothing is written when empty. Kubernetes sysctls (bridge-nf-call, ip_forward, node tuning) are set by GlueKube's Ansible, not here."
  type        = map(string)
  default     = {}
}

variable "extra_packages" {
  description = "Packages installed in addition to the base set (curl)."
  type        = list(string)
  default     = []
}

variable "extra_write_files" {
  description = "Files written in addition to the base set (apt auto-upgrade disable, and k8s.conf when extra_sysctls is set)."
  type = list(object({
    path        = string
    content     = string
    permissions = optional(string)
  }))
  default = []
}

variable "extra_runcmd" {
  description = "Commands appended to runcmd, after the base ones. They run as root in the final stage, before the power_state reboot, under `set -e`: a failing command stops the remaining ones and fails the first boot, so append `|| true` to a command whose failure is acceptable."
  type        = list(string)
  default     = []
}

variable "extra_cloud_config" {
  description = <<-EOT
    Additional top-level cloud-config keys merged into the document, for anything the inputs above
    do not cover (e.g. `mounts`). Keys this module manages cannot be set here -- use the matching
    extra_* input instead -- so a caller cannot silently drop the update policy, the apt mirror or the reboot.
  EOT
  type        = any
  default     = {}

  validation {
    condition = length(setintersection(keys(var.extra_cloud_config), [
      "apt", "bootcmd", "hostname", "package_update", "package_upgrade", "packages", "power_state",
      "runcmd", "ssh_pwauth", "users", "write_files",
    ])) == 0
    error_message = "extra_cloud_config must not set a key this module manages (apt, bootcmd, hostname, package_update, package_upgrade, packages, power_state, runcmd, ssh_pwauth, users, write_files). Use extra_packages, extra_write_files or extra_runcmd instead."
  }
}
