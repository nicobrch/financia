# Environment Configuration
environment = "dev"
region      = "us-central1"

# Cloud Run Configuration
service_name    = "financia-api-dev"
container_image = "us-central1-docker.pkg.dev/dev-ai-agents-projects/financia/api:latest"

# Resource Configuration
min_instances   = 0
max_instances   = 5
memory_limit    = "512Mi"
cpu_limit       = "1"
timeout_seconds = 300

# Monitoring
alert_notification_email = "" # Set to your email if you want alerts in dev

# Note: Sensitive variables (API keys, tokens, etc.) are passed via GitHub Secrets
# and should NOT be committed to this file
# These include:
# - whatsapp_api_key
# - gemini_api_key
# - google_client_id
# - google_client_secret
# - google_refresh_token
# - spreadsheet_id
# - whatsapp_webhook_verify_token
