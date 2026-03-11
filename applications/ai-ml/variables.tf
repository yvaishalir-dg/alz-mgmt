# =============================================================================
# applications/aiml/variables.tf
# =============================================================================

# ── Required ──────────────────────────────────────────────────────────────────

variable "location" {
  type        = string
  description = "Azure region where all AI/ML resources will be deployed. Must match or be compatible with the hub region."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group for the AI/ML landing zone resources."
}

variable "workload_name" {
  type        = string
  description = "Short name identifying this workload. Used in resource naming. e.g. 'aiml', 'genai', 'mlops'."
}

variable "environment" {
  type        = string
  description = "Environment shortname. e.g. 'dev', 'tst', 'stg', 'prd'."
  validation {
    condition     = contains(["dev", "tst", "stg", "prd"], var.environment)
    error_message = "environment must be one of: dev, tst, stg, prd."
  }
}

variable "location_short" {
  type        = string
  description = "Short location code used in resource names. e.g. 'eus' for East US, 'weu' for West Europe, 'sec' for Sweden Central."
}

# ── VNet Configuration ────────────────────────────────────────────────────────

variable "vnet_address_space" {
  type        = string
  description = <<EOT
Address space for the NEW VNet that the module will create and peer to the hub.
This is NOT BYO VNet — the module creates a new VNet with this CIDR.
Must not overlap with hub or other spoke VNets.
Example: "10.100.0.0/23" or "192.168.0.0/23"
Note: AI Foundry has restrictions — must be in 192.168.0.0/16 range currently.
EOT
  default     = "192.168.0.0/23"

  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "vnet_address_space must be a valid CIDR block."
  }
}

variable "firewall_ip_address" {
  type = string
  description = "(Optional) IP address of the firewall if a firewall is deployed for use by the BYO vnet. This IP address wlll be used to configure the route table for the subnets when provided. If using a BYO Vnet, the firewall is assumed to be deployed and configured outside of this module."
  default = null
}

variable "hub_dns_server_ips" {
  type        = list(string)
  description = <<EOT
DNS server IP addresses to use in the spoke VNet.
If your hub has Private DNS Resolver inbound endpoints, specify their IPs here.
Otherwise, leave empty to use Azure default DNS (168.63.129.16).
Example: ["10.0.1.4", "10.0.1.5"]
EOT
  default     = []
}

variable "use_internet_routing" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
Use direct internet routing instead of firewall routing for subnets when platform landing zone is enabled.

When set to true and `flag_platform_landing_zone` is true, route tables will use NextHopType = "Internet"
for 0.0.0.0/0 traffic instead of NextHopType = "VirtualAppliance" routing through the Azure Firewall.

This setting is particularly useful for Azure Application Gateway v2 deployments that require direct
internet connectivity and cannot use virtual appliance routing.

**Security Considerations**: Enabling this setting bypasses the Azure Firewall for internet-bound traffic
from associated subnets, which may impact security posture. Ensure proper network security group rules
are in place when using this option.

**Compatibility**: This setting only applies when `flag_platform_landing_zone = true`. When
`flag_platform_landing_zone = false`, no route tables are created regardless of this setting.
DESCRIPTION
}

# ── Platform Remote State ─────────────────────────────────────────────────────

variable "platform_state_resource_group_name" {
  type        = string
  description = "Resource group name of the Azure Storage Account holding the platform Terraform state."
  default = "rg-alz-mgmt-state-eastus-001"
}

variable "platform_state_storage_account_name" {
  type        = string
  description = "Storage account name holding the platform Terraform remote state."
  default = "stoalzmgmeas001aqqd"
}

variable "platform_state_container_name" {
  type        = string
  default     = "mgmt-tfstate"
  description = "Blob container name for the platform Terraform state file."
}

variable "platform_state_key" {
  type        = string
  default     = "terraform.tfstate"
  description = "State file key (blob name) for the platform deployment."
}

# ── AI Foundry Configuration ──────────────────────────────────────────────────

variable "ai_model_deployments" {
  type = map(object({
    name = string
    model = object({
      format  = string
      name    = string
      version = string
    })
    scale = object({
      type     = string
      capacity = optional(number, 1)
    })
  }))
  description = <<EOT
Map of AI model deployments to create in the AI Foundry Hub.
Example:
{
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
}
EOT
  default     = {}
}

# ── Optional Features ─────────────────────────────────────────────────────────

variable "enable_app_gateway" {
  type        = bool
  default     = false
  description = "Whether to deploy Application Gateway for GenAI applications."
}

variable "enable_bastion" {
  type        = bool
  default     = false
  description = "Whether to deploy Azure Bastion for secure VM access."
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = "Whether to enable telemetry for AVM modules."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Map of tags to apply to all resources in this landing zone."
}

variable "jumpvm_definition" {
  type = object({
    deploy           = optional(bool, true)
    name             = optional(string)
    sku              = optional(string, "Standard_B2s")
    tags             = optional(map(string), {})
    enable_telemetry = optional(bool, true)
  })
  default     = {}
  description = <<DESCRIPTION
Configuration object for the Jump VM to be created for managing the implementation services.

- `deploy` - (Optional) Whether to deploy the Jump VM. Default is true.
- `name` - (Optional) The name of the Jump VM. If not provided, a name will be generated.
- `sku` - (Optional) The VM size/SKU for the Jump VM. Default is "Standard_B2s".
- `tags` - (Optional) Map of tags to assign to the Jump VM.
- `enable_telemetry` - (Optional) Whether telemetry is enabled for the Jump VM module. Default is true.
DESCRIPTION
}
