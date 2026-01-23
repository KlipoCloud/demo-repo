# Signal 1: Underutilized VM - Small VM but still wasteful patterns
resource "azurerm_resource_group" "underutilized" {
  name     = "rg-underutilized-test"
  location = "East US"
}

resource "azurerm_virtual_machine" "idle_vm" {
  name                = "vm-idle-dev"
  location            = azurerm_resource_group.underutilized.location
  resource_group_name = azurerm_resource_group.underutilized.name
  network_interface_ids = [azurerm_network_interface.idle_nic.id]
  vm_size = "Standard_B2s"

  # SIGNAL: No auto-shutdown configured for dev environment
  # SIGNAL: Premium disk for basic workload
  storage_os_disk {
    name              = "idle-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  os_profile {
    computer_name  = "idle-vm"
    admin_username = "devuser"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  # SIGNAL: Missing environment tag for cost tracking
  tags = {
    Purpose = "development"
    # Missing: Environment, CostCenter, Owner
  }

  # Added auto-shutdown configuration
  lifecycle {
    ignore_changes = ["auto_shutdown"]
  }

  auto_shutdown {
    enabled = true
    time    = "1900"
    timezone = "UTC"
    notification {
      enabled = true
      email   = "admin@example.com"
    }
  }
}

resource "azurerm_virtual_network" "idle_vnet" {
  name                = "vnet-idle"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.underutilized.location
  resource_group_name = azurerm_resource_group.underutilized.name
}

resource "azurerm_subnet" "idle_subnet" {
  name                 = "subnet-idle"
  resource_group_name  = azurerm_resource_group.underutilized.name
  virtual_network_name = azurerm_virtual_network.idle_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "idle_nic" {
  name                = "nic-idle"
  location            = azurerm_resource_group.underutilized.location
  resource_group_name = azurerm_resource_group.underutilized.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.idle_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}