#NAT
#================================

resource "azurerm_public_ip" "nat" {
  name                = "nat-gateway-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_nat_gateway" "nat" {
  name                = "nat-gateway"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

#ROUTES
#================================

resource "azurerm_route_table" "private_zone" {
  name                = "private-zone"
  resource_group_name = var.resource_group_name
  location            = var.location

  route {
    name           = "default"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

data "http" "public_ip" {
  method = "GET"
  url    = "http://api.ipify.org?format=json"
}

resource "azurerm_network_security_group" "public_zone" {
  name                = "public_zone"
  location            = var.location
  resource_group_name = var.resource_group_name

  dynamic "security_rule" {
    for_each = var.public_zone_nsg_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.name == "ssh" ? jsondecode(data.http.public_ip.response_body).ip : security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }

  tags = {
    org  = "cloudacademy"
    app  = "voteapp"
    zone = "public"
  }
}

resource "azurerm_network_security_group" "private_zone_frontend" {
  name                = "private_zone_frontend"
  location            = var.location
  resource_group_name = var.resource_group_name

  dynamic "security_rule" {
    for_each = var.private_zone_frontend_nsg_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }

  tags = {
    org       = "cloudacademy"
    app       = "voteapp"
    zone      = "private"
    component = "frontend"
  }
}

resource "azurerm_network_security_group" "private_zone_api" {
  name                = "private_zone_api"
  location            = var.location
  resource_group_name = var.resource_group_name

  dynamic "security_rule" {
    for_each = var.private_zone_frontend_nsg_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }

  tags = {
    org       = "cloudacademy"
    app       = "voteapp"
    zone      = "private"
    component = "api"
  }
}


#VNET
#================================

module "vnet1" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.8.1"

  resource_group_name = var.resource_group_name
  location            = var.location
  name                = "cloudacademydevops-vnet1"

  address_space = var.vnet_address_space

  dns_servers = {
    dns_servers = ["8.8.8.8"]
  }

  subnets = {
    public_zone = {
      name                            = "public-zone"
      address_prefixes                = var.public_subnet_address_prefixes
      default_outbound_access_enabled = true
      network_security_group = {
        id = azurerm_network_security_group.public_zone.id
      }
    }
    private_zone_frontend = {
      name                            = "private-zone-frontend"
      address_prefixes                = var.private_subnet_address_prefixes.frontend
      default_outbound_access_enabled = false
      nat_gateway = {
        id = azurerm_nat_gateway.nat.id
      }
      network_security_group = {
        id = azurerm_network_security_group.private_zone_frontend.id
      }
      route_table = {
        id = azurerm_route_table.private_zone.id
      }
    }
    private_zone_api = {
      name                            = "private-zone-api"
      address_prefixes                = var.private_subnet_address_prefixes.api
      default_outbound_access_enabled = false
      nat_gateway = {
        id = azurerm_nat_gateway.nat.id
      }
      network_security_group = {
        id = azurerm_network_security_group.private_zone_api.id
      }
      route_table = {
        id = azurerm_route_table.private_zone.id
      }
    }
  }
}
