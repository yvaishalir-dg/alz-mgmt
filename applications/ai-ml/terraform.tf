terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.21"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }

  # Remote state backend
  backend "azurerm" {
    # resource_group_name  = "rg-terraform-state"      # Update to your state RG
    # storage_account_name = "sttfstate"               # Update to your state SA
    # container_name       = "tfstate"
    # key                  = "applications/aiml/terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
  }
}

provider "azapi" {}
