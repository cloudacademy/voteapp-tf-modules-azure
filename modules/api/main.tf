terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }
  }
}

#LOCALS
#================================

locals {
  vms_username = "skynet.ops"
  loadbalancer = {
    frontend_ip_configuration = {
      name       = "internal-api"
      ip_address = "10.0.20.100"
    }
  }
}

#LB
#================================

resource "azurerm_lb" "loadbalancer" {
  name                = "loadbalancer-internal-api"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = local.loadbalancer.frontend_ip_configuration.name
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.loadbalancer.frontend_ip_configuration.ip_address
  }

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }
}

resource "azurerm_lb_backend_address_pool" "api" {
  name            = "api"
  loadbalancer_id = azurerm_lb.loadbalancer.id
}

resource "azurerm_lb_probe" "api" {
  name            = "api"
  loadbalancer_id = azurerm_lb.loadbalancer.id
  port            = 8080
}

resource "azurerm_lb_rule" "api" {
  loadbalancer_id                = azurerm_lb.loadbalancer.id
  name                           = "api"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.api.id]
  frontend_ip_configuration_name = local.loadbalancer.frontend_ip_configuration.name
  probe_id                       = azurerm_lb_probe.api.id
}

#API
#================================

data "cloudinit_config" "api" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
    #! /bin/bash

    echo "checking network connectivity..."
    until curl -Is www.google.com | grep -q "200 OK"; do
      echo "Waiting for network connectivity..."
      sleep 5
    done

    echo "starting install..."
    apt-get -y update
    apt-get -y install jq

    echo "deployment starting..."
    echo ===========================
    echo API - download latest release, install, and start...
    mkdir -p ./voteapp-api-go
    cd ./voteapp-api-go
    curl -sL https://api.github.com/repos/cloudacademy/voteapp-api-go/releases/latest | jq -r '.assets[] | select(.name | contains("linux-amd64")) | .browser_download_url' | xargs curl -OL
    tar -xvf *.tar.gz

    #db config
    export MONGO_CONN_STR="${var.mongo_db_config.connection_string}"
    export MONGO_USERNAME="${var.mongo_db_config.username}"
    export MONGO_PASSWORD="${var.mongo_db_config.password}"

    #start the API up...
    ./api &

    echo "deployment finished!"
    EOF
  }
}

resource "azurerm_linux_virtual_machine_scale_set" "api" {
  name                = "api-vmss"
  location            = var.location
  resource_group_name = var.resource_group_name
  upgrade_mode        = "Manual"
  sku                 = "Standard_B1s"
  instances           = 1
  zones               = [1, 2, 3]

  admin_username                  = local.vms_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = local.vms_username
    public_key = var.ssh_pubkey
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "api-nic"
    primary = true

    ip_configuration {
      name                                   = "api-ipconfig"
      subnet_id                              = var.subnet_id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.api.id]
      primary                                = true
    }
  }

  custom_data = data.cloudinit_config.api.rendered

  tags = {
    role = "api"
  }
}
