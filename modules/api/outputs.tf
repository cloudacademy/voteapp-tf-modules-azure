output "api_vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.api.name
}

output "api_backend_pool_id" {
  value = azurerm_lb_backend_address_pool.api.id
}
