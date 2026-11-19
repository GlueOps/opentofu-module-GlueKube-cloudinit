output "user_data" {
  description = "The rendered `#cloud-config` document. Pass it to EC2 with base64encode(), or to a Proxmox snippet as-is."
  value       = "#cloud-config\n${yamlencode(local.cloud_config)}"
}
