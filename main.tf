provider "azurerm" {
  version = "=2.6.0"
  features {}
}


resource "azurerm_resource_group" "openttd_rg" {
  name = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "openttd_vnet" {
  name = "${var.prefix}-vnet"
  resource_group_name = azurerm_resource_group.openttd_rg.name
  location = azurerm_resource_group.openttd_rg.location
  address_space = [
    "10.0.0.0/16"]
}

resource "azurerm_subnet" "vm_subnet" {
  name = "subnet01"
  resource_group_name = azurerm_resource_group.openttd_rg.name
  virtual_network_name = azurerm_virtual_network.openttd_vnet.name
  address_prefix = "10.0.1.0/24"
  service_endpoints = [
    "Microsoft.Storage"]

}


resource "azurerm_network_security_group" "openttd_subnet" {
  name = "${var.prefix}-nsg"
  location = azurerm_resource_group.openttd_rg.location
  resource_group_name = azurerm_resource_group.openttd_rg.name

  security_rule {
    name = "allowopenttd"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "*"
    source_port_range = "*"
    destination_port_range = "3979"
    source_address_prefixes = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name = "allowssh"
    priority = 101
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "2"
    source_address_prefixes = var.openttd_admin_ips
    destination_address_prefix = "*"
  }


  tags = var.tags
}

resource "azurerm_network_profile" "openttd_network_profile" {
  name = "${var.prefix}-networkprofile"
  location = azurerm_resource_group.openttd_rg.location
  resource_group_name = azurerm_resource_group.openttd_rg.name

  container_network_interface {
    name = "${var.prefix}-nic"

    ip_configuration {
      name = "${var.prefix}-acr-nic"
      subnet_id = azurerm_subnet.vm_subnet.id
    }
  }
}

resource "azurerm_storage_account" "openttd-storage" {
  name = "${var.prefix}storage01"
  location = azurerm_resource_group.openttd_rg.location
  resource_group_name = azurerm_resource_group.openttd_rg.name
  account_tier = "Standard"
  account_replication_type = "LRS"

  #network_rules {
  #  default_action = "Deny"
  #  virtual_network_subnet_ids = [
  #    azurerm_subnet.acr_subnet.id]
  #}

}

resource "azurerm_storage_share" "openttd_config_share" {
  name = "config"
  storage_account_name = azurerm_storage_account.openttd-storage.name
  quota = 200
}

resource "azurerm_public_ip" "acr_vm_ip" {
  name = "${var.prefix}-ip"
  location = azurerm_resource_group.openttd_rg.location
  resource_group_name = azurerm_resource_group.openttd_rg.name
  allocation_method = "Static"

  tags = var.tags
}

resource "azurerm_network_interface" "main" {
  name = "${var.prefix}-nic"
  location = azurerm_resource_group.openttd_rg.location
  resource_group_name = azurerm_resource_group.openttd_rg.name

  ip_configuration {
    name = "testconfiguration1"
    subnet_id = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.acr_vm_ip.id
  }
}

resource "azurerm_subnet_network_security_group_association" "openttd_subnet_assoc" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.openttd_subnet.id
}

data "template_file" "cloudconfig" {
  template = file("cloudconfig.tpl")
}

data "template_cloudinit_config" "config" {
  gzip = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = data.template_file.cloudconfig.rendered
  }
}

resource "azurerm_virtual_machine" "main" {
  name = "${var.prefix}-vm"
  location = azurerm_resource_group.openttd_rg.location
  resource_group_name = azurerm_resource_group.openttd_rg.name
  network_interface_ids = [
    azurerm_network_interface.main.id]
  vm_size = "Standard_DS1_v2"


  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "16.04-LTS"
    version = "latest"
  }
  storage_os_disk {
    name = "${var.prefix}osdisk1"
    caching = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name = "openttd"
    admin_username = "openttdadmin"
    admin_password = var.admin_password
    custom_data = data.template_cloudinit_config.config.rendered
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = var.tags

}
