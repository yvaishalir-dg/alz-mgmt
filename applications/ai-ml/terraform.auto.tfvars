# =============================================================================
# applications/aiml/terraform.tfvars
#
# Example configuration for AI/ML landing zone deployment.
# Update these values to match your environment before running terraform apply.
# =============================================================================

# ── Identity ──────────────────────────────────────────────────────────────────
location       = "eastus"  # Or eastus, westeurope, etc.
location_short = "eus"             # eus, weu, etc.
environment    = "dev"
workload_name  = "aiml"

# ── Resource Group ────────────────────────────────────────────────────────────
resource_group_name = "rg-aiml-dev-001"

# ── VNet Configuration ────────────────────────────────────────────────────────
# The module creates a NEW VNet with this address space and peers it to hub
# IMPORTANT: AI Foundry currently requires 192.168.0.0/16 range
vnet_address_space = "192.168.0.0/23"
firewall_ip_address = null
# DNS servers — use hub's Private DNS Resolver inbound endpoints if available
# Otherwise leave empty to use Azure default DNS (168.63.129.16)
hub_dns_server_ips = []  # Example: ["10.0.1.4", "10.0.1.5"]

# ── Platform Remote State ─────────────────────────────────────────────────────
platform_state_resource_group_name  = "rg-alz-mgmt-state-eastus-001"
platform_state_storage_account_name = "stoalzmgmeas001lllk"
platform_state_container_name       = "mgmt-tfstate"
platform_state_key                  = "terraform.tfstate"

# ── AI Model Deployments ─────────────────────────────────────────────────────
# Define which AI models to deploy in the AI Foundry Hub
ai_model_deployments = {
  "gpt-4o" = {
    name = "gpt-4o-deployment"
    model = {
      format  = "OpenAI"
      name    = "gpt-4o"
      version = "2024-05-13"
    }
    scale = {
      type     = "Standard"
      capacity = 10
    }
  }
  "text-embedding-ada-002" = {
    name = "text-embedding-ada-002"
    model = {
      format  = "OpenAI"
      name    = "text-embedding-ada-002"
      version = "2"
    }
    scale = {
      type     = "Standard"
      capacity = 10
    }
  }
}

# ── Optional Features ─────────────────────────────────────────────────────────
enable_app_gateway = false  # Set to true if you need Application Gateway for GenAI apps
enable_bastion     = false  # Set to true if you need Bastion for VM access

# ── Tags ──────────────────────────────────────────────────────────────────────
tags = {
  Environment  = "dev"
  Workload     = "aiml"
  CostCenter   = "ai-platform"
  ManagedBy    = "terraform"
  Owner        = "application-team"
  Project      = "ai-ml-landing-zone"
}
