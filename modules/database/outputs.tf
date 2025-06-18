output "mongo_connection_string" {
  value = azurerm_cosmosdb_account.mongo.primary_mongodb_connection_string
  #   sensitive = true
}

output "mongo_username" {
  value = local.mongo_username
  # sensitive = true
}

output "mongo_password" {
  value = local.mongo_password
  # sensitive = true
}
