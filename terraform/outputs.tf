output "service_url" {
  description = "Cloud Run service URL"
  value       = module.cloud_run.service_url
}

output "service_name" {
  description = "Cloud Run service name"
  value       = module.cloud_run.service_name
}

output "service_account_email" {
  description = "Application service account email"
  value       = module.iam.app_service_account_email
}

output "secret_ids" {
  description = "Secret Manager secret IDs"
  value       = module.secret_manager.secret_ids
  sensitive   = true
}

output "environment" {
  description = "Deployment environment"
  value       = var.environment
}
