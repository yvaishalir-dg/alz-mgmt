# =============================================================================
# applications/aiml/main.tf
#
# AI/ML Application Landing Zone
# - Creates new VNet with hub peering (not BYO existing VNet)
# - Uses platform hub's DNS zones and firewall
# - Creates "genai_*" resources (Cosmos, Storage, Key Vault, AI Search)
# - Uses those genai_* resources as BYOR for AI Foundry
# - Creates AI Foundry Hub + Projects
# =============================================================================

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
}

# Add a vnet in a separate resource group
resource "azurerm_resource_group" "aiml_rg" {
  location = var.location
  name     = var.resource_group_name
}



# 2. The Loop for VNet Links
resource "azurerm_private_dns_zone_virtual_network_link" "all_links" {
  for_each = local.private_dns_zones_existing

  # This creates names like "vnet-link-azure_storage_blob"
  name                  = "vnet-link-${each.key}"
  
  # The actual DNS zone name (e.g., privatelink.blob.core.windows.net)
  private_dns_zone_name = each.value.name
  
  resource_group_name   = local.hub_dns_resource_group_name
  virtual_network_id    = module.vnet.resource_id

  # Optional: Best practice to enable auto-registration if needed
  registration_enabled  = false 
}

# -----------------------------------------------------------------------------
# AI/ML Landing Zone Module
# -----------------------------------------------------------------------------
module "aiml_landing_zone" {
  source  = "Azure/avm-ptn-aiml-landing-zone/azurerm"
  version = "0.4.0"

  # ── Core Configuration ─────────────────────────────────────────────────────
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  enable_telemetry    = var.enable_telemetry

  # ── Platform Landing Zone Flag ─────────────────────────────────────────────
  # Set to false when using it as a application landing zone
  flag_platform_landing_zone = false

  vnet_definition = {
    existing_byo_vnet = {
      this_vnet = {
        vnet_resource_id = module.vnet.resource_id
      }
    }
    subnets = {
      JumpboxSubnet = {
        enabled        = true
      }
    }
    tags = var.tags
  }
  # ── Private DNS Zones — Use Hub's Existing Zones ───────────────────────────
  private_dns_zones = {
    # Enable Azure Policy to automatically link new private endpoints
    # to the existing hub DNS zones
    azure_policy_pe_zone_linking_enabled = true

    # Point to the hub's resource group where DNS zones are hosted
    existing_zones_resource_group_resource_id = data.azurerm_resource_group.hub_dns_resource_group.id
  }

  # ── GenAI Cosmos DB — Created by Landing Zone ──────────────────────────────
  # This will be used as BYOR for AI Foundry
  genai_cosmosdb_definition = {
    name              = "cosmos-aiml-${var.environment}-${var.location_short}"
    consistency_level = "Session"

    # Private endpoint using hub DNS zone
    enable_diagnostic_settings = true
  }

  # ── GenAI Key Vault — Created by Landing Zone ──────────────────────────────
  # This will be used as BYOR for AI Foundry
  genai_key_vault_definition = {
    name                          = "kv-aiml-${var.environment}-${substr(var.location_short, 0, 3)}"
    public_network_access_enabled = false

    network_acls = {
      bypass         = "AzureServices"
      default_action = "Deny"
    }

    enable_diagnostic_settings = true
  }

  # ── GenAI Storage Account — Created by Landing Zone ────────────────────────
  # This will be used as BYOR for AI Foundry
  genai_storage_account_definition = {
    name                      = "staiml${var.environment}${var.location_short}"
    shared_access_key_enabled = true

    endpoints = {
      blob = {
        type = "blob"
      }
      file = {
        type = "file"
      }
    }

    enable_diagnostic_settings = true
  }

  # ── Knowledge Store AI Search — Created by Landing Zone ────────────────────
  # This will be used as BYOR for AI Foundry
  ks_ai_search_definition = {
    name = "srch-aiml-${var.environment}-${var.location_short}"

    enable_diagnostic_settings = true
  }

