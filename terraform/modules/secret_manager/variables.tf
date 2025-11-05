variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "secrets" {
  description = "Map of secret names to secret values"
  type        = map(string)
  # Note: Not marked as sensitive here because for_each keys cannot be sensitive.
  # The actual secret values are still protected when stored in Secret Manager.
}

variable "service_account_email" {
  description = "Service account email that needs access to secrets"
  type        = string
}

variable "labels" {
  description = "Labels to apply to secrets"
  type        = map(string)
  default     = {}
}
