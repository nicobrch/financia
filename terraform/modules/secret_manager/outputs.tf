output "secret_ids" {
  description = "Map of secret names to their full resource IDs"
  value = {
    for name, secret in google_secret_manager_secret.secrets :
    name => secret.id
  }
  sensitive = true
}

output "secret_names" {
  description = "List of secret names created"
  value       = keys(google_secret_manager_secret.secrets)
}
