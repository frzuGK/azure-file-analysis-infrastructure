output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "drop_container_name" {
  description = "The name of the upload container"
  value       = azurerm_storage_container.drop.name
}

output "acr_name" {
  description = "The name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "The login server URL of the ACR"
  value       = azurerm_container_registry.main.login_server
}

output "container_app_job_name" {
  description = "The name of the Container Apps Job"
  value       = azurerm_container_app_job.analyzer.name
}

output "openai_endpoint" {
  description = "The endpoint of the Azure OpenAI service"
  value       = azurerm_cognitive_account.openai.endpoint
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}
