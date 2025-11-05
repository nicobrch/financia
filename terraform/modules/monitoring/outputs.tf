output "dashboard_url" {
  description = "URL to the monitoring dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.app_dashboard.id}?project=${var.project_id}"
}

output "notification_channel_id" {
  description = "ID of the notification channel"
  value       = var.notification_email != "" ? google_monitoring_notification_channel.email[0].id : null
}
