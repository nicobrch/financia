# Deployment & CI/CD

## Overview
Financia uses GitHub Actions for continuous integration and deployment. The pipeline handles linting, testing, infrastructure provisioning, and application deployment.

## CI/CD Pipeline Architecture

```
Pull Request
    ↓
[Linting] → [Type Checking] → [Unit Tests] → [Terraform Plan]
    ↓
[Code Review] → [Approve]
    ↓
Merge to main
    ↓
[Terraform Apply] → [Docker Build] → [Push to Registry] → [Deploy to Cloud Run] → [Smoke Tests]
```

---

## GitHub Actions Workflows

### CI Workflow (`.github/workflows/ci.yml`)

```yaml
name: CI

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main, develop]

jobs:
  lint:
    name: Lint Code
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install UV
        run: curl -LsSf https://astral.sh/uv/install.sh | sh

      - name: Install dependencies
        run: uv sync

      - name: Run ruff
        run: uv run ruff check .

      - name: Run black (check only)
        run: uv run black --check .

  type-check:
    name: Type Checking
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install UV
        run: curl -LsSf https://astral.sh/uv/install.sh | sh

      - name: Install dependencies
        run: uv sync

      - name: Run mypy
        run: uv run mypy app/

  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install UV
        run: curl -LsSf https://astral.sh/uv/install.sh | sh

      - name: Install dependencies
        run: uv sync

      - name: Run pytest
        run: uv run pytest --cov=app --cov-report=xml --cov-report=term

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml

  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: gcp-terraform@dev-ai-agents-projects.iam.gserviceaccount.com

      - name: Terraform Init
        run: |
          cd terraform
          terraform init

      - name: Terraform Plan
        run: |
          cd terraform
          terraform plan -var-file="environments/dev/terraform.tfvars" -no-color
        env:
          TF_VAR_whatsapp_api_key: ${{ secrets.WHATSAPP_API_KEY }}
          TF_VAR_gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
          TF_VAR_google_client_id: ${{ secrets.GOOGLE_CLIENT_ID }}
          TF_VAR_google_client_secret: ${{ secrets.GOOGLE_CLIENT_SECRET }}
          TF_VAR_google_refresh_token: ${{ secrets.GOOGLE_REFRESH_TOKEN }}

      - name: Comment PR with Plan
        uses: actions/github-script@v7
        if: github.event_name == 'pull_request'
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const output = `#### Terraform Plan 📖
            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\`
            `;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })

  build:
    name: Build Docker Image
    runs-on: ubuntu-latest
    needs: [lint, type-check, test]
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build image
        run: |
          docker build -t financia-api:${{ github.sha }} .
```

---

### CD Workflow (`.github/workflows/cd.yml`)

```yaml
name: CD

on:
  push:
    branches: [main]
  workflow_dispatch:  # Manual trigger

