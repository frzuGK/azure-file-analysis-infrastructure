variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "westeurope"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "drop_container_name" {
  description = "Name of the blob container for file uploads"
  type        = string
  default     = "binaries-drop"
}

variable "output_container_name" {
  description = "Name of the blob container for analysis results"
  type        = string
  default     = "analysis-results"
}

variable "queue_name" {
  description = "Name of the storage queue for events"
  type        = string
  default     = "new-binary-events"
}

variable "openai_deployment_name" {
  description = "Name of the Azure OpenAI deployment"
  type        = string
  default     = "gpt-mini"
}

variable "container_image_name" {
  description = "Container image repository name"
  type        = string
  default     = "re-analyzer"
}

variable "container_image_tag" {
  description = "Container image tag"
  type        = string
  default     = "1.0.0"
}
