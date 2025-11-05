# Environment Configuration
environment = "prod"
region      = "us-central1"

# Cloud Run Configuration
service_name    = "financia-api"
container_image = "us-central1-docker.pkg.dev/prod-ai-agents-projects/financia/api:v1.0.0"

# Resource Configuration
min_instances   = 1 # Keep 1 instance warm in production
max_instances   = 20
memory_limit    = "512Mi"
cpu_limit       = "1"
timeout_seconds = 300

# Monitoring
alert_notification_email = "your-email@example.com" # TODO: Set your email

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
