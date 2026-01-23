# Signal 2: Unused/Orphaned Resources
resource "azurerm_resource_group" "unused_resources" {
  name     = "rg-unused-test"
  location = "East US"
}

# SIGNAL: Unused public IP (allocated but not attached)
# resource "azurerm_public_ip" "orphaned_ip" {
#   name                = "pip-orphaned"
#   resource_group_name = azurerm_resource_group.unused_resources.name
#   location            = azurerm_resource_group.unused_resources.location
#   allocation_method   = "Static"
#   sku                = "Standard"
#
#   # SIGNAL: No attachment to any resource - burning money
#   tags = {
#     Status = "Allocated but unused"
#   }
# }

# SIGNAL: Storage account with expensive tier for dev
resource "azurerm_storage_account" "expensive_storage" {
  name                     = "stexpensivedev001"
  resource_group_name      = azurerm_resource_group.unused_resources.name
  location                 = azurerm_resource_group.unused_resources.location
  account_tier             = "Standard" # Cost signal: Premium for dev
  account_replication_type = "LRS"      # Cost signal: Zone redundant for dev

  tags = {
    Environment = "development"
    # SIGNAL: Premium storage for non-production
  }
}

# SIGNAL: Load balancer with no backend pool
# resource "azurerm_lb" "unused_lb" {
#   name                = "lb-unused"
#   location            = azurerm_resource_group.unused_resources.location
#   resource_group_name = azurerm_resource_group.unused_resources.name
#   sku                = "Standard"
#
#   frontend_ip_configuration {
#     name                 = "PublicIPAddress"
#     public_ip_address_id = azurerm_public_ip.orphaned_ip.id
#   }
#
#   # SIGNAL: No backend pool configured - unused load balancer
#   tags = {
#     Status = "Configured but no backend"
#   }
# }

# SIGNAL: Managed disk not attached to any VM
# resource "azurerm_managed_disk" "orphaned_disk" {
#   name                 = "disk-orphaned"
#   location             = azurerm_resource_group.unused_resources.location
#   resource_group_name  = azurerm_resource_group.unused_resources.name
#   storage_account_type = "Premium_LRS" # Cost signal: Premium unattached
#   create_option        = "Empty"
#   disk_size_gb         = "64"
#
#   tags = {
#     Status = "Unattached storage"
#   }
# }

# SIGNAL: Application Gateway with no backend targets
resource "azurerm_application_gateway" "unused_appgw" {
  name                = "appgw-unused"
  resource_group_name = azurerm_resource_group.unused_resources.name
  location            = azurerm_resource_group.unused_resources.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1 # Minimum for testing
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_ip.id
  }

  backend_address_pool {
    name = "empty-backend-pool" # SIGNAL: Empty backend pool
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "empty-backend-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 1
  }
}

resource "azurerm_virtual_network" "unused_vnet" {
  name                = "vnet-unused"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.unused_resources.location
  resource_group_name = azurerm_resource_group.unused_resources.name
}

resource "azurerm_subnet" "appgw_subnet" {
  name                 = "subnet-appgw"
  resource_group_name  = azurerm_resource_group.unused_resources.name
  virtual_network_name = azurerm_virtual_network.unused_vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_public_ip" "appgw_ip" {
  name                = "pip-appgw"
  resource_group_name = azurerm_resource_group.unused_resources.name
  location            = azurerm_resource_group.unused_resources.location
  allocation_method   = "Static"
  sku                = "Standard"
}