jobs:
  terraform-apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: gcp-terraform@dev-ai-agents-projects.iam.gserviceaccount.com

      - name: Terraform Init
        run: |
          cd terraform
          terraform init

      - name: Terraform Apply
        run: |
          cd terraform
          terraform apply -var-file="environments/prod/terraform.tfvars" -auto-approve
        env:
          TF_VAR_container_image: us-central1-docker.pkg.dev/dev-ai-agents-projects/financia/api:${{ github.sha }}
          TF_VAR_whatsapp_api_key: ${{ secrets.WHATSAPP_API_KEY }}
          TF_VAR_gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
          TF_VAR_google_client_id: ${{ secrets.GOOGLE_CLIENT_ID }}
          TF_VAR_google_client_secret: ${{ secrets.GOOGLE_CLIENT_SECRET }}
          TF_VAR_google_refresh_token: ${{ secrets.GOOGLE_REFRESH_TOKEN }}

  build-and-deploy:
    name: Build and Deploy
    runs-on: ubuntu-latest
    needs: terraform-apply
    steps:
      - uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: gcp-terraform@dev-ai-agents-projects.iam.gserviceaccount.com

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker for Artifact Registry
        run: gcloud auth configure-docker us-central1-docker.pkg.dev

      - name: Build and Push Docker Image
        run: |
          docker build -t us-central1-docker.pkg.dev/dev-ai-agents-projects/financia/api:${{ github.sha }} .
          docker push us-central1-docker.pkg.dev/dev-ai-agents-projects/financia/api:${{ github.sha }}

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy financia-api \
            --image us-central1-docker.pkg.dev/dev-ai-agents-projects/financia/api:${{ github.sha }} \
            --region us-central1 \
            --platform managed \
            --project dev-ai-agents-projects

  smoke-tests:
    name: Smoke Tests
    runs-on: ubuntu-latest
    needs: build-and-deploy
    steps:
      - uses: actions/checkout@v4

      - name: Wait for deployment
        run: sleep 30

      - name: Test health endpoint
        run: |
          RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" https://financia-api-xxxxx-uc.a.run.app/health)
          if [ $RESPONSE -ne 200 ]; then
            echo "Health check failed with status $RESPONSE"
            exit 1
          fi
          echo "Health check passed"

      - name: Test webhook verification
        run: |
          RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "https://financia-api-xxxxx-uc.a.run.app/webhook?hub.mode=subscribe&hub.verify_token=${{ secrets.WHATSAPP_WEBHOOK_VERIFY_TOKEN }}&hub.challenge=test123")
          if [ $RESPONSE -ne 200 ]; then
            echo "Webhook verification failed with status $RESPONSE"
            exit 1
          fi
          echo "Webhook verification passed"

      - name: Notify on failure
        if: failure()
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '🚨 Deployment smoke tests failed',
              body: `Smoke tests failed for deployment ${context.sha}\n\nPlease investigate immediately.`,
              labels: ['deployment', 'critical']
            })
```

---

## Docker Configuration

### Dockerfile
```dockerfile
# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install UV
RUN pip install uv

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Install dependencies
RUN uv sync --no-dev

# Copy application code
COPY app/ ./app/
COPY main.py ./

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"

