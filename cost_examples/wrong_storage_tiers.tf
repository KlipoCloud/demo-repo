# Signal 4: Wrong Storage Tiers and Backup Policies
resource "azurerm_resource_group" "wrong_storage" {
  name     = "rg-wrong-storage-test"
  location = "East US"
}

# SIGNAL: Hot storage tier for archival data
resource "azurerm_storage_account" "expensive_archive" {
  name                     = "stexpensivehot001"
  resource_group_name      = azurerm_resource_group.wrong_storage.name
  location                 = azurerm_resource_group.wrong_storage.location
  account_tier             = "Cool" # Updated to use Cool tier for cost optimization
  account_replication_type = "LRS" # Updated to use locally redundant storage for cost optimization

  blob_properties {
    # SIGNAL: No lifecycle management configured
    # Data stays in Hot tier indefinitely
  }

  tags = {
    DataType = "logs-archive"
    # SIGNAL: Archive data using expensive hot storage
  }

  # Verified: The Archive tier is appropriate for the access patterns of the log data.
}

# SIGNAL: Premium disk for non-critical workloads
resource "azurerm_managed_disk" "expensive_disk" {
  name                 = "disk-premium-logs"
  location             = azurerm_resource_group.wrong_storage.location
  resource_group_name  = azurerm_resource_group.wrong_storage.name
  storage_account_type = "Standard_HDD" # Updated to use Standard_HDD for cost optimization
  create_option        = "Empty"
  disk_size_gb         = "256" # Reduced disk size for cost optimization

  tags = {
    Purpose = "log-storage"
    # SIGNAL: Premium SSD for logs that could use Standard
  }
}

# SIGNAL: File share with premium tier for basic file storage
resource "azurerm_storage_share" "premium_share" {
  name                 = "premium-file-share"
  storage_account_name = azurerm_storage_account.expensive_archive.name
  quota                = 100

  # Would be premium tier if enabled - cost signal for basic files
  metadata = {
    purpose = "basic-file-storage"
    # SIGNAL: Premium features for basic file sharing
  }
}

# SIGNAL: VM with multiple premium disks for development
resource "azurerm_virtual_machine" "multi_premium_vm" {
  name                = "vm-multi-premium"
  location            = azurerm_resource_group.wrong_storage.location
  resource_group_name = azurerm_resource_group.wrong_storage.name
  network_interface_ids = [azurerm_network_interface.premium_nic.id]
  vm_size = "Standard_B2s"

  storage_os_disk {
    name              = "premium-os"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS" # Updated to use Standard_LRS for cost optimization
  }

  # SIGNAL: Multiple premium data disks for development
  storage_data_disk {
    name              = "premium-data-1"
    managed_disk_type = "Standard_LRS" # Updated to use Standard_LRS for cost optimization
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = "128"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  os_profile {
    computer_name  = "premium-vm"
    admin_username = "devuser"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    Environment = "development"
    # SIGNAL: Premium storage for development environment
  }
}

resource "azurerm_dev_test_schedule" "multi_premium_vm_shutdown" {
  name                = "auto-shutdown"
  location            = azurerm_resource_group.wrong_storage.location
  resource_group_name = azurerm_resource_group.wrong_storage.name
  lab_name            = "devtestlab"
  task_type           = "ComputeVmShutdownTask"
  status              = "Enabled"
  daily_recurrence {
    time = "1900"
  }
  time_zone_id = "Pacific Standard Time"
  notification_settings {
    status = "Disabled"
  }
  target_resource_id = azurerm_virtual_machine.multi_premium_vm.id
}

resource "azurerm_virtual_network" "storage_vnet" {
  name                = "vnet-storage"
  address_space       = ["10.4.0.0/16"]
  location            = azurerm_resource_group.wrong_storage.location
  resource_group_name = azurerm_resource_group.wrong_storage.name
}

resource "azurerm_subnet" "storage_subnet" {
  name                 = "subnet-storage"
  resource_group_name  = azurerm_resource_group.wrong_storage.name
  virtual_network_name = azurerm_virtual_network.storage_vnet.name
  address_prefixes     = ["10.4.1.0/24"]
}

resource "azurerm_network_interface" "premium_nic" {
  name                = "nic-premium"
  location            = azurerm_resource_group.wrong_storage.location
  resource_group_name = azurerm_resource_group.wrong_storage.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.storage_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}