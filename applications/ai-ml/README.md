# AI/ML Landing Zone — BYOR Pattern with AI Foundry

## Architecture Overview

This configuration deploys an AI/ML application landing zone that:

1. ✅ Creates a **NEW VNet** and peers it to the platform hub (NOT BYO existing VNet)
2. ✅ Uses platform hub's **DNS zones** and **firewall** for routing
3. ✅ Creates **GenAI resources** (Cosmos DB, Storage, Key Vault, AI Search)
4. ✅ Uses those GenAI resources as **BYOR** (Bring Your Own Resource) for **AI Foundry**
5. ✅ Creates **AI Foundry Hub + Projects** with connections to BYOR resources

---

## Resource Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│  PLATFORM HUB (platform/single_zone)                                     │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  Hub VNet  10.0.0.0/16                                             │  │
│  │  ├─ Azure Firewall      10.0.1.4                                   │  │
│  │  ├─ VPN/ExpressRoute Gateway                                       │  │
│  │  └─ Private DNS Resolver (optional)                                │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  Private DNS Zones (centralized)                                   │  │
│  │  ├─ privatelink.services.ai.azure.com                              │  │
│  │  ├─ privatelink.openai.azure.com                                   │  │
│  │  ├─ privatelink.blob.core.windows.net                              │  │
│  │  ├─ privatelink.vaultcore.azure.net                                │  │
│  │  ├─ privatelink.documents.azure.com                                │  │
│  │  └─ privatelink.search.windows.net                                 │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
                            │
                            │ VNet Peering
                            │ (created by module)
                            ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  AI/ML SPOKE (applications/aiml)                                         │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  NEW Spoke VNet  192.168.0.0/23  ← Created by module                │  │
│  │  Peered to Hub ✓                                                   │  │
│  │  Firewall routing: All egress → 10.0.1.4 ✓                         │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  STEP 1: Create GenAI Resources (for general AI apps + AI Foundry BYOR) │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  genai_cosmosdb_definition        → cosmos-aiml-dev-sec             │  │
│  │  genai_key_vault_definition       → kv-aiml-dev-sec                 │  │
│  │  genai_storage_account_definition → staimldevsec                    │  │
│  │  ks_ai_search_definition          → srch-aiml-dev-sec               │  │
│  │                                                                     │  │
│  │  Each with Private Endpoint → Hub DNS zones ✓                      │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                            │                                             │
│                            │ (BYOR References)                           │
│                            ▼                                             │
│  STEP 2: Create AI Foundry Using GenAI Resources as BYOR                │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  ai_foundry_definition:                                            │  │
│  │                                                                     │  │
│  │    cosmosdb_definition = { this = {} }                             │  │
│  │      ↓ references → cosmos-aiml-dev-sec                            │  │
│  │                                                                     │  │
│  │    key_vault_definition = { this = {} }                            │  │
│  │      ↓ references → kv-aiml-dev-sec                                │  │
│  │                                                                     │  │
│  │    storage_account_definition = { this = {} }                      │  │
│  │      ↓ references → staimldevsec                                   │  │
│  │                                                                     │  │
│  │    ai_search_definition = { this = {} }                            │  │
│  │      ↓ references → srch-aiml-dev-sec                              │  │
│  │                                                                     │  │
│  │  ai_projects = {                                                   │  │
│  │    default_project = {                                             │  │
│  │      create_project_connections = true                             │  │
│  │      cosmos_db_connection = { new_resource_map_key = "this" }      │  │
│  │      ai_search_connection = { new_resource_map_key = "this" }      │  │
│  │      storage_account_connection = { new_resource_map_key = "this" }│  │
│  │    }                                                               │  │
│  │  }                                                                 │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  RESULT: AI Foundry Hub + Project with connections to shared resources  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Key Concepts Explained

### 1. What is BYOR (Bring Your Own Resource)?

BYOR means AI Foundry **uses existing resources** instead of creating its own. In this configuration:

**Without BYOR (module creates everything):**
```hcl
ai_foundry_definition = {
  cosmosdb_definition = {
    cosmos1 = {
      # Module creates NEW Cosmos DB just for AI Foundry
      consistency_level = "Session"
    }
  }
}

# Total Cosmos DBs created: 1 (dedicated to AI Foundry only)
```

**With BYOR (shared resources):**
```hcl
# Step 1: Create Cosmos DB for GenAI apps
genai_cosmosdb_definition = {
  name = "cosmos-aiml-dev"
  consistency_level = "Session"
}

# Step 2: AI Foundry uses the SAME Cosmos DB via BYOR
ai_foundry_definition = {
  cosmosdb_definition = {
    this = {
      # References the Cosmos DB created above
      # "this" key matches the genai resource
    }
  }
}

# Total Cosmos DBs created: 1 (shared by GenAI apps AND AI Foundry)
```

**Benefits of BYOR:**
- ✅ **Cost savings** — one set of resources instead of two
- ✅ **Consistency** — GenAI apps and AI Foundry use same storage/search/vault
- ✅ **Simplified management** — fewer resources to monitor
- ✅ **Data sharing** — AI Foundry projects can access data from GenAI apps

---

### 2. The "this" Key Pattern

The map key `"this"` is the **link between genai_* and ai_foundry_definition**:

