output "nexus_private_url" {
  value = "http://10.20.1.10:8081"
}

output "runner_public_ip" {
  value = azurerm_public_ip.runner_pip.ip_address
}

output "runner_ssh_command" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.runner_pip.ip_address}"
}

output "container_app_url" {
  value = azurerm_container_app.app.latest_revision_fqdn
}