# Project Configuration
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be either 'dev' or 'prod'."
  }
}

# Application Configuration
variable "service_name" {
  description = "Cloud Run service name"
  type        = string
}

variable "container_image" {
  description = "Container image URL from Artifact Registry"
  type        = string
}

variable "spreadsheet_id" {
  description = "Google Sheets spreadsheet ID"
  type        = string
  sensitive   = true
}

variable "whatsapp_webhook_verify_token" {
  description = "WhatsApp webhook verification token"
  type        = string
  sensitive   = true
}

# Secret Manager - Application Secrets
variable "whatsapp_api_key" {
  description = "WhatsApp Business API key"
  type        = string
  sensitive   = true
}

variable "gemini_api_key" {
  description = "Google Gemini API key"
  type        = string
  sensitive   = true
}

variable "google_client_id" {
  description = "OAuth 2.0 client ID"
  type        = string
  sensitive   = true
}

variable "google_client_secret" {
  description = "OAuth 2.0 client secret"
  type        = string
  sensitive   = true
}

variable "google_refresh_token" {
  description = "OAuth 2.0 refresh token"
  type        = string
  sensitive   = true
}

# Monitoring
variable "alert_notification_email" {
  description = "Email for monitoring alerts"
  type        = string
  default     = ""
}

# Resource Configuration
variable "min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 10
}

variable "memory_limit" {
  description = "Memory limit for Cloud Run container"
  type        = string
  default     = "512Mi"
}

variable "cpu_limit" {
  description = "CPU limit for Cloud Run container"
  type        = string
  default     = "1"
}

variable "timeout_seconds" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300
}
