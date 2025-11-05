variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "service_name" {
  description = "Name of the service being monitored"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "notification_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = ""
}

variable "cloud_run_service_name" {
  description = "Cloud Run service name to monitor"
  type        = string
}

variable "labels" {
  description = "Labels to apply to monitoring resources"
  type        = map(string)
  default     = {}
}
