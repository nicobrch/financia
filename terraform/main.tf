# Local variables
locals {
  app_name = "financia"
  labels = {
    app         = local.app_name
    environment = var.environment
    managed_by  = "terraform"
  }

  # Secret names
  secret_names = {
    whatsapp_api_key     = "WHATSAPP_API_KEY_${upper(var.environment)}"
    gemini_api_key       = "GEMINI_API_KEY_${upper(var.environment)}"
    google_client_id     = "GOOGLE_CLIENT_ID_${upper(var.environment)}"
    google_client_secret = "GOOGLE_CLIENT_SECRET_${upper(var.environment)}"
    google_refresh_token = "GOOGLE_REFRESH_TOKEN_${upper(var.environment)}"
  }
}

# IAM Module - Service Accounts and Roles
module "iam" {
  source = "./modules/iam"

  project_id  = var.project_id
  app_name    = local.app_name
  environment = var.environment
  labels      = local.labels

  depends_on = [time_sleep.wait_for_apis]
}

# Secret Manager Module - Store Application Secrets
module "secret_manager" {
  source = "./modules/secret_manager"

  project_id  = var.project_id
  environment = var.environment

  secrets = {
    (local.secret_names.whatsapp_api_key)     = var.whatsapp_api_key
    (local.secret_names.gemini_api_key)       = var.gemini_api_key
    (local.secret_names.google_client_id)     = var.google_client_id
    (local.secret_names.google_client_secret) = var.google_client_secret
    (local.secret_names.google_refresh_token) = var.google_refresh_token
  }

  service_account_email = module.iam.app_service_account_email
  labels                = local.labels

  depends_on = [time_sleep.wait_for_apis]
}

# Cloud Run Module - Deploy Application
module "cloud_run" {
  source = "./modules/cloud_run"

  project_id   = var.project_id
  region       = var.region
  service_name = var.service_name
  image        = var.container_image
  environment  = var.environment
  labels       = local.labels

  # Environment variables (non-sensitive)
  environment_variables = {
    GCP_PROJECT_ID                = var.project_id
    SPREADSHEET_ID                = var.spreadsheet_id
    WHATSAPP_WEBHOOK_VERIFY_TOKEN = var.whatsapp_webhook_verify_token
    ENVIRONMENT                   = var.environment
    LOG_LEVEL                     = var.environment == "prod" ? "INFO" : "DEBUG"
    GEMINI_MODEL                  = "gemini-pro"
  }

  # Secret references (retrieved from Secret Manager at runtime)
  secret_environment_variables = {
    WHATSAPP_API_KEY     = "${module.secret_manager.secret_ids[local.secret_names.whatsapp_api_key]}/versions/latest"
    GEMINI_API_KEY       = "${module.secret_manager.secret_ids[local.secret_names.gemini_api_key]}/versions/latest"
    GOOGLE_CLIENT_ID     = "${module.secret_manager.secret_ids[local.secret_names.google_client_id]}/versions/latest"
    GOOGLE_CLIENT_SECRET = "${module.secret_manager.secret_ids[local.secret_names.google_client_secret]}/versions/latest"
    GOOGLE_REFRESH_TOKEN = "${module.secret_manager.secret_ids[local.secret_names.google_refresh_token]}/versions/latest"
  }

  service_account_email = module.iam.app_service_account_email

  # Resource limits
  min_instances   = var.min_instances
  max_instances   = var.max_instances
  memory_limit    = var.memory_limit
  cpu_limit       = var.cpu_limit
  timeout_seconds = var.timeout_seconds

  depends_on = [module.iam, module.secret_manager]
}

# Monitoring Module - Logging and Alerts
module "monitoring" {
  source = "./modules/monitoring"

  project_id             = var.project_id
  service_name           = var.service_name
  environment            = var.environment
  notification_email     = var.alert_notification_email
  cloud_run_service_name = module.cloud_run.service_name

  labels = local.labels

  depends_on = [module.cloud_run]
}
