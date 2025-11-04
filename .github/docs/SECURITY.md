# Security & Authentication

## OAuth 2.0 Flow

### Overview
The application uses OAuth 2.0 to access Google Drive and Google Sheets on behalf of the user. This ensures secure access without sharing passwords.

### Initial Setup

#### 1. Create Google Cloud Project
```bash
# Navigate to https://console.cloud.google.com
# Create new project: "financia-expenses"
```

#### 2. Enable APIs
Enable the following APIs in your GCP project:
- Google Drive API
- Google Sheets API
- Secret Manager API
- Gemini API (if separate from standard AI Platform)

#### 3. Configure OAuth Consent Screen
```
User Type: Internal (for personal use) or External
App Name: Financia Expense Tracker
User support email: your-email@example.com
Developer contact: your-email@example.com
Scopes:
  - https://www.googleapis.com/auth/spreadsheets
  - https://www.googleapis.com/auth/drive.file
```

#### 4. Create OAuth 2.0 Credentials
```
Application type: Web application
Name: Financia Web Client
Authorized redirect URIs:
  - http://localhost:8080/oauth/callback (for local dev)
  - https://your-domain.com/oauth/callback (for production)
```

Save the **Client ID** and **Client Secret**.

### Authorization Flow

#### Step 1: Generate Authorization URL
```python
from google_auth_oauthlib.flow import Flow

def get_authorization_url():
    """Generate OAuth 2.0 authorization URL."""
    flow = Flow.from_client_config(
        {
            "web": {
                "client_id": GOOGLE_CLIENT_ID,
                "client_secret": GOOGLE_CLIENT_SECRET,
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "redirect_uris": ["http://localhost:8080/oauth/callback"],
            }
        },
        scopes=[
            "https://www.googleapis.com/auth/spreadsheets",
            "https://www.googleapis.com/auth/drive.file",
        ],
    )
    flow.redirect_uri = "http://localhost:8080/oauth/callback"

    authorization_url, state = flow.authorization_url(
        access_type="offline",  # Request refresh token
        include_granted_scopes="true",
        prompt="consent"  # Force consent screen to get refresh token
    )

    return authorization_url, state
```

#### Step 2: Handle Callback
```python
from fastapi import APIRouter, Request
from google_auth_oauthlib.flow import Flow

router = APIRouter()

@router.get("/oauth/callback")
async def oauth_callback(request: Request, code: str, state: str):
    """Handle OAuth 2.0 callback."""
    flow = Flow.from_client_config(
        client_config,
        scopes=SCOPES,
        state=state
    )
    flow.redirect_uri = "http://localhost:8080/oauth/callback"

    # Exchange authorization code for tokens
    flow.fetch_token(code=code)

    credentials = flow.credentials

    # Store refresh token in Secret Manager
    await store_secret("GOOGLE_REFRESH_TOKEN", credentials.refresh_token)

    return {"message": "Authorization successful!"}
```

#### Step 3: Use Refresh Token
```python
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request as GoogleRequest

async def get_authenticated_sheets_client():
    """Get authenticated Google Sheets client."""
    # Retrieve refresh token from Secret Manager
    refresh_token = await get_secret("GOOGLE_REFRESH_TOKEN")
    client_id = await get_secret("GOOGLE_CLIENT_ID")
    client_secret = await get_secret("GOOGLE_CLIENT_SECRET")

    # Create credentials from refresh token
    credentials = Credentials(
        None,  # No access token yet
        refresh_token=refresh_token,
        token_uri="https://oauth2.googleapis.com/token",
        client_id=client_id,
        client_secret=client_secret,
    )

    # Refresh access token if needed
    if not credentials.valid:
        credentials.refresh(GoogleRequest())

    # Build Sheets service
    from googleapiclient.discovery import build
    service = build("sheets", "v4", credentials=credentials)

    return service
```

---

## Secret Manager Integration

### Storing Secrets

#### Using gcloud CLI
```bash
# Create secret
gcloud secrets create GEMINI_API_KEY \
    --project=dev-ai-agents-projects \
    --replication-policy="automatic"

# Add secret version
echo -n "your-api-key-here" | \
gcloud secrets versions add GEMINI_API_KEY \
    --project=dev-ai-agents-projects \
    --data-file=-
```

