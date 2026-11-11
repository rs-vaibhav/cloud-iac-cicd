locals {
  name = "${var.project}-${var.environment}"
  tags = merge({
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
    cost_center = "gts-internship"
  }, var.tags)
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

module "network" {
  source = "./modules/network"

  name                  = local.name
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  vnet_cidr             = var.vnet_cidr
  allowed_ingress_cidrs = var.allowed_ingress_cidrs
  tags                  = local.tags
}

module "acr" {
  source = "./modules/acr"

  # ACR names must be globally unique and alphanumeric
  name                = replace("acr${local.name}${substr(md5(data.azurerm_client_config.current.subscription_id), 0, 6)}", "-", "")
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = var.environment == "prod" ? "Standard" : "Basic"
  tags                = local.tags
}

module "aks" {
  source = "./modules/aks"

  name                       = local.name
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  subnet_id                  = module.network.aks_subnet_id
  kubernetes_version         = var.kubernetes_version
  vm_size                    = var.aks_vm_size
  node_count                 = var.aks_node_count
  max_nodes                  = var.aks_max_nodes
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  acr_id                     = module.acr.id
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  tags                       = local.tags
}

module "postgres" {
  source = "./modules/postgres"

  name                = local.name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  delegated_subnet_id = module.network.db_subnet_id
  private_dns_zone_id = module.network.postgres_private_dns_zone_id
  sku_name            = var.postgres_sku
  storage_mb          = var.postgres_storage_mb
  high_availability   = var.postgres_ha
  tags                = local.tags
}

# ---- Secrets: the DB connection string lives in Key Vault, never in Git or tfvars ----
resource "azurerm_key_vault" "this" {
  name                       = substr(replace("kv-${local.name}-${substr(md5(data.azurerm_client_config.current.subscription_id), 0, 6)}", "_", "-"), 0, 24)
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  purge_protection_enabled   = var.environment == "prod"
  soft_delete_retention_days = 7
  tags                       = local.tags
}

resource "azurerm_role_assignment" "kv_admin_deployer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# AKS workload identity reads secrets through the Key Vault CSI driver
resource "azurerm_role_assignment" "kv_reader_aks" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.aks.key_vault_secrets_provider_identity_object_id
}

resource "azurerm_key_vault_secret" "database_url" {
  name         = "database-url"
  key_vault_id = azurerm_key_vault.this.id
  value        = module.postgres.connection_string
  content_type = "postgresql connection string"
  depends_on   = [azurerm_role_assignment.kv_admin_deployer]
}
