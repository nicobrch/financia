# Initial Setup Commands

**Copy-paste commands for setting up the infrastructure**

## 🚀 Step 1: Run Setup Script

```bash
# Make script executable
chmod +x scripts/setup-workload-identity.sh

# Run the setup script
./scripts/setup-workload-identity.sh
```

**Expected output**: Service account details and Workload Identity Provider resource name

**Save these values** for the next step:
- `WIF_PROVIDER`: Full resource name of Workload Identity Provider
- `WIF_SA_EMAIL_DEV`: `terraform-dev@dev-ai-agents-projects.iam.gserviceaccount.com`
- `WIF_SA_EMAIL_PROD`: `terraform-prod@dev-ai-agents-projects.iam.gserviceaccount.com`

---

## 🔐 Step 2: Add GitHub Secrets

Run these commands to get the values you need:

### Get Workload Identity Provider Resource Name
```bash
gcloud iam workload-identity-pools providers describe github-oidc-provider \
  --project=dev-ai-agents-projects \
  --location=global \
  --workload-identity-pool=github-actions-pool \
  --format="value(name)"
```

### Get Project Number
```bash
gcloud projects describe dev-ai-agents-projects --format="value(projectNumber)"
```

### Generate Webhook Verify Token (if you don't have one)
```bash
openssl rand -hex 32
```

### Add to GitHub
Navigate to: `https://github.com/nicobrch/financia/settings/secrets/actions`

Click "New repository secret" and add each of the following:

| Secret Name | Command to Get Value |
|-------------|---------------------|
| `WIF_PROVIDER` | Output from first command above |
| `WIF_SA_EMAIL_DEV` | `terraform-dev@dev-ai-agents-projects.iam.gserviceaccount.com` |
| `WIF_SA_EMAIL_PROD` | `terraform-prod@dev-ai-agents-projects.iam.gserviceaccount.com` |
| `GCP_PROJECT_ID` | `dev-ai-agents-projects` |
| `GCS_TERRAFORM_STATE_BUCKET` | `dev-ai-agents-projects-terraform-state` |
| `WHATSAPP_API_KEY` | Get from WhatsApp Business Platform |
| `GEMINI_API_KEY` | Get from Google AI Studio |
| `GOOGLE_CLIENT_ID` | Get from GCP Console → APIs & Services → Credentials |
| `GOOGLE_CLIENT_SECRET` | Get from GCP Console → APIs & Services → Credentials |
| `GOOGLE_REFRESH_TOKEN` | Generated during OAuth flow |
| `WHATSAPP_WEBHOOK_VERIFY_TOKEN` | Output from `openssl rand -hex 32` |
| `SPREADSHEET_ID_DEV` | Get from dev Google Sheets URL |
| `SPREADSHEET_ID_PROD` | Get from prod Google Sheets URL |

---

## 🌍 Step 3: Create GitHub Environments

### Create Dev Environment
```bash
# Navigate to: https://github.com/nicobrch/financia/settings/environments
# Click "New environment"
# Name: dev
# Click "Configure environment"
# No protection rules needed (or add reviewers if desired)
# Click "Save protection rules"
```

### Create Prod Environment
```bash
# Click "New environment" again
# Name: prod
# Click "Configure environment"
# Check "Required reviewers" and add yourself
# (Optional) Set "Wait timer" to 5 minutes
# Click "Save protection rules"
```

---

## 🧪 Step 4: Test Locally (Optional)

### Verify Workload Identity
```bash
# Test dev service account
gcloud auth print-access-token \
  --impersonate-service-account=terraform-dev@dev-ai-agents-projects.iam.gserviceaccount.com

# Test prod service account
gcloud auth print-access-token \
  --impersonate-service-account=terraform-prod@dev-ai-agents-projects.iam.gserviceaccount.com
```

### Verify State Bucket
```bash
# Check bucket exists
gsutil ls gs://dev-ai-agents-projects-terraform-state/

# Check versioning is enabled
gsutil versioning get gs://dev-ai-agents-projects-terraform-state/
```

### Initialize Terraform
```bash
cd terraform

# Initialize with dev backend
terraform init -backend-config=environments/dev/backend.hcl

# Validate
terraform validate

# Format check
terraform fmt -check -recursive
```

### Run Terraform Plan (requires secrets as env vars)
```bash
# Set environment variables
export TF_VAR_project_id="dev-ai-agents-projects"
export TF_VAR_whatsapp_api_key="your-whatsapp-key"
export TF_VAR_gemini_api_key="your-gemini-key"
export TF_VAR_google_client_id="your-client-id"
export TF_VAR_google_client_secret="your-client-secret"
export TF_VAR_google_refresh_token="your-refresh-token"
export TF_VAR_spreadsheet_id="your-spreadsheet-id"
export TF_VAR_whatsapp_webhook_verify_token="your-verify-token"

# Plan
terraform plan -var-file=environments/dev/terraform.tfvars
```

---

## 🔄 Step 5: Test GitHub Actions

