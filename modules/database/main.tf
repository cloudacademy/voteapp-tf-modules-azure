resource "random_string" "unique" {
  length  = 6
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_cosmosdb_account" "mongo" {
  name                = "mongo-${random_string.unique.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "MongoDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  capabilities {
    name = "EnableMongo"
  }

  tags = {
    environment = "Terraform"
    role        = "database"
  }
}

resource "azurerm_cosmosdb_mongo_database" "db" {
  name                = "voteapp"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.mongo.name
  throughput          = 400
}

locals {
  mongo_connection_string = azurerm_cosmosdb_account.mongo.primary_mongodb_connection_string

  credentials_match = regex("^mongodb://([^:]+):([^@]+)@", local.mongo_connection_string)

  mongo_username = local.credentials_match[0]
  mongo_password = local.credentials_match[1]
}
