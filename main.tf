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
  default = "France Central" # see https://azure.microsoft.com/en-us/global-infrastructure/france/
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
  zone = "1"
  version = "14"
  administrator_login = "postgres"
  administrator_password = random_password.postgres.result
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