  # ── AI Foundry Definition — Uses GenAI Resources as BYOR ───────────────────
  ai_foundry_definition = {
    # Core AI Foundry settings
    create_byor = true
    purge_on_destroy = false

    ai_foundry = {
      name                       = "aif-${var.workload_name}-${var.environment}-${var.location_short}"
      create_ai_agent_service    = true
      allow_project_management   = true
      disable_local_auth         = true
      enable_diagnostic_settings = true
      private_dns_zone_resource_ids = local.private_dns_zones_existing_id
    }
    create_byor              = true # default: false
    create_private_endpoints = true # default: false
    # ── AI Model Deployments ──────────────────────────────────────────────────
    ai_model_deployments = var.ai_model_deployments

    # ── AI Foundry Projects ───────────────────────────────────────────────────
    ai_projects = {
      default_project = {
        name         = "${var.workload_name}-project-${var.environment}"
        description  = "Default AI/ML project for ${var.workload_name}"
        display_name = "${var.workload_name} Project (${var.environment})"

        # Create connections to the BYOR resources
        create_project_connections = true

        # Connect to Cosmos DB
        cosmos_db_connection = {
          new_resource_map_key = "this"
        }

        # Connect to AI Search
        ai_search_connection = {
          new_resource_map_key = "this"
        }

        # Connect to Storage Account
        storage_account_connection = {
          new_resource_map_key = "this"
        }
      }
    }

    cosmosdb_definition = {
      this = {
        private_dns_zone_resource_id = local.private_dns_zones_existing.cosmos_sql_zone.resource_id
        consistency_level            = "Session"
      }
    }

    ai_search_definition = {
      this = {
        private_dns_zone_resource_id = local.private_dns_zones_existing.ai_search_zone.resource_id
      }
    }

    key_vault_definition = {
      this = {
        private_dns_zone_resource_id = local.private_dns_zones_existing.key_vault_zone.resource_id
      }
    }

    storage_account_definition = {
      this = {
        endpoints = {
          blob = {
            private_dns_zone_resource_id = local.private_dns_zones_existing.storage_blob_zone.resource_id
            type                         = "blob"
          }
          file = {
            private_dns_zone_resource_id = local.private_dns_zones_existing.storage_file_zone.resource_id
            type                         = "file"
          }
          queue = {
            private_dns_zone_resource_id = local.private_dns_zones_existing.storage_queue_zone.resource_id
            type                         = "queue"
          }
          table = {
            private_dns_zone_resource_id = local.private_dns_zones_existing.storage_table_zone.resource_id
            type                         = "table"
          }
        }
      }
    }
  }

  # ── Container App Environment (for GenAI apps) ─────────────────────────────
  container_app_environment_definition = {
    name                       = "cae-aiml-${var.environment}-${var.location_short}"
    enable_diagnostic_settings = true
  }

  # ── App Gateway (optional — for GenAI apps) ────────────────────────────────
  app_gateway_definition = {
    deploy = false
    backend_address_pools = {
      default_pool = {
        name = "aiml-backend-pool"
      }
    }

    backend_http_settings = {
      default_http_settings = {
        name     = "aiml-http-settings"
        port     = 80
        protocol = "Http"
      }
    }

    frontend_ports = {
      http_port = {
        name = "http-port-80"
        port = 80
      }
    }

    http_listeners = {
      http_listener = {
        name               = "http-listener"
        frontend_port_name = "http-port-80"
      }
    }

    request_routing_rules = {
      default_rule = {
        name                       = "default-routing-rule"
        rule_type                  = "Basic"
        http_listener_name         = "http-listener"
        backend_address_pool_name  = "aiml-backend-pool"
        backend_http_settings_name = "aiml-http-settings"
        priority                   = 100
      }
    }
  }

  # ── Bastion (optional — for secure VM access) ──────────────────────────────
  bastion_definition = var.enable_bastion ? {} : null

  # ── App Configuration (for GenAI apps) ─────────────────────────────────────
  genai_app_configuration_definition = {
    name                       = "appcs-aiml-${var.environment}-${var.location_short}"
    enable_diagnostic_settings = true
  }

  # ── Container Registry (for GenAI apps) ────────────────────────────────────
  genai_container_registry_definition = {
    name                       = "acr${var.workload_name}${var.environment}${var.location_short}"
    enable_diagnostic_settings = true
  }
  
  firewall_definition = {
    deploy = false
  }
  
  apim_definition = {
    deploy = false,
    publisher_name = ""
    publisher_email = ""
  }
}
