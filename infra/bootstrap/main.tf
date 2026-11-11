# One-time bootstrap of the remote state backend (run locally with your own Azure login).
#   cd infra/bootstrap && terraform init && terraform apply -var storage_account_name=sttfstate<unique>
terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "storage_account_name" {
  description = "Globally unique, 3-24 lowercase letters and digits"
  type        = string
  default     = "sttfstatenotes001"
}

resource "azurerm_resource_group" "state" {
  name     = "rg-tfstate"
  location = var.location
  tags     = { managed_by = "terraform", purpose = "terraform-state" }
}

resource "azurerm_storage_account" "state" {
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false # Entra ID auth only
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true # recover from a corrupted state file
    delete_retention_policy {
      days = 14
    }
  }
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

output "storage_account_name" {
  value = azurerm_storage_account.state.name
}
