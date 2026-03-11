#create a BYO vnet and peer to the hub
module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "=0.16.0"
  tags = var.tags
  location      = azurerm_resource_group.aiml_rg.location
  parent_id     = azurerm_resource_group.aiml_rg.id
  address_space = ["192.168.0.0/20"] # has to be out of 192.168.0.0/16 currently. Other RFC1918 not supported for foundry capabilityHost injection.
  name = local.aiml_vnet_name
  peerings = {
    peertovnet1 = {
      name                                 = "${module.naming.virtual_network_peering.name_unique}-aiml-spoke-to-hub"
      remote_virtual_network_resource_id   = local.hub_vnet_resource_id
      allow_forwarded_traffic              = true
      allow_gateway_transit                = true
      allow_virtual_network_access         = true
      create_reverse_peering               = true
      reverse_name                         = "${module.naming.virtual_network_peering.name_unique}-hub-to-aiml-spoke"
      reverse_allow_virtual_network_access = true
    }
  }
}

module "firewall_route_table" {
  source  = "Azure/avm-res-network-routetable/azurerm"
  version = "0.4.1"
  count = var.firewall_ip_address != null ? 1 : 0

  location                      = azurerm_resource_group.aiml_rg.location
  name                          = local.route_table_name
  resource_group_name           = azurerm_resource_group.aiml_rg.name
  bgp_route_propagation_enabled = true
  routes = var.use_internet_routing ? {
    internet_route = {
      name           = "default-to-internet"
      address_prefix = "0.0.0.0/0"
      next_hop_type  = "Internet"
    }
    } : {
    azure_firewall = {
      name                   = "default-to-firewall"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = var.firewall_ip_address
    }
  }
}

resource "azurerm_subnet_route_table_association" "associate_all" {
  # We use for_each to loop through the list of subnet names from the data source
  # We filter out GatewaySubnet or AzureFirewallSubnet as they usually shouldn't have custom UDRs
  for_each = {
    for s in module.vnet.subnets : s => s
    if s != "AzureBastionSubnet" && s != "AzureFirewallSubnet"
  }

  subnet_id      = "${module.vnet.resource_id}/subnets/${each.value}"
  route_table_id = module.firewall_route_table[0].resource.id
  depends_on = [ module.firewall_route_table[0], module.aiml_landing_zone]
}

