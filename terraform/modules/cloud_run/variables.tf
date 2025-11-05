variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
}

variable "image" {
  description = "Container image URL"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "labels" {
  description = "Labels to apply to the service"
  type        = map(string)
  default     = {}
}

variable "environment_variables" {
  description = "Environment variables (non-sensitive)"
  type        = map(string)
  default     = {}
}

variable "secret_environment_variables" {
  description = "Secret environment variables (references to Secret Manager)"
  type        = map(string)
  default     = {}
}

variable "service_account_email" {
  description = "Service account email for the Cloud Run service"
  type        = string
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "memory_limit" {
  description = "Memory limit (e.g., 512Mi, 1Gi)"
  type        = string
  default     = "512Mi"
}

variable "cpu_limit" {
  description = "CPU limit"
  type        = string
  default     = "1"
}

variable "timeout_seconds" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300
}

variable "concurrency" {
  description = "Maximum concurrent requests per instance"
  type        = number
  default     = 80
}

variable "ingress" {
  description = "Ingress settings (all, internal, internal-and-cloud-load-balancing)"
  type        = string
  default     = "all"
}
