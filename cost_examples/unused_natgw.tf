@ -0,0 +1,104 @@
# Signal 5: Unused NAT Gateway
resource "azurerm_resource_group" "unused_natgw" {
  name     = "rg-unused-natgw-test"
  location = "East US"
}

# SIGNAL: NAT Gateway with no subnet associations
resource "azurerm_nat_gateway" "unused_nat" {
  name                    = "nat-unused"
  location                = azurerm_resource_group.unused_natgw.location
  resource_group_name     = azurerm_resource_group.unused_natgw.name
  sku_name               = "Standard"
  idle_timeout_in_minutes = 10

  tags = {
    Status = "deployed-but-unused"
    # SIGNAL: NAT Gateway burning money with no associations
  }
}

# SIGNAL: Public IP allocated for NAT Gateway but NAT Gateway unused
resource "azurerm_public_ip" "unused_nat_ip" {
  name                = "pip-unused-nat"
  resource_group_name = azurerm_resource_group.unused_natgw.name
  location            = azurerm_resource_group.unused_natgw.location
  allocation_method   = "Static"
  sku                = "Standard"

  tags = {
    Purpose = "nat-gateway"
    # SIGNAL: Public IP for unused NAT Gateway
  }
}

resource "azurerm_nat_gateway_public_ip_association" "unused_nat_ip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.unused_nat.id
  public_ip_address_id = azurerm_public_ip.unused_nat_ip.id
}

# SIGNAL: VNet exists but no subnet uses the NAT Gateway
resource "azurerm_virtual_network" "nat_vnet" {
  name                = "vnet-nat-unused"
  address_space       = ["10.6.0.0/16"]
  location            = azurerm_resource_group.unused_natgw.location
  resource_group_name = azurerm_resource_group.unused_natgw.name
}

resource "azurerm_subnet" "nat_subnet" {
  name                 = "subnet-no-nat"
  resource_group_name  = azurerm_resource_group.unused_natgw.name
  virtual_network_name = azurerm_virtual_network.nat_vnet.name
  address_prefixes     = ["10.6.1.0/24"]

  # SIGNAL: No NAT Gateway association - NAT Gateway is unused
}

# SIGNAL: VM that could use NAT Gateway but doesn't
resource "azurerm_virtual_machine" "vm_without_nat" {
  name                = "vm-no-nat"
  location            = azurerm_resource_group.unused_natgw.location
  resource_group_name = azurerm_resource_group.unused_natgw.name
  network_interface_ids = [azurerm_network_interface.vm_nic.id]
  vm_size = "Standard_B1s"

  storage_os_disk {
    name              = "vm-os-disk"
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
    computer_name  = "vm-no-nat"
    admin_username = "adminuser"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    OutboundConnectivity = "none"
    # SIGNAL: VM in subnet that doesn't use the deployed NAT Gateway
  }
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "nic-vm-no-nat"
  location            = azurerm_resource_group.unused_natgw.location
  resource_group_name = azurerm_resource_group.unused_natgw.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.nat_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
