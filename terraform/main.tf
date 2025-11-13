terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Random suffix for unique resource names
resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}

locals {
  prefix   = "fileanalysis${random_integer.suffix.result}"
  location = var.location
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.prefix}"
  location = local.location
  tags     = local.tags
}

# Storage Account
resource "azurerm_storage_account" "main" {
  name                            = "st${local.prefix}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  allow_nested_items_to_be_public = false
  
  tags = local.tags
}

# Storage Containers
resource "azurerm_storage_container" "drop" {
  name                  = var.drop_container_name
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "output" {
  name                  = var.output_container_name
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Storage Queue
resource "azurerm_storage_queue" "events" {
  name                 = var.queue_name
  storage_account_name = azurerm_storage_account.main.name
}

# Event Grid System Topic
resource "azurerm_eventgrid_system_topic" "storage" {
  name                   = "es-${local.prefix}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  source_arm_resource_id = azurerm_storage_account.main.id
  topic_type             = "Microsoft.Storage.StorageAccounts"
  
  tags = local.tags
}

# Event Grid Subscription to Storage Queue
resource "azurerm_eventgrid_system_topic_event_subscription" "blob_to_queue" {
  name                = "blob-to-queue"
  system_topic        = azurerm_eventgrid_system_topic.storage.name
  resource_group_name = azurerm_resource_group.main.name

  storage_queue_endpoint {
    storage_account_id = azurerm_storage_account.main.id
    queue_name         = azurerm_storage_queue.events.name
  }

  included_event_types = ["Microsoft.Storage.BlobCreated"]
  
  subject_filter {
    subject_begins_with = "/blobServices/default/containers/${var.drop_container_name}/blobs/"
  }
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = local.tags
}

# Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                       = "env-${local.prefix}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  tags = local.tags
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = "acr${local.prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
  
  tags = local.tags
}

# Azure OpenAI Account
resource "azurerm_cognitive_account" "openai" {
  name                  = "aoai${local.prefix}"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  kind                  = "OpenAI"
  sku_name              = "S0"
  custom_subdomain_name = "aoai${local.prefix}"
  
  tags = local.tags
}

# Azure OpenAI Deployment
resource "azurerm_cognitive_deployment" "gpt4o_mini" {
  name                 = var.openai_deployment_name
  cognitive_account_id = azurerm_cognitive_account.openai.id
  
  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"
    version = "2024-07-18"
  }
  
  sku {
    name     = "GlobalStandard"
    capacity = 10
  }
}

# Container Apps Job
resource "azurerm_container_app_job" "analyzer" {
  name                         = "job-analyze-${local.prefix}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  container_app_environment_id = azurerm_container_app_environment.main.id
  
  replica_timeout_in_seconds = 300
  replica_retry_limit        = 2
  
  # System-assigned managed identity
  identity {
    type = "SystemAssigned"
  }
  
  # Registry configuration
  registry {
    server   = azurerm_container_registry.main.login_server
    identity = "system"
  }
  
  # Secrets
  secret {
    name  = "storagecs"
    value = azurerm_storage_account.main.primary_connection_string
  }
  
  secret {
    name  = "aoai-key"
    value = azurerm_cognitive_account.openai.primary_access_key
  }
  
  secret {
    name  = "aoai-endpoint"
    value = azurerm_cognitive_account.openai.endpoint
  }
  
  # Template configuration
  template {
    container {
      name   = "analyzer"
      image  = "${azurerm_container_registry.main.login_server}/${var.container_image_name}:${var.container_image_tag}"
      cpu    = 1.0
      memory = "2Gi"
      
      env {
        name        = "AZURE_STORAGE_CONNECTION_STRING"
        secret_name = "storagecs"
      }
      
      env {
        name        = "AOAI_KEY"
        secret_name = "aoai-key"
      }
      
      env {
        name        = "AOAI_ENDPOINT"
        secret_name = "aoai-endpoint"
      }
      
      env {
        name  = "QUEUE_NAME"
        value = var.queue_name
      }
      
      env {
        name  = "DROP_CONTAINER"
        value = var.drop_container_name
      }
      
      env {
        name  = "OUT_CONTAINER"
        value = var.output_container_name
      }
    }
  }
  
  # Event-driven scale rule
  event_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
    
    scale {
      min_executions = 0
      max_executions = 10
      
      rules {
        name             = "azure-queue"
        custom_rule_type = "azure-queue"
        
        metadata = {
          queueName   = var.queue_name
          queueLength = "1"
        }
        
        authentication {
          secret_name       = "storagecs"
          trigger_parameter = "connection"
        }
      }
    }
  }
  
  tags = local.tags
  
  depends_on = [
    azurerm_role_assignment.job_acr_pull
  ]
}

# Role Assignment: Container Apps Job -> ACR Pull
resource "azurerm_role_assignment" "job_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app_job.analyzer.identity[0].principal_id
}
