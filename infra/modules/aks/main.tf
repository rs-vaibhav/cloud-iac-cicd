variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "subnet_id" { type = string }
variable "kubernetes_version" {
  type    = string
  default = null
}
variable "vm_size" { type = string }
variable "node_count" { type = number }
variable "max_nodes" { type = number }
variable "log_analytics_workspace_id" { type = string }
variable "acr_id" { type = string }
variable "tenant_id" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_kubernetes_cluster" "this" {
  name                      = "aks-${var.name}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  dns_prefix                = "aks-${var.name}"
  kubernetes_version        = var.kubernetes_version
  automatic_upgrade_channel = "patch"
  sku_tier                  = "Free"

  # Entra ID authentication + Azure RBAC for Kubernetes, no local admin accounts
  local_account_disabled = true
  azure_active_directory_role_based_access_control {
    tenant_id          = var.tenant_id
    azure_rbac_enabled = true
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                         = "system"
    vm_size                      = var.vm_size
    vnet_subnet_id               = var.subnet_id
    auto_scaling_enabled         = true
    node_count                   = var.node_count
    min_count                    = var.node_count
    max_count                    = var.max_nodes
    os_disk_size_gb              = 64
    only_critical_addons_enabled = false
    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "calico"
    load_balancer_sku   = "standard"
    pod_cidr            = "192.168.0.0/16"
    service_cidr        = "172.16.0.0/16"
    dns_service_ip      = "172.16.0.10"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [default_node_pool[0].node_count] # managed by the autoscaler
  }
}

# Nodes pull images from ACR using the kubelet managed identity (no registry passwords)
resource "azurerm_role_assignment" "acr_pull" {
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

output "name" { value = azurerm_kubernetes_cluster.this.name }
output "id" { value = azurerm_kubernetes_cluster.this.id }
output "oidc_issuer_url" { value = azurerm_kubernetes_cluster.this.oidc_issuer_url }
output "key_vault_secrets_provider_identity_object_id" {
  value = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].object_id
}
output "key_vault_secrets_provider_client_id" {
  value = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].client_id
}