#### Using Terraform
```hcl
# terraform/modules/secret_manager/main.tf
resource "google_secret_manager_secret" "gemini_api_key" {
  project   = var.project_id
  secret_id = "GEMINI_API_KEY"

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "gemini_api_key_version" {
  secret      = google_secret_manager_secret.gemini_api_key.id
  secret_data = var.gemini_api_key
}
```

### Retrieving Secrets

```python
from google.cloud import secretmanager
from typing import Optional
import logging

logger = logging.getLogger(__name__)

class SecretManagerClient:
    """Client for Google Secret Manager."""

    def __init__(self, project_id: str):
        self.project_id = project_id
        self.client = secretmanager.SecretManagerServiceClient()
        self._cache = {}  # Simple in-memory cache

    async def get_secret(self, secret_id: str, version: str = "latest") -> Optional[str]:
        """
        Retrieve secret from Secret Manager.

        Args:
            secret_id: Secret identifier
            version: Secret version (default: "latest")

        Returns:
            Secret value as string, or None if not found
        """
        # Check cache first
        cache_key = f"{secret_id}:{version}"
        if cache_key in self._cache:
            return self._cache[cache_key]

        try:
            name = f"projects/{self.project_id}/secrets/{secret_id}/versions/{version}"
            response = self.client.access_secret_version(request={"name": name})
            secret_value = response.payload.data.decode("UTF-8")

            # Cache for future use
            self._cache[cache_key] = secret_value

            return secret_value

        except Exception as e:
            logger.error(f"Error retrieving secret {secret_id}: {e}")
            return None

    async def store_secret(self, secret_id: str, value: str) -> bool:
        """
        Store a new secret version.

        Args:
            secret_id: Secret identifier
            value: Secret value

        Returns:
            True if successful, False otherwise
        """
        try:
            parent = f"projects/{self.project_id}/secrets/{secret_id}"
            response = self.client.add_secret_version(
                request={
                    "parent": parent,
                    "payload": {"data": value.encode("UTF-8")},
                }
            )

            # Clear cache for this secret
            self._cache = {k: v for k, v in self._cache.items() if not k.startswith(f"{secret_id}:")}

            logger.info(f"Stored new version of secret {secret_id}")
            return True

        except Exception as e:
            logger.error(f"Error storing secret {secret_id}: {e}")
            return False
```

---

## IAM & Service Accounts

### Cloud Run Service Account

Create a dedicated service account for Cloud Run with minimal permissions:

```hcl
# terraform/modules/iam/main.tf
resource "google_service_account" "financia_app" {
  project      = var.project_id
  account_id   = "financia-app"
  display_name = "Financia Application Service Account"
  description  = "Service account for Financia Cloud Run service"
}

# Grant Secret Manager access
resource "google_project_iam_member" "app_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.financia_app.email}"
}

# Grant Cloud Logging
resource "google_project_iam_member" "app_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.financia_app.email}"
}
```

### Terraform Service Account

The Terraform service account needs broader permissions:

```bash
# Create service account
gcloud iam service-accounts create gcp-terraform \
    --project=dev-ai-agents-projects \
    --display-name="Terraform Service Account"

# Grant necessary roles
gcloud projects add-iam-policy-binding dev-ai-agents-projects \
    --member="serviceAccount:gcp-terraform@dev-ai-agents-projects.iam.gserviceaccount.com" \
    --role="roles/run.admin"

gcloud projects add-iam-policy-binding dev-ai-agents-projects \
    --member="serviceAccount:gcp-terraform@dev-ai-agents-projects.iam.gserviceaccount.com" \
    --role="roles/secretmanager.admin"

gcloud projects add-iam-policy-binding dev-ai-agents-projects \
    --member="serviceAccount:gcp-terraform@dev-ai-agents-projects.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"
```

---

## Input Validation & Sanitization

### Sanitize User Input

