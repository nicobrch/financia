# Terraform Infrastructure

## Overview
All GCP infrastructure for Financia is defined as code using Terraform. This ensures reproducible, version-controlled infrastructure deployments.

## Service Account
- **Name**: `gcp-terraform@dev-ai-agents-projects.iam.gserviceaccount.com`
- **Purpose**: Manage all GCP resources via Terraform
- **Permissions**: Cloud Run Admin, Secret Manager Admin, IAM Service Account User, Logging Admin

## Project Structure

```
terraform/
├── main.tf                 # Main configuration, module composition
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── versions.tf             # Provider versions and requirements
├── backend.tf              # GCS backend configuration
├── terraform.tfvars        # Variable values (gitignored)
├── modules/
│   ├── cloud_run/          # Cloud Run service module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── secret_manager/     # Secret Manager module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── iam/                # IAM roles and service accounts
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── monitoring/         # Logging and monitoring
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    ├── dev/                # Development environment
    │   ├── main.tf
    │   └── terraform.tfvars
    └── prod/               # Production environment
        ├── main.tf
        └── terraform.tfvars
```

---

## Core Configuration Files

### backend.tf
```hcl
terraform {
  backend "gcs" {
    bucket  = "financia-terraform-state"
    prefix  = "terraform/state"

    # Service account for state management
    impersonate_service_account = "gcp-terraform@dev-ai-agents-projects.iam.gserviceaccount.com"
  }
}
```

### versions.tf
```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  impersonate_service_account = "gcp-terraform@dev-ai-agents-projects.iam.gserviceaccount.com"
}
```

### variables.tf
```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "dev-ai-agents-projects"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "financia-api"
}

variable "container_image" {
  description = "Container image URL"
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

# Secret values (stored in Secret Manager, not in tfvars)
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
```

### main.tf
```hcl
# Local variables
locals {
  app_name = "financia"
  labels = {
    app         = local.app_name
    environment = var.environment
    managed_by  = "terraform"
  }
}

# IAM Module - Service Accounts and Roles
module "iam" {
  source = "./modules/iam"

  project_id  = var.project_id
  app_name    = local.app_name
  environment = var.environment
}

# Secret Manager Module - Store Secrets
module "secret_manager" {
  source = "./modules/secret_manager"

  project_id = var.project_id
  secrets = {
    whatsapp_api_key     = var.whatsapp_api_key
    gemini_api_key       = var.gemini_api_key
    google_client_id     = var.google_client_id
    google_client_secret = var.google_client_secret
    google_refresh_token = var.google_refresh_token
  }

  service_account_email = module.iam.app_service_account_email
}

# Cloud Run Module - Deploy Application
module "cloud_run" {
  source = "./modules/cloud_run"

  project_id    = var.project_id
  region        = var.region
  service_name  = var.service_name
  image         = var.container_image
  environment   = var.environment
  labels        = local.labels

  environment_variables = {
    GCP_PROJECT_ID                = var.project_id
    SPREADSHEET_ID                = var.spreadsheet_id
    WHATSAPP_WEBHOOK_VERIFY_TOKEN = var.whatsapp_webhook_verify_token
    ENVIRONMENT                   = var.environment
    LOG_LEVEL                     = var.environment == "prod" ? "INFO" : "DEBUG"
  }

  service_account_email = module.iam.app_service_account_email

  depends_on = [module.iam, module.secret_manager]
}

# Monitoring Module - Logging and Alerts
module "monitoring" {
  source = "./modules/monitoring"

  project_id   = var.project_id
  service_name = var.service_name
  environment  = var.environment

  notification_email = var.alert_notification_email
}
```

### outputs.tf
```hcl
output "service_url" {
  description = "Cloud Run service URL"
  value       = module.cloud_run.service_url
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
```

---

## Terraform Modules

### Cloud Run Module (`modules/cloud_run/`)

**main.tf**:
```hcl
resource "google_cloud_run_v2_service" "app" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = var.image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      # Environment variables
      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.key
          value = env.value
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    timeout = "300s"

    service_account = var.service_account_email
  }

  labels = var.labels
}

# Allow unauthenticated access (WhatsApp webhooks)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  name     = google_cloud_run_v2_service.app.name
  location = google_cloud_run_v2_service.app.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
```

**variables.tf**:
```hcl
variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "service_name" {
  type = string
}

variable "image" {
  type = string
}

variable "environment" {
  type = string
}

variable "labels" {
  type = map(string)
}

variable "environment_variables" {
  type = map(string)
}

variable "service_account_email" {
  type = string
}
```