# Run application
CMD ["uv", "run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

### .dockerignore
```
.git
.github
.venv
__pycache__
*.pyc
*.pyo
*.pyd
.pytest_cache
.mypy_cache
.ruff_cache
.coverage
htmlcov/
dist/
build/
*.egg-info/
.env
.env.*
terraform/
tests/
docs/
*.md
!README.md
```

---

## Deployment Environments

### Development
- **Branch**: `develop`
- **Trigger**: Push to `develop` branch
- **Service**: `financia-api-dev`
- **URL**: `https://financia-api-dev-xxxxx-uc.a.run.app`
- **Auto-deploy**: Yes

### Production
- **Branch**: `main`
- **Trigger**: Push to `main` branch
- **Service**: `financia-api`
- **URL**: `https://financia-api-xxxxx-uc.a.run.app`
- **Auto-deploy**: Yes (with approval)
- **Requires**: Manual approval in GitHub Actions

---

## Rollback Strategy

### Automatic Rollback
Cloud Run supports automatic rollback on failed health checks:

```hcl
resource "google_cloud_run_v2_service" "app" {
  # ... other configuration

  template {
    # ... other configuration

    # Gradual rollout
    traffic {
      type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
      percent = 100
    }
  }
}
```

### Manual Rollback
```bash
# List revisions
gcloud run revisions list --service=financia-api --region=us-central1

# Rollback to specific revision
gcloud run services update-traffic financia-api \
  --to-revisions=financia-api-00042-abc=100 \
  --region=us-central1
```

### Rollback via Terraform
```bash
# Update terraform.tfvars with previous image
TF_VAR_container_image=us-central1-docker.pkg.dev/dev-ai-agents-projects/financia/api:previous-sha

# Apply
terraform apply -var-file="environments/prod/terraform.tfvars"
```

---

## Monitoring Deployment

### Cloud Run Logs
```bash
# View logs
gcloud run services logs read financia-api --region=us-central1 --limit=50

# Follow logs in real-time
gcloud run services logs tail financia-api --region=us-central1
```

### Deployment Metrics
Monitor in Google Cloud Console:
- **Request count**: Number of requests per second
- **Request latency**: P50, P95, P99 latency
- **Error rate**: Percentage of failed requests
- **Container CPU utilization**: CPU usage
- **Container memory utilization**: Memory usage
- **Container instance count**: Number of running instances

---

## Secrets Management in CI/CD

### GitHub Secrets
Required secrets in GitHub repository settings:

```
WIF_PROVIDER              # Workload Identity Federation provider
WHATSAPP_API_KEY          # WhatsApp Business API key
GEMINI_API_KEY            # Google Gemini API key
GOOGLE_CLIENT_ID          # OAuth 2.0 client ID
GOOGLE_CLIENT_SECRET      # OAuth 2.0 client secret
GOOGLE_REFRESH_TOKEN      # OAuth 2.0 refresh token
WHATSAPP_WEBHOOK_VERIFY_TOKEN  # Webhook verification token
```

### Workload Identity Federation Setup
```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create "github-actions" \
  --project="dev-ai-agents-projects" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="dev-ai-agents-projects" \
  --location="global" \
  --workload-identity-pool="github-actions" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Grant permissions
gcloud iam service-accounts add-iam-policy-binding \
  gcp-terraform@dev-ai-agents-projects.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions/attribute.repository/username/financia"
```

---

## Local Deployment Testing

### Build and Run Locally
```bash
# Build Docker image
docker build -t financia-api:local .

# Run container
docker run -p 8080:8080 \
  -e GCP_PROJECT_ID=dev-ai-agents-projects \
  -e SPREADSHEET_ID=your-spreadsheet-id \
  -e WHATSAPP_WEBHOOK_VERIFY_TOKEN=test-token \
  financia-api:local

# Test health endpoint
curl http://localhost:8080/health
```

### Test with ngrok
```bash
# Install ngrok
brew install ngrok  # macOS
# or download from https://ngrok.com

# Start ngrok tunnel
ngrok http 8080

# Update WhatsApp webhook URL to ngrok URL
# Example: https://abc123.ngrok.io/webhook
```

---

## Performance Optimization

### Cold Start Reduction
```hcl
resource "google_cloud_run_v2_service" "app" {
  template {
    scaling {
      min_instance_count = 1  # Keep 1 instance warm
    }
  }
}
```

### Image Size Optimization
```dockerfile
# Use multi-stage build
FROM python:3.11-slim as builder
WORKDIR /app
RUN pip install uv
COPY pyproject.toml uv.lock ./
RUN uv sync --no-dev

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY app/ ./app/
COPY main.py ./
CMD ["/app/.venv/bin/uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

---

## Troubleshooting Deployments

### Issue: Deployment Fails
```bash
# Check deployment status
gcloud run services describe financia-api --region=us-central1

# View recent logs
gcloud run services logs read financia-api --region=us-central1 --limit=100
```

### Issue: Health Check Fails
```bash
# Test health endpoint locally
curl https://financia-api-xxxxx-uc.a.run.app/health

# Check container logs
gcloud run services logs read financia-api --region=us-central1 | grep "health"
```

### Issue: Terraform Apply Fails
```bash
# Refresh state
terraform refresh

# Target specific resource
terraform apply -target=module.cloud_run
```

---

## Deployment Checklist

Before deploying to production:

- [ ] All tests passing
- [ ] Terraform plan reviewed
- [ ] Secrets updated in Secret Manager
- [ ] Database/Sheets backup created
- [ ] Monitoring alerts configured
- [ ] Rollback plan documented
- [ ] Stakeholders notified
- [ ] Deployment window scheduled
- [ ] Health check endpoint working
- [ ] Smoke tests prepared