```python
import re
from typing import Optional

def sanitize_text(text: str, max_length: int = 500) -> str:
    """
    Sanitize user input text.

    Args:
        text: Input text to sanitize
        max_length: Maximum allowed length

    Returns:
        Sanitized text
    """
    # Remove or escape potentially harmful characters
    text = text.strip()
    text = re.sub(r'[<>]', '', text)  # Remove HTML-like brackets
    text = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', text)  # Remove control characters
    text = text[:max_length]  # Truncate to max length

    return text

def validate_amount(amount: float) -> Optional[float]:
    """
    Validate expense amount.

    Args:
        amount: Amount to validate

    Returns:
        Validated amount or None if invalid
    """
    if amount <= 0:
        return None
    if amount > 1_000_000:  # Sanity check
        return None

    # Round to 2 decimal places
    return round(amount, 2)
```

### Rate Limiting

Implement rate limiting on webhook endpoint:

```python
from fastapi import Request, HTTPException
from collections import defaultdict
from datetime import datetime, timedelta
import asyncio

class RateLimiter:
    """Simple in-memory rate limiter."""

    def __init__(self, max_requests: int = 10, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.requests = defaultdict(list)
        self._lock = asyncio.Lock()

    async def check_rate_limit(self, identifier: str) -> bool:
        """
        Check if request is within rate limit.

        Args:
            identifier: Unique identifier (e.g., phone number)

        Returns:
            True if within limit, False otherwise
        """
        async with self._lock:
            now = datetime.now()
            cutoff = now - timedelta(seconds=self.window_seconds)

            # Remove old requests
            self.requests[identifier] = [
                req_time for req_time in self.requests[identifier]
                if req_time > cutoff
            ]

            # Check limit
            if len(self.requests[identifier]) >= self.max_requests:
                return False

            # Add current request
            self.requests[identifier].append(now)
            return True

# Usage in webhook
rate_limiter = RateLimiter(max_requests=10, window_seconds=60)

@router.post("/webhook")
async def whatsapp_webhook(webhook: WhatsAppWebhook):
    sender_id = webhook.entry[0].changes[0].value.messages[0].from_

    if not await rate_limiter.check_rate_limit(sender_id):
        raise HTTPException(
            status_code=429,
            detail="Rate limit exceeded. Please try again later."
        )

    # Process message...
```

---

## HTTPS & TLS

### Cloud Run Automatic HTTPS
Cloud Run automatically provides HTTPS with managed TLS certificates. No configuration needed.

### Custom Domain (Optional)
```bash
# Map custom domain to Cloud Run service
gcloud run domain-mappings create \
    --service=financia-api \
    --domain=api.financia.example.com \
    --region=us-central1 \
    --project=dev-ai-agents-projects
```

---

## Security Best Practices Checklist

- [ ] All secrets stored in Secret Manager (never in code)
- [ ] OAuth 2.0 refresh token secured
- [ ] Service accounts use least privilege IAM roles
- [ ] Input validation on all user inputs
- [ ] Rate limiting on webhook endpoint
- [ ] HTTPS enforced (automatic on Cloud Run)
- [ ] Secrets cache cleared on rotation
- [ ] Audit logging enabled
- [ ] Regular security reviews of dependencies (`uv audit`)
- [ ] Environment variables validated at startup
- [ ] Error messages don't leak sensitive information
- [ ] Webhook verify token is strong and random
- [ ] Access logs monitored for suspicious activity

---

## Monitoring & Alerts

### Set Up Security Alerts

```hcl
# terraform/modules/monitoring/main.tf
resource "google_monitoring_alert_policy" "unauthorized_access" {
  display_name = "Unauthorized Access Attempts"
  combiner     = "OR"

  conditions {
    display_name = "Webhook Verification Failures"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"logging.googleapis.com/user/webhook_verification_failed\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}
```

### Log Security Events

```python
import logging

security_logger = logging.getLogger("security")

# Log failed webhook verifications
security_logger.warning(
    "webhook_verification_failed",
    remote_ip=request.client.host,
    verify_token_hash=hashlib.sha256(provided_token.encode()).hexdigest()
)

# Log successful authentications
security_logger.info(
    "oauth_token_refreshed",
    user_id="single_user",
    token_expiry=credentials.expiry.isoformat()
)

# Log rate limit violations
security_logger.warning(
    "rate_limit_exceeded",
    sender_id=sender_id,
    request_count=len(requests)
)
```
