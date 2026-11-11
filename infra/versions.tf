terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Partial configuration - values come from envs/<env>.backend.hcl
  #   terraform init -backend-config=envs/dev.backend.hcl
  backend "azurerm" {}
}

provider "azurerm" {
  # subscription_id is read from ARM_SUBSCRIPTION_ID; auth uses OIDC in CI (ARM_USE_OIDC=true)
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
