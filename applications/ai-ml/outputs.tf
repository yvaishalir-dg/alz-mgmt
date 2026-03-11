# =============================================================================
# applications/aiml/outputs.tf
# =============================================================================

# ── Resource Group ────────────────────────────────────────────────────────────

output "resource_group_name" {
  description = "Name of the AI/ML landing zone resource group."
  value       = var.resource_group_name
}

# ── VNet ──────────────────────────────────────────────────────────────────────

output "vnet_resource_id" {
  description = "Resource ID of the AI/ML spoke VNet created by the module."
  value       = module.vnet.resource_id
}

output "vnet_name" {
  description = "Name of the AI/ML spoke VNet."
  value       = module.vnet.name
}

# ── AI Foundry ────────────────────────────────────────────────────────────────

output "log_analytics_workspace_id" {
  description = "Resource ID of the deployed log analytics workspace."
  value       = module.aiml_landing_zone.log_analytics_workspace_id
}

# output "ai_foundry_name" {
#   description = "Name of the deployed AI Foundry Hub."
#   value       = module.aiml_landing_zone.ai_foundry_name
# }

# output "ai_foundry_endpoint" {
#   description = "Endpoint URL of the AI Foundry Hub."
#   value       = module.aiml_landing_zone.ai_foundry_endpoint
#   sensitive   = true
# }

# # ── GenAI Resources (BYOR for AI Foundry) ─────────────────────────────────────

# output "genai_key_vault_resource_id" {
#   description = "Resource ID of the Key Vault created by the landing zone and used by AI Foundry."
#   value       = module.aiml_landing_zone.genai_key_vault_resource_id
# }

# output "genai_storage_account_resource_id" {
#   description = "Resource ID of the Storage Account created by the landing zone and used by AI Foundry."
#   value       = module.aiml_landing_zone.genai_storage_account_resource_id
# }

# output "genai_cosmosdb_resource_id" {
#   description = "Resource ID of the Cosmos DB created by the landing zone and used by AI Foundry."
#   value       = module.aiml_landing_zone.genai_cosmosdb_resource_id
# }

# output "ks_ai_search_resource_id" {
#   description = "Resource ID of the AI Search created by the landing zone and used by AI Foundry."
#   value       = module.aiml_landing_zone.ks_ai_search_resource_id
# }

# # ── Container Apps ────────────────────────────────────────────────────────────

# output "container_app_environment_resource_id" {
#   description = "Resource ID of the Container App Environment for GenAI applications."
#   value       = module.aiml_landing_zone.container_app_environment_resource_id
# }

# ── Hub References (from platform remote state) ───────────────────────────────

output "hub_vnet_resource_id" {
  description = "Hub VNet resource ID consumed from platform remote state (for reference)."
  value       = local.hub_vnet_resource_id
}

output "firewall_private_ip" {
  description = "Azure Firewall private IP used for routing (from platform)."
  value       = local.firewall_private_ip
}
