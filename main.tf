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

resource "azurerm_subnet" "acr_subnet" {
  name = "acr-subnet"
  resource_group_name = azurerm_resource_group.openttd_rg.name
  virtual_network_name = azurerm_virtual_network.openttd_vnet.name
  address_prefix = "10.0.1.0/24"

  delegation {
    name = "acctestdelegation"

    service_delegation {
      name = "Microsoft.ContainerInstance/containerGroups"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
    }
  }
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
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "3979"
    source_address_prefixes = var.openttd_allowed_ips
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


  tags = {
    environment = "Production"
  }
}
