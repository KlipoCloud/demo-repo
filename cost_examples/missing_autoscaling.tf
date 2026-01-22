@ -0,0 +1,131 @@
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
  sku_name = "S0" # Fixed 10 DTUs - always consuming resources

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