```hcl
# The key "this" here...
genai_cosmosdb_definition = {
  name = "cosmos-aiml-dev"
}

# ...matches the key "this" here
ai_foundry_definition = {
  cosmosdb_definition = {
    this = {
      # Empty object means: use the Cosmos DB from genai_cosmosdb_definition
    }
  }
  
  ai_projects = {
    project1 = {
      cosmos_db_connection = {
        new_resource_map_key = "this"  # ← Points to the "this" key above
      }
    }
  }
}
```

**The module internally does:**
1. Creates Cosmos DB from `genai_cosmosdb_definition`
2. Stores it in an internal map with key `"this"`
3. When AI Foundry needs Cosmos DB, looks up key `"this"` in the map
4. Connects AI Foundry to that existing Cosmos DB

You can use different keys if you want multiple resources:

```hcl
genai_cosmosdb_definition = {
  name = "cosmos-genai-apps"
}

ai_foundry_definition = {
  cosmosdb_definition = {
    foundry_cosmos = {
      # Creates a SEPARATE Cosmos DB just for AI Foundry
      # Not BYOR, because key doesn't match any genai_* resource
    }
  }
}
```

But for your use case (shared resources), always use `"this"` for everything.

---

### 3. VNet Creation vs BYO VNet

**This configuration creates a NEW VNet** (NOT BYO existing VNet):

```hcl
vnet_definition = {
  name          = "vnet-aiml-dev-sec"
  address_space = ["192.168.0.0/23"]  # Module creates this VNet
  
  hub_vnet_peering_definition = {
    peer_vnet_resource_id = local.hub_vnet_resource_id  # Peer to hub
    firewall_ip_address   = local.firewall_private_ip   # Route via firewall
  }
}
```

**What the module does:**
1. Creates VNet `vnet-aiml-dev-sec` with address space `192.168.0.0/23`
2. Creates subnets inside this VNet for:
   - Private endpoints
   - Container Apps (AI agent services)
   - App Gateway (if enabled)
   - Bastion (if enabled)
3. Peers this VNet to the hub VNet (bidirectional peering)
4. Configures route tables to send all egress traffic to firewall IP

**The alternative (true BYO VNet) would be:**
```hcl
virtual_network = {
  existing_byo_vnet = {
    spoke = {
      vnet_resource_id = "/subscriptions/.../virtualNetworks/my-existing-vnet"
      firewall_ip_address = "10.0.1.4"
    }
  }
}
```
This is NOT what your configuration does.

---

### 4. Private DNS Zones Integration

```hcl
private_dns_zones = {
  azure_policy_pe_zone_linking_enabled = true
  existing_zones_resource_group_resource_id = local.hub_resource_group_id
}
```

**What this does:**
- Enables Azure Policy to **automatically link private endpoints** to hub DNS zones
- When a private endpoint is created (e.g., for Cosmos DB), Azure Policy:
  1. Detects the private endpoint
  2. Finds the matching DNS zone in the hub resource group
  3. Writes an A record into that zone pointing to the private endpoint's IP

**Without this:** You'd need to manually configure DNS zone groups for every private endpoint.

**With this:** Automatic — all private endpoints get DNS records in hub zones with zero manual config.

---

## Deployment Order

```
1. Platform Hub (platform/single_zone)
   └─ Creates hub VNet, firewall, DNS zones
   └─ Exports outputs via remote state

2. AI/ML Landing Zone (applications/aiml)
   ├─ Reads platform outputs via remote state
   ├─ Creates NEW spoke VNet and peers to hub
   ├─ Creates GenAI resources (Cosmos, Storage, Key Vault, AI Search)
   ├─ Creates AI Foundry Hub using GenAI resources as BYOR
   └─ Creates AI Foundry Project with connections to BYOR resources
```

---

## Common Questions

### Q1: Can GenAI apps and AI Foundry share the same Cosmos DB database?

**Yes.** That's the entire point of BYOR. Both can use the same Cosmos DB account, and you can create different databases/containers for each workload:

```
Cosmos DB Account: cosmos-aiml-dev
├─ Database: genai-apps
│  └─ Container: user-sessions
├─ Database: ai-foundry
│  └─ Container: model-training-data
```

AI Foundry projects reference the Cosmos DB account, then create their own databases inside it.

---

### Q2: What if I want AI Foundry to have its own dedicated resources?

Change the keys to NOT match:

```hcl
genai_cosmosdb_definition = {
  name = "cosmos-genai"
}

ai_foundry_definition = {
  cosmosdb_definition = {
    foundry_dedicated = {  # ← Different key = new resource
      consistency_level = "Session"
    }
  }
}
```

Now you have **two** Cosmos DBs.

---

### Q3: Why use 192.168.0.0/23 instead of 10.x.x.x?

AI Foundry has a **current limitation** — it requires VNets to be in the `192.168.0.0/16` range for capability host injection (AI agent services). This is a known restriction and may change in future versions.

---

## Files in This Configuration

| File | Purpose |
|---|---|
| `main.tf` | Module configuration with BYOR pattern |
| `variables.tf` | Input variables |
| `outputs.tf` | Resource IDs and endpoints |
| `terraform.tfvars` | Example values |
| `platform-outputs.tf` | Required platform hub outputs |

---

## Next Steps

1. **Update platform hub** — Add the outputs from `platform-outputs.tf` to your `platform/single_zone/outputs.tf`
2. **Update tfvars** — Modify `terraform.tfvars` with your actual values
3. **Deploy:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Verify BYOR connections:**
   - Go to Azure Portal → AI Foundry Hub
   - Check "Connected Resources"
   - Should show Cosmos DB, Storage, Key Vault, AI Search all connected ✓
