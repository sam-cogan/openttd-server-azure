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
  service_endpoints = [
    "Microsoft.Storage"]

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
    protocol = "*"
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


  tags = var.tags
}

resource "azurerm_network_profile" "openttd_network_profile" {
  name = "${var.prefix}-networkprofile"
  location = azurerm_resource_group.openttd_rg.location
  resource_group_name = azurerm_resource_group.openttd_rg.name

  container_network_interface {
    name = "examplecnic"

    ip_configuration {
      name = "${var.prefix}-acr-nic"
      subnet_id = azurerm_subnet.acr_subnet.id
    }
  }
}

resource "azurerm_storage_account" "openttd-storage" {
  name = "${var.prefix}storage01"
  location = azurerm_resource_group.openttd_rg.location
  resource_group_name = azurerm_resource_group.openttd_rg.name
  account_tier = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action = "Deny"
    virtual_network_subnet_ids = [
      azurerm_subnet.acr_subnet.id]
  }

}

resource "azurerm_storage_share" "openttd_config_share" {
  name = "config"
  storage_account_name = azurerm_storage_account.openttd-storage.name
  quota = 200
}

resource "azurerm_container_group" "openttd_acr" {
  name = "${var.prefix}-acr"
  location = azurerm_resource_group.openttd_rg.location
  resource_group_name = azurerm_resource_group.openttd_rg.name
  ip_address_type = "public"
  os_type = "Linux"
  network_profile_id = azurerm_network_profile.openttd_network_profile.id
  container {
    name = "openttd"
    image = "redditopenttd/openttd"
    cpu = "1"
    memory = "1"

    ports {
      port = 3979
      protocol = "TCP"
    }
    ports {
      port = 3979
      protocol = "UDP"
    }

    environment_variables = {
      loadgame = "false"
    }
    volume {
      mount_path = "config"
      name = "opeenttd-config"
      share_name = azurerm_storage_share.openttd_config_share.name
      storage_account_key = azurerm_storage_account.openttd-storage.primary_access_key
      storage_account_name = azurerm_storage_account.openttd-storage.name
    }
  }


  tags = var.tags
}

