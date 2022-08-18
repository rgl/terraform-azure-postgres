# see https://github.com/hashicorp/terraform
terraform {
  required_version = "1.2.6"
  required_providers {
    # see https://github.com/hashicorp/terraform-provider-random
    # see https://registry.terraform.io/providers/hashicorp/random
    random = {
      source  = "hashicorp/random"
      version = "3.3.2"
    }
    # see https://github.com/terraform-providers/terraform-provider-azurerm
    # see https://registry.terraform.io/providers/hashicorp/azurerm
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.18.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# NB you can test the relative speed from you browser to a location using https://azurespeedtest.azurewebsites.net/
# get the available locations with: az account list-locations --output table
variable "location" {
  default = "northeurope"
}

# NB this depends on the location.
# NB if the location does not have this zone the deployment will fail with:
#      Server Name: "example83f433c0bc329d86"): polling after Create: Code="InternalServerError" Message="An unexpected error occured while processing the request. Tracking ID: '1f65426f-cfd8-41fb-9952-2fbc8df9bb6d'"
# NB you can see the available zones in the azure portal postgres instance creation page.
variable "zone" {
  default = "1"
}

# NB this name must be unique within the Azure subscription.
#    all the other names must be unique within this resource group.
variable "resource_group_name" {
  default = "rgl-terraform-azure-postgres"
}

data "azurerm_client_config" "current" {
}

output "fqdn" {
  value = azurerm_postgresql_flexible_server.example.fqdn
}

output "password" {
  value = random_password.postgres.result
  sensitive = true
}

resource "random_id" "postgres" {
  byte_length = 8
}

resource "random_password" "postgres" {
  min_upper = 1
  min_lower = 1
  min_numeric = 1
  min_special = 1
  # NB must be between 8-128.
  length = 16
}

resource "azurerm_resource_group" "example" {
  name = var.resource_group_name # NB this name must be unique within the Azure subscription.
  location = var.location
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server
resource "azurerm_postgresql_flexible_server" "example" {
  # NB this name must be unique within azure.
  # NB it will be used as part of the domain name as $name.postgres.database.azure.com.
  # NB this name must be 3-63 characters long.
  name = "example${random_id.postgres.hex}"
  resource_group_name = azurerm_resource_group.example.name
  location = azurerm_resource_group.example.location
  # NB the available zones are region/location specific. for example, at the
  #    time this was tested, the francecentral region/location ONLY had ONE
  #    zone available, and it was zone 2. because of this, if the zone you
  #    define here is not available, the deployment fails with:
  #     Server Name: "example83f433c0bc329d86"): polling after Create: Code="InternalServerError" Message="An unexpected error occured while processing the request. Tracking ID: '1f65426f-cfd8-41fb-9952-2fbc8df9bb6d'"
  zone = var.zone
  version = "14"
  administrator_login = "postgres"
  administrator_password = random_password.postgres.result
  backup_retention_days = 7
  // Development (aka Burstable) sku.
  // 1 vCores, 2 GiB RAM, 32 GiB storage.
  // see https://docs.microsoft.com/en-us/azure/templates/microsoft.dbforpostgresql/2021-06-01/flexibleservers#sku
  sku_name = "B_Standard_B1ms"
  storage_mb = 32*1024
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "all" {
  name = "all"
  server_id = azurerm_postgresql_flexible_server.example.id
  start_ip_address = "0.0.0.0"
  end_ip_address = "255.255.255.255"
}
