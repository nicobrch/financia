# Application Service Account
resource "google_service_account" "app" {
  project      = var.project_id
  account_id   = "${var.app_name}-app-${var.environment}"
  display_name = "Financia Application Service Account (${var.environment})"
  description  = "Service account for Financia Cloud Run service in ${var.environment}"
}

# Grant Secret Manager Secret Accessor role
resource "google_project_iam_member" "app_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Grant Cloud Logging Writer role
resource "google_project_iam_member" "app_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Grant Cloud Monitoring Metric Writer role
resource "google_project_iam_member" "app_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Grant Cloud Error Reporting Writer role
resource "google_project_iam_member" "app_error_writer" {
  project = var.project_id
  role    = "roles/errorreporting.writer"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Grant Cloud Trace Agent role (for distributed tracing)
resource "google_project_iam_member" "app_trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.app.email}"
}