### Test Terraform Plan on PR
```bash
# Create test branch
git checkout -b test/infrastructure-setup

# Make a change
echo "# Test" >> terraform/README.md

# Commit and push
git add .
git commit -m "test: trigger terraform plan"
git push -u origin test/infrastructure-setup

# Create PR in GitHub UI
# Verify "Terraform Plan (Dev)" workflow runs
# Check PR comment has plan output
```

### Test Terraform Apply (Dev)
```bash
# Navigate to: https://github.com/nicobrch/financia/actions/workflows/terraform-apply-dev.yml
# Click "Run workflow"
# Type "apply" in confirmation input
# Click "Run workflow"
# Monitor execution
```

### Test Terraform Apply (Prod) - CAUTION
```bash
# Navigate to: https://github.com/nicobrch/financia/actions/workflows/terraform-apply-prod.yml
# Click "Run workflow"
# Type "apply-prod" in confirmation input
# Click "Run workflow"
# Approve if reviewers are configured
# Monitor execution
```

---

## ✅ Step 6: Verify Deployment

### Check Cloud Run Services
```bash
# List services
gcloud run services list --region=us-central1

# Get dev service URL
gcloud run services describe financia-api-dev \
  --region=us-central1 \
  --format='value(status.url)'

# Get prod service URL
gcloud run services describe financia-api \
  --region=us-central1 \
  --format='value(status.url)'
```

### Test Health Endpoints
```bash
# Test dev
curl https://financia-api-dev-xxxxx-uc.a.run.app/health

# Test prod
curl https://financia-api-xxxxx-uc.a.run.app/health
```

### Verify Secrets
```bash
# List secrets
gcloud secrets list --project=dev-ai-agents-projects

# Check specific secret exists (dev)
gcloud secrets describe WHATSAPP_API_KEY_DEV --project=dev-ai-agents-projects

# Check specific secret exists (prod)
gcloud secrets describe WHATSAPP_API_KEY_PROD --project=dev-ai-agents-projects
```

---

## 📊 Step 7: Set Up Monitoring

### View Dashboards
```bash
# List dashboards
gcloud monitoring dashboards list --project=dev-ai-agents-projects

# Open in browser (replace DASHBOARD_ID)
echo "https://console.cloud.google.com/monitoring/dashboards/custom/DASHBOARD_ID?project=dev-ai-agents-projects"
```

### List Alert Policies
```bash
gcloud alpha monitoring policies list --project=dev-ai-agents-projects
```

### Update Notification Email
```bash
# Edit terraform/environments/prod/terraform.tfvars
# Set: alert_notification_email = "your-email@example.com"

# Then re-run terraform apply
```

---

## 🔧 Troubleshooting Commands

### Check IAM Permissions
```bash
# Check dev service account permissions
gcloud projects get-iam-policy dev-ai-agents-projects \
  --flatten="bindings[].members" \
  --filter="bindings.members:terraform-dev@dev-ai-agents-projects.iam.gserviceaccount.com"

# Check prod service account permissions
gcloud projects get-iam-policy dev-ai-agents-projects \
  --flatten="bindings[].members" \
  --filter="bindings.members:terraform-prod@dev-ai-agents-projects.iam.gserviceaccount.com"
```

### View Terraform State
```bash
cd terraform

# List resources
terraform state list

# Show specific resource
terraform state show module.cloud_run.google_cloud_run_v2_service.app

# Refresh state
terraform refresh -var-file=environments/dev/terraform.tfvars
```

### View Logs
```bash
# View Cloud Run logs (dev)
gcloud run services logs read financia-api-dev \
  --region=us-central1 \
  --limit=50

# Follow logs in real-time
gcloud run services logs tail financia-api-dev \
  --region=us-central1
```

### Force Unlock Terraform State
```bash
cd terraform
terraform force-unlock <LOCK_ID>
```

---

## 🚨 Emergency Commands

### Rollback Cloud Run Deployment
```bash
# List revisions
gcloud run revisions list \
  --service=financia-api \
  --region=us-central1

# Route traffic to previous revision
gcloud run services update-traffic financia-api \
  --to-revisions=financia-api-00042-abc=100 \
  --region=us-central1
```

### Delete All Resources (DANGER!)
```bash
cd terraform
terraform destroy -var-file=environments/dev/terraform.tfvars
```

---

## 📚 Useful Links

- **GCP Console**: https://console.cloud.google.com/
- **Cloud Run**: https://console.cloud.google.com/run?project=dev-ai-agents-projects
- **Secret Manager**: https://console.cloud.google.com/security/secret-manager?project=dev-ai-agents-projects
- **IAM**: https://console.cloud.google.com/iam-admin/iam?project=dev-ai-agents-projects
- **Monitoring**: https://console.cloud.google.com/monitoring?project=dev-ai-agents-projects
- **Logs**: https://console.cloud.google.com/logs?project=dev-ai-agents-projects
- **Artifact Registry**: https://console.cloud.google.com/artifacts?project=dev-ai-agents-projects

---

**✅ Setup Complete!**

Your infrastructure is now ready for secure, keyless deployments with GitHub Actions and GCP Workload Identity Federation.
