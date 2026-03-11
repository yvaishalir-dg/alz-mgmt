# -----------------------------------------------------------------------------
# Data Sources — Platform Remote State
# -----------------------------------------------------------------------------
data "terraform_remote_state" "platform" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.platform_state_resource_group_name
    storage_account_name = var.platform_state_storage_account_name
    container_name       = var.platform_state_container_name
    key                  = var.platform_state_key
  }
}

data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------
locals {
  # Hub networking from platform
  hub_vnet_resource_id          = data.terraform_remote_state.platform.outputs.hub_and_spoke_vnet_virtual_network_resource_ids["primary"]
  hub_and_spoke_vnet_firewall_resource_names = try(data.terraform_remote_state.platform.outputs.hub_and_spoke_vnet_firewall_resource_names["primary"], null)
  hub_resource_group_name       = data.terraform_remote_state.platform.outputs.templated_inputs.connectivity_resource_groups.vnet_primary.name
  hub_dns_resource_group_name   = data.terraform_remote_state.platform.outputs.templated_inputs.connectivity_resource_groups.dns.name
  firewall_private_ip           = try(data.terraform_remote_state.platform.outputs.hub_and_spoke_vnet_firewall_private_ip_address["primary"], null)
  hub_log_analytics_workspace_id = try(data.terraform_remote_state.platform.outputs.hub_log_analytics_workspace_id, null)
}

data "azurerm_resource_group" "hub_dns_resource_group" {
  name = local.hub_dns_resource_group_name
}


locals {
  jump_vm_name = "ai-alz-jumpvm"
  aiml_vnet_name = "vnet-aiml-${var.environment}-${var.location_short}"
  route_table_name = "${local.aiml_vnet_name}-firewall-route-table"
  region_zones = []
  # DNS zone IDs for AI/ML services
  # These are used by the landing zone module for private endpoints
  private_dns_zone_map = {
    key_vault_zone = {
      name = "privatelink.vaultcore.azure.net"
    }
    apim_zone = {
      name = "privatelink.azure-api.net"
    }
    cosmos_sql_zone = {
      name = "privatelink.documents.azure.com"
    }
    cosmos_mongo_zone = {
      name = "privatelink.mongo.cosmos.azure.com"
    }
    cosmos_cassandra_zone = {
      name = "privatelink.cassandra.cosmos.azure.com"
    }
    cosmos_gremlin_zone = {
      name = "privatelink.gremlin.cosmos.azure.com"
    }
    cosmos_table_zone = {
      name = "privatelink.table.cosmos.azure.com"
    }
    cosmos_analytical_zone = {
      name = "privatelink.analytics.cosmos.azure.com"
    }
    cosmos_postgres_zone = {
      name = "privatelink.postgres.cosmos.azure.com"
    }
    storage_blob_zone = {
      name = "privatelink.blob.core.windows.net"
    }
    storage_queue_zone = {
      name = "privatelink.queue.core.windows.net"
    }
    storage_table_zone = {
      name = "privatelink.table.core.windows.net"
    }
    storage_file_zone = {
      name = "privatelink.file.core.windows.net"
    }
    storage_dlfs_zone = {
      name = "privatelink.dfs.core.windows.net"
    }
    storage_web_zone = {
      name = "privatelink.web.core.windows.net"
    }
    ai_search_zone = {
      name = "privatelink.search.windows.net"
    }
    container_registry_zone = {
      name = "privatelink.azurecr.io"
    }
    app_configuration_zone = {
      name = "privatelink.azconfig.io"
    }
    ai_foundry_openai_zone = {
      name = "privatelink.openai.azure.com"
    }
    ai_foundry_ai_services_zone = {
      name = "privatelink.services.ai.azure.com"
    }
    ai_foundry_cognitive_services_zone = {
      name = "privatelink.cognitiveservices.azure.com"
    }
  }

  private_dns_zones_existing = { for key, value in local.private_dns_zone_map : key => {
    name        = value.name
    resource_id = "${coalesce(data.azurerm_resource_group.hub_dns_resource_group.id, "notused")}/providers/Microsoft.Network/privateDnsZones/${value.name}"
    }
  }
  private_dns_zones_existing_id = [for key, value in local.private_dns_zone_map: "${coalesce(data.azurerm_resource_group.hub_dns_resource_group.id, "notused")}/providers/Microsoft.Network/privateDnsZones/${value.name}"]
}