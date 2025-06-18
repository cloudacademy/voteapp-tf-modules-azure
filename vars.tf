variable "tenant_id" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type        = string
  description = "azure resource group"
}

variable "location" {
  type        = string
  description = "azure region"
  default     = "eastus"
}

variable "vnet_address_space" {
  description = "Base address space for the virtual network"
  type        = list(string)
}

variable "public_subnet_address_prefixes" {
  type = list(string)
}

variable "private_subnet_address_prefixes" {
  type = map(list(string))
}

variable "public_zone_nsg_rules" {
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  description = "public zone nsg ruleset"
}


variable "private_zone_frontend_nsg_rules" {
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  description = "private zone frontend nsg ruleset"
}

variable "private_zone_api_nsg_rules" {
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  description = "private zone api nsg ruleset"
}

variable "mongo_db_config" {
  sensitive = true
  type = object({
    connection_string = string
    username          = string
    password          = string
  })
  description = "mongodb connection details"
}

variable "ssh_public_key_path" {
  type        = string
  description = "SSH public key file for VM access"
  default     = null
}
