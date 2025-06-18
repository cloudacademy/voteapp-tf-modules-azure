terraform {
  required_version = ">= 1.10.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.3"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}

#LOCALS
#================================
locals {
  ssh_public_key = var.ssh_public_key_path == null ? null : file(var.ssh_public_key_path)
}

#RESOURCEGROUP
#================================

resource "azurerm_resource_group" "cloudacademydevops" {
  name     = var.resource_group_name
  location = var.location
}

#SSHKEY
#================================

resource "tls_private_key" "skynetcorp" {
  count = local.ssh_public_key == null ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "terraform_data" "ssh_private_key" {
  count = local.ssh_public_key == null ? 1 : 0

  triggers_replace = {
    key = tls_private_key.skynetcorp[0].private_key_pem
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "${tls_private_key.skynetcorp[0].private_key_pem}" > ./skynetcorp.pem
      echo "${tls_private_key.skynetcorp[0].public_key_openssh}" > ./skynetcorp.pub
    EOT
  }
}

#MODULES
#================================

module "network" {
  source                          = "./modules/network"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.cloudacademydevops.name
  vnet_address_space              = var.vnet_address_space
  public_subnet_address_prefixes  = var.public_subnet_address_prefixes
  private_subnet_address_prefixes = var.private_subnet_address_prefixes
  public_zone_nsg_rules           = var.public_zone_nsg_rules
  private_zone_frontend_nsg_rules = var.private_zone_frontend_nsg_rules
  private_zone_api_nsg_rules      = var.private_zone_api_nsg_rules
}

module "database" {
  source = "./modules/database"

  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
}

module "api" {
  source              = "./modules/api"
  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  subnet_id           = module.network.private_subnet_api_id
  ssh_pubkey          = local.ssh_public_key == null ? tls_private_key.skynetcorp[0].public_key_openssh : local.ssh_public_key
  # mongo_db_config     = var.mongo_db_config
  mongo_db_config = {
    connection_string = module.database.mongo_connection_string
    username          = module.database.mongo_username
    password          = module.database.mongo_password
  }
}

module "frontend" {
  source              = "./modules/frontend"
  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  subnet_id           = module.network.private_subnet_frontend_id
  ssh_pubkey          = local.ssh_public_key == null ? tls_private_key.skynetcorp[0].public_key_openssh : local.ssh_public_key
  enable_https        = false
}

module "bastion" {
  source              = "./modules/bastion"
  location            = var.location
  resource_group_name = azurerm_resource_group.cloudacademydevops.name
  subnet_id           = module.network.public_subnet_id
  ssh_pubkey          = local.ssh_public_key == null ? tls_private_key.skynetcorp[0].public_key_openssh : local.ssh_public_key
  mongo_db_config = {
    connection_string = module.database.mongo_connection_string
    username          = module.database.mongo_username
    password          = module.database.mongo_password
  }
}