**outputs.tf**:
```hcl
output "service_url" {
  value = google_cloud_run_v2_service.app.uri
}

output "service_id" {
  value = google_cloud_run_v2_service.app.id
}
```

### Secret Manager Module (`modules/secret_manager/`)

**main.tf**:
```hcl
resource "google_secret_manager_secret" "secrets" {
  for_each = var.secrets

  project   = var.project_id
  secret_id = upper(each.key)

  replication {
    auto {}
  }

  labels = {
    app        = "financia"
    managed_by = "terraform"
  }
}

resource "google_secret_manager_secret_version" "secret_versions" {
  for_each = var.secrets

  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value
}

# Grant access to app service account
resource "google_secret_manager_secret_iam_member" "app_access" {
  for_each = var.secrets

  secret_id = google_secret_manager_secret.secrets[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
}
```

### IAM Module (`modules/iam/`)

**main.tf**:
```hcl
resource "google_service_account" "app" {
  project      = var.project_id
  account_id   = "${var.app_name}-${var.environment}"
  display_name = "Financia Application (${var.environment})"
  description  = "Service account for Financia Cloud Run service"
}

# Grant Secret Manager access
resource "google_project_iam_member" "app_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Grant Cloud Logging
resource "google_project_iam_member" "app_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Grant Cloud Monitoring
resource "google_project_iam_member" "app_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.app.email}"
}
```

---

## Terraform Workflow

### Initialize
```bash
cd terraform
terraform init
```

### Plan
```bash
# Plan for dev environment
terraform plan -var-file="environments/dev/terraform.tfvars"

# Plan for prod environment
terraform plan -var-file="environments/prod/terraform.tfvars"
```

### Apply
```bash
# Apply to dev
terraform apply -var-file="environments/dev/terraform.tfvars"

# Apply to prod (requires confirmation)
terraform apply -var-file="environments/prod/terraform.tfvars"
```

### Destroy
```bash
# Destroy dev environment
terraform destroy -var-file="environments/dev/terraform.tfvars"
```

---

## Environment-Specific Configuration

### environments/dev/terraform.tfvars
```hcl
environment = "dev"
region      = "us-central1"

service_name = "financia-api-dev"
container_image = "us-central1-docker.pkg.dev/dev-ai-agents-projects/financia/api:latest"

spreadsheet_id = "your-dev-spreadsheet-id"
whatsapp_webhook_verify_token = "dev-verify-token-12345"

alert_notification_email = "dev-alerts@example.com"
```

### environments/prod/terraform.tfvars
```hcl
environment = "prod"
region      = "us-central1"

service_name = "financia-api"
container_image = "us-central1-docker.pkg.dev/dev-ai-agents-projects/financia/api:v1.0.0"

spreadsheet_id = "your-prod-spreadsheet-id"
whatsapp_webhook_verify_token = "prod-verify-token-67890"

alert_notification_email = "prod-alerts@example.com"
```

---

## State Management

### Create GCS Bucket for State
```bash
gcloud storage buckets create gs://financia-terraform-state \
    --project=dev-ai-agents-projects \
    --location=us-central1 \
    --uniform-bucket-level-access

# Enable versioning
gcloud storage buckets update gs://financia-terraform-state \
    --versioning
```

### State Locking
GCS backend automatically handles state locking.

---

## Best Practices

1. **Never commit secrets**: Use `terraform.tfvars` and add to `.gitignore`
2. **Use modules**: Keep code DRY and reusable
3. **Version providers**: Pin provider versions in `versions.tf`
4. **Plan before apply**: Always run `terraform plan` first
5. **Use workspaces**: Separate dev/prod state
6. **Tag resources**: Add labels for cost tracking and organization
7. **Remote state**: Store state in GCS, not locally
8. **Import existing**: Use `terraform import` for existing resources
9. **Document changes**: Add comments to explain complex configurations
10. **Review plans**: Carefully review terraform plan output

---

## Troubleshooting

### Issue: Authentication Error
```bash
# Ensure service account impersonation is configured
gcloud auth application-default login --impersonate-service-account=gcp-terraform@dev-ai-agents-projects.iam.gserviceaccount.com
```

### Issue: State Lock
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

### Issue: Import Existing Resource
```bash
# Import Cloud Run service
terraform import module.cloud_run.google_cloud_run_v2_service.app projects/dev-ai-agents-projects/locations/us-central1/services/financia-api
```

### Issue: Validate Configuration
```bash
terraform validate
terraform fmt -check
```
