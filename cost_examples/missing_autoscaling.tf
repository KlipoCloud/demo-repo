# Signal 3: Missing Auto-scaling and Right-sizing
resource "azurerm_resource_group" "no_autoscaling" {
  name     = "rg-no-autoscaling-test"
  location = "East US"
}

# SIGNAL: Static VM scale set without auto-scaling
resource "azurerm_virtual_machine_scale_set" "static_vmss" {
  name                = "vmss-static"
  location            = azurerm_resource_group.no_autoscaling.location
  resource_group_name = azurerm_resource_group.no_autoscaling.name

  # SIGNAL: Fixed capacity instead of auto-scaling
  sku {
    name     = "Standard_B1s"
    tier     = "Standard"
    capacity = 3 # Fixed - no auto-scaling configured
  }

  storage_profile_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name_prefix = "static"
    admin_username       = "adminuser"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  network_profile {
    name    = "vmss-netprofile"
    primary = true

    ip_configuration {
      name      = "IPConfiguration"
      subnet_id = azurerm_subnet.vmss_subnet.id
      primary   = true
    }
  }

  # SIGNAL: No auto-scaling rules defined
  tags = {
    AutoScaling = "disabled"
    Environment = "production" # Production without auto-scaling!
  }
}

# Added autoscaling configuration for the VM Scale Set
resource "azurerm_monitor_autoscale_setting" "vmss_autoscale" {
  name                = "autoscale-vmss-static"
  resource_group_name = azurerm_resource_group.no_autoscaling.name
  location            = azurerm_resource_group.no_autoscaling.location
  target_resource_id  = azurerm_virtual_machine_scale_set.static_vmss.id

  profile {
    name = "defaultProfile"

    capacity {
      minimum = 1
      maximum = 5
      default = 3
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_virtual_machine_scale_set.static_vmss.id
        operator           = "GreaterThan"
        statistic          = "Average"
        threshold          = 75
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_virtual_machine_scale_set.static_vmss.id
        operator           = "LessThan"
        statistic          = "Average"
        threshold          = 25
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}

# SIGNAL: App Service Plan without auto-scaling
resource "azurerm_service_plan" "fixed_app_plan" {
  name                = "plan-fixed"
  resource_group_name = azurerm_resource_group.no_autoscaling.name
  location            = azurerm_resource_group.no_autoscaling.location
  os_type             = "Linux"
  sku_name            = "S1" # SIGNAL: Fixed S1 tier without auto-scaling

  tags = {
    Scaling = "manual"
    # SIGNAL: Manual scaling for production workload
  }
}

# Added autoscaling configuration for the App Service Plan
resource "azurerm_monitor_autoscale_setting" "app_service_plan_autoscale" {
  name                = "autoscale-app-service-plan"
  resource_group_name = azurerm_resource_group.no_autoscaling.name
  location            = azurerm_resource_group.no_autoscaling.location
  target_resource_id  = azurerm_service_plan.fixed_app_plan.id

  profile {
    name = "defaultProfile"

    capacity {
      minimum = 1
      maximum = 3
      default = 2
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_service_plan.fixed_app_plan.id
        operator           = "GreaterThan"
        statistic          = "Average"
        threshold          = 75
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_service_plan.fixed_app_plan.id
        operator           = "LessThan"
        statistic          = "Average"
        threshold          = 25
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}

resource "azurerm_linux_web_app" "fixed_webapp" {
  name                = "app-fixed-scaling"
  resource_group_name = azurerm_resource_group.no_autoscaling.name
  location            = azurerm_service_plan.fixed_app_plan.location
  service_plan_id     = azurerm_service_plan.fixed_app_plan.id

  site_config {}

  # SIGNAL: No auto-scaling configuration
  tags = {
    Environment = "production"
    Scaling     = "none"
  }
}

# SIGNAL: SQL Database with fixed DTU instead of serverless
resource "azurerm_mssql_server" "fixed_sql_server" {
  name                         = "sqlserver-fixed-001"
  resource_group_name          = azurerm_resource_group.no_autoscaling.name
  location                     = azurerm_resource_group.no_autoscaling.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd123!"

  tags = {
    CostOptimization = "needed"
  }
}

resource "azurerm_mssql_database" "fixed_db" {
  name           = "db-fixed-dtu"
  server_id      = azurerm_mssql_server.fixed_sql_server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"

  # SIGNAL: Fixed DTU model instead of serverless for dev/test
  sku_name = "GP_S_Gen5_1" # Updated to serverless-compatible tier

  tags = {
    Environment = "development"
    # SIGNAL: Fixed DTU for development database
    CostIssue   = "should-use-serverless"
  }
}

resource "azurerm_virtual_network" "vmss_vnet" {
  name                = "vnet-vmss"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.no_autoscaling.location
  resource_group_name = azurerm_resource_group.no_autoscaling.name
}

resource "azurerm_subnet" "vmss_subnet" {
  name                 = "subnet-vmss"
  resource_group_name  = azurerm_resource_group.no_autoscaling.name
  virtual_network_name = azurerm_virtual_network.vmss_vnet.name
  address_prefixes     = ["10.2.1.0/24"]
}