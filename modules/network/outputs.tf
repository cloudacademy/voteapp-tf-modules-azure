output "public_subnet_id" {
  value = module.vnet1.subnets.public_zone.resource_id
}

output "private_subnet_frontend_id" {
  value = module.vnet1.subnets.private_zone_frontend.resource_id
}

output "private_subnet_api_id" {
  value = module.vnet1.subnets.private_zone_api.resource_id
}
