# Enable required Google Cloud APIs
# These need to be enabled before other resources can be created

resource "google_project_service" "required_apis" {
  for_each = toset([
    "secretmanager.googleapis.com",   # Secret Manager API
    "run.googleapis.com",              # Cloud Run API
    "iam.googleapis.com",              # IAM API
    "cloudresourcemanager.googleapis.com", # Cloud Resource Manager API
    "logging.googleapis.com",          # Cloud Logging API
    "monitoring.googleapis.com",       # Cloud Monitoring API
    "serviceusage.googleapis.com",     # Service Usage API
  ])

  project = var.project_id
  service = each.value

  # Don't disable the service if the resource is destroyed
  disable_on_destroy = false

  # Wait for the API to be fully enabled before proceeding
  timeouts {
    create = "10m"
    update = "10m"
  }
}

# Add a delay to ensure APIs are fully propagated
resource "time_sleep" "wait_for_apis" {
  depends_on = [google_project_service.required_apis]

  create_duration = "30s"
}
