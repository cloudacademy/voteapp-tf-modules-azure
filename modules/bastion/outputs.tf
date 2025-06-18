output "bastion_public_ip" {
  value = azurerm_public_ip.bastion.ip_address
}
