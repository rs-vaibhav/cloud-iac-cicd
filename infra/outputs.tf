output "resource_group" {
  value = azurerm_resource_group.this.name
}

output "aks_name" {
  value = module.aks.name
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "key_vault_name" {
  value = azurerm_key_vault.this.name
}

output "key_vault_csi_client_id" {
  description = "Client ID used by the SecretProviderClass in k8s/"
  value       = module.aks.key_vault_secrets_provider_client_id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "postgres_fqdn" {
  value = module.postgres.fqdn
}
