output "frontend_vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.frontend.name
}

output "frontend_backend_pool_id" {
  value = azurerm_lb_backend_address_pool.frontend.id
}

output "loadbalancer" {
  value = {
    fqdn      = azurerm_public_ip.loadbalancer.fqdn
    public_ip = azurerm_public_ip.loadbalancer.ip_address
  }
}
