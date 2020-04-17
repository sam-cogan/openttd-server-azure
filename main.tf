provider "azurerm" {
  version = "=2.6.0"
  features {}
}


resource "azurerm_resource_group" "openttd_rg" {
  name = "${var.prefix}-rg"
  location = var.location
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

resource "azurerm_container_group" "openttd_acr" {
  name = "${var.prefix}-acr"
  location = azurerm_resource_group.openttd_rg.location
  resource_group_name = azurerm_resource_group.openttd_rg.name
  ip_address_type = "public"
  dns_name_label = "${var.prefix}-acr"
  os_type = "Linux"

  container {
    name = "openttd"
    image = "redditopenttd/openttd"
    cpu = "1"
    memory = "1"

    ports {
      port = 3979

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

