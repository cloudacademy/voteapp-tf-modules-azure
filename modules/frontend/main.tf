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
      name = "frontend"
    }
  }
  api = {
    lb_internal_ip_address = "10.0.20.100"
    port                   = 8080
  }
}

#LB
#================================

resource "random_string" "fqdn" {
  length  = 6
  special = false
  upper   = false
  numeric = false
}

resource "azurerm_public_ip" "loadbalancer" {
  name                = "loadbalance"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  domain_name_label   = random_string.fqdn.result
  sku                 = "Standard"
  zones               = [1, 2, 3]

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }
}

resource "azurerm_lb" "loadbalancer" {
  name                = "loadbalancer-frontend"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = local.loadbalancer.frontend_ip_configuration.name
    public_ip_address_id = azurerm_public_ip.loadbalancer.id
  }

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }
}

resource "azurerm_lb_backend_address_pool" "frontend" {
  name            = "frontend"
  loadbalancer_id = azurerm_lb.loadbalancer.id
}

resource "azurerm_lb_probe" "frontend" {
  name            = "frontend"
  loadbalancer_id = azurerm_lb.loadbalancer.id
  port            = 80
}

resource "azurerm_lb_rule" "frontend_http" {
  loadbalancer_id                = azurerm_lb.loadbalancer.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.frontend.id]
  frontend_ip_configuration_name = local.loadbalancer.frontend_ip_configuration.name
  probe_id                       = azurerm_lb_probe.frontend.id
}

resource "azurerm_lb_rule" "frontend_https" {
  count = var.enable_https ? 1 : 0

  loadbalancer_id                = azurerm_lb.loadbalancer.id
  name                           = "https"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.frontend.id]
  frontend_ip_configuration_name = local.loadbalancer.frontend_ip_configuration.name
  probe_id                       = azurerm_lb_probe.frontend.id
}

#FRONTEND
#================================

data "cloudinit_config" "frontend" {
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
    apt-get -y install nginx jq certbot python3-certbot-nginx

    echo "deployment starting..."
    echo ===========================
    echo FRONTEND - download latest release and install...
    VOTE_APP=voteapp-frontend-react-2025
    mkdir -p ./$VOTE_APP && cd ./$VOTE_APP

    curl -sL https://api.github.com/repos/cloudacademy/$VOTE_APP/releases/latest | jq -r '.assets[0].browser_download_url' | xargs curl -OL
    tar -xvf *.tar.gz
    rm -rf /var/www/html
    cp -R dist /var/www/html
    cat > /var/www/html/env-config.js << EOFF
    window._env_ = {API_BASE_URL: "http://${azurerm_public_ip.loadbalancer.fqdn}"}
    EOFF

    echo "configuring nginx..."
    cat > /etc/nginx/sites-available/default << 'EOFF'
      ${file("${path.module}/nginx/default.conf")}
    EOFF

    FQDN=${azurerm_public_ip.loadbalancer.fqdn}
    echo $FQDN
    sed -i "s/^\(\s*server_name\s*\).*;/\1$FQDN;/" /etc/nginx/sites-available/default
    nginx -s reload

    %{if var.enable_https}
    apt-get -y install certbot python3-certbot-nginx

    cat > /var/www/html/env-config.js << EOFF
    window._env_ = {API_BASE_URL: "https://${azurerm_public_ip.loadbalancer.fqdn}"}
    EOFF
  
    EMAIL="jeremycook123@gmail.com"
    certbot --nginx -d "$FQDN" --non-interactive --agree-tos --email "$EMAIL" || true
    %{endif}

    echo "deployment finished!"
    EOF
  }
}

resource "azurerm_linux_virtual_machine_scale_set" "frontend" {
  name                = "frontend-vmss"
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
    name    = "frontend-nic"
    primary = true

    ip_configuration {
      name                                   = "frontend-ipconfig"
      subnet_id                              = var.subnet_id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.frontend.id]
      primary                                = true
    }
  }

  custom_data = data.cloudinit_config.frontend.rendered

  tags = {
    role = "frontend"
  }
}

resource "azurerm_monitor_autoscale_setting" "frontend" {
  name                = "frontent"
  location            = var.location
  resource_group_name = var.resource_group_name

  target_resource_id = azurerm_linux_virtual_machine_scale_set.frontend.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 4
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.frontend.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 30
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        dimensions {
          name     = "AppName"
          operator = "Equals"
          values   = ["App1"]
        }
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.frontend.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

  tags = {
    org = "cloudacademy"
    app = "voteapp"
  }
}
