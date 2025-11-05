# Infrastructure Setup Guide

This guide walks you through setting up GitHub OIDC authentication with GCP Workload Identity Federation for secure, keyless deployments.

## 🏗️ Architecture Overview

```
GitHub Actions (OIDC Token)
    ↓
GCP Workload Identity Pool
    ↓
Service Account (terraform-dev / terraform-prod)
    ↓
GCP Resources (Cloud Run, Secret Manager, etc.)
```

### Key Benefits
- ✅ **No JSON keys** - More secure, no credentials to rotate
- ✅ **Granular permissions** - Separate service accounts for dev/prod
- ✅ **Audit trail** - All actions logged and traceable
- ✅ **State versioning** - Terraform state stored in GCS with versioning

## 📋 Prerequisites

1. **GCP Project**: `dev-ai-agents-projects`
2. **gcloud CLI** installed and authenticated
3. **GitHub repository**: `nicobrch/financia`
4. **Permissions**: Project Owner or Workload Identity Pool Admin

## 🚀 Step 1: Run Workload Identity Setup Script

This script creates all the necessary GCP infrastructure:

```bash
# Make script executable
chmod +x scripts/setup-workload-identity.sh

# Run the setup script
./scripts/setup-workload-identity.sh
```

The script will create:
- ✅ Workload Identity Pool and OIDC Provider
- ✅ Service accounts for Terraform (dev and prod)
- ✅ IAM role bindings
- ✅ GCS bucket for Terraform state (with versioning)
- ✅ Artifact Registry repository

**Expected output**: Service account emails and Workload Identity Provider resource names.

## 🔐 Step 2: Configure GitHub Secrets

Navigate to your GitHub repository:
**Settings → Secrets and variables → Actions → New repository secret**

### Infrastructure Secrets (from setup script output)

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `WIF_PROVIDER` | Workload Identity Provider resource name | `projects/123456789/locations/global/workloadIdentityPools/github-actions-pool/providers/github-oidc-provider` |
| `WIF_SA_EMAIL_DEV` | Dev Terraform service account email | `terraform-dev@dev-ai-agents-projects.iam.gserviceaccount.com` |
| `WIF_SA_EMAIL_PROD` | Prod Terraform service account email | `terraform-prod@dev-ai-agents-projects.iam.gserviceaccount.com` |
| `GCP_PROJECT_ID` | GCP Project ID | `dev-ai-agents-projects` |
| `GCS_TERRAFORM_STATE_BUCKET` | Terraform state bucket name | `dev-ai-agents-projects-terraform-state` |

### Application Secrets

| Secret Name | Description | Where to Get |
|------------|-------------|--------------|
| `WHATSAPP_API_KEY` | WhatsApp Business API key | WhatsApp Business Platform |
| `GEMINI_API_KEY` | Google Gemini API key | Google AI Studio |
| `GOOGLE_CLIENT_ID` | OAuth 2.0 client ID | GCP Console → APIs & Services → Credentials |
| `GOOGLE_CLIENT_SECRET` | OAuth 2.0 client secret | GCP Console → APIs & Services → Credentials |
| `GOOGLE_REFRESH_TOKEN` | OAuth 2.0 refresh token | Generated during OAuth flow |
| `WHATSAPP_WEBHOOK_VERIFY_TOKEN` | Webhook verification token | Generate random string (e.g., `openssl rand -hex 32`) |
| `SPREADSHEET_ID_DEV` | Dev Google Sheets ID | From Google Sheets URL |
| `SPREADSHEET_ID_PROD` | Prod Google Sheets ID | From Google Sheets URL |

## 🎯 Step 3: Configure GitHub Environments

GitHub requires environments to be configured for the workflows to run.

**Settings → Environments → New environment**

### Create "dev" Environment
1. Name: `dev`
2. Protection rules: None (optional: add reviewers)
3. Environment secrets: None needed (uses repository secrets)

### Create "prod" Environment
1. Name: `prod`
2. Protection rules:
   - ✅ Required reviewers (add yourself)
   - ✅ Wait timer: 5 minutes (optional)
3. Environment secrets: None needed (uses repository secrets)

## 📦 Step 4: Initialize Terraform Locally (Optional)

Test the setup locally before running in GitHub Actions:

```bash
cd terraform

# Initialize for dev environment
terraform init -backend-config=environments/dev/backend.hcl

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Plan (requires environment variables)
export TF_VAR_project_id="dev-ai-agents-projects"
export TF_VAR_whatsapp_api_key="your-whatsapp-key"
export TF_VAR_gemini_api_key="your-gemini-key"
export TF_VAR_google_client_id="your-client-id"
export TF_VAR_google_client_secret="your-client-secret"
export TF_VAR_google_refresh_token="your-refresh-token"
export TF_VAR_spreadsheet_id="your-spreadsheet-id"
export TF_VAR_whatsapp_webhook_verify_token="your-verify-token"

terraform plan -var-file=environments/dev/terraform.tfvars
```

## 🔄 Step 5: Using the CI/CD Pipeline

### Workflow Overview

1. **Terraform Plan** (Automatic on PR)
   - Triggers on pull requests
   - Runs `terraform plan`
   - Posts plan output as PR comment
   - Validates changes before merge

2. **Terraform Apply** (Manual trigger)
   - Triggered manually from GitHub Actions UI
   - Requires explicit confirmation
   - Runs `terraform apply`
   - Creates deployment summary

### Making Infrastructure Changes

1. **Create a branch**:
   ```bash
   git checkout -b feature/add-cloud-scheduler
   ```

2. **Make changes** to Terraform files:
   ```bash
   # Edit files in terraform/
   vim terraform/main.tf
   ```

3. **Commit and push**:
   ```bash
   git add terraform/
   git commit -m "Add Cloud Scheduler for automated tasks"
   git push origin feature/add-cloud-scheduler
   ```

4. **Create Pull Request**:
   - GitHub Actions will automatically run `terraform plan`
   - Review the plan output in the PR comment
   - Ensure changes match expectations

5. **Merge PR** (after approval):
   ```bash
   # Merge via GitHub UI or:
   git checkout main
   git merge feature/add-cloud-scheduler
   git push origin main
   ```

6. **Manually trigger Terraform Apply**:
   - Go to: **Actions → Terraform Apply (Dev) → Run workflow**
   - Type `apply` in the confirmation input
   - Click "Run workflow"
   - Monitor the deployment

7. **Deploy to Production**:
   - Same process, but use "Terraform Apply (Prod)"
   - Type `apply-prod` for confirmation
   - Requires approval from designated reviewers

## 🧪 Testing the Setup

### Test 1: Verify Workload Identity

```bash
# This should succeed (uses Workload Identity)
gcloud auth print-access-token --impersonate-service-account=terraform-dev@dev-ai-agents-projects.iam.gserviceaccount.com
```

### Test 2: Verify State Bucket

```bash
# List state bucket
gsutil ls gs://dev-ai-agents-projects-terraform-state/

# Check versioning
gsutil versioning get gs://dev-ai-agents-projects-terraform-state/
```

### Test 3: Verify Terraform Init

```bash
cd terraform
terraform init -backend-config=environments/dev/backend.hcl
```

## 🔍 Troubleshooting

### Issue: "Workload Identity Provider not found"

**Solution**: Ensure the provider is created correctly:
```bash
gcloud iam workload-identity-pools providers describe github-oidc-provider \
  --project=dev-ai-agents-projects \
  --location=global \
  --workload-identity-pool=github-actions-pool
```

### Issue: "Permission denied" during Terraform apply

**Solution**: Check service account IAM roles:
```bash
gcloud projects get-iam-policy dev-ai-agents-projects \
  --flatten="bindings[].members" \
  --filter="bindings.members:terraform-dev@dev-ai-agents-projects.iam.gserviceaccount.com"
```

### Issue: GitHub Actions fails with "Failed to authenticate"

**Checklist**:
1. ✅ `WIF_PROVIDER` secret is correct
2. ✅ `WIF_SA_EMAIL_DEV` secret is correct
3. ✅ Service account has `roles/iam.workloadIdentityUser` role
4. ✅ Attribute condition in provider matches your GitHub repo owner

### Issue: Terraform state lock error

**Solution**: Force unlock (use with caution):
```bash
terraform force-unlock LOCK_ID
```

## 🏃 Quick Reference

### Run Terraform Plan (Dev)
```bash
cd terraform
terraform init -backend-config=environments/dev/backend.hcl
terraform plan -var-file=environments/dev/terraform.tfvars
```

### Run Terraform Apply (Dev)
Manual trigger via GitHub Actions UI

### View Terraform State
```bash
terraform show
terraform state list
```

### Import Existing Resource
```bash
terraform import module.cloud_run.google_cloud_run_v2_service.app \
  projects/dev-ai-agents-projects/locations/us-central1/services/financia-api-dev
```

### Destroy Resources (CAUTION!)
```bash
terraform destroy -var-file=environments/dev/terraform.tfvars
```

## 📚 Additional Resources

- [GCP Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terraform State Management](https://developer.hashicorp.com/terraform/language/state)

## 🎓 Best Practices

1. ✅ **Always run `terraform plan` before `apply`**
2. ✅ **Review PR plan output carefully**
3. ✅ **Use separate service accounts for dev/prod**
4. ✅ **Enable state file versioning**
5. ✅ **Test in dev before deploying to prod**
6. ✅ **Use manual approval for production deployments**
7. ✅ **Keep sensitive values in GitHub Secrets**
8. ✅ **Document all infrastructure changes**
9. ✅ **Regularly review IAM permissions**
10. ✅ **Monitor Terraform state file changes**

## 🚨 Emergency Procedures

### Rollback Production Deployment

1. **Identify previous working revision**:
   ```bash
   gcloud run revisions list --service=financia-api --region=us-central1
   ```

2. **Route traffic to previous revision**:
   ```bash
   gcloud run services update-traffic financia-api \
     --to-revisions=financia-api-00042-abc=100 \
     --region=us-central1
   ```

3. **Or revert Terraform changes and redeploy**:
   ```bash
   git revert <commit-hash>
   git push origin main
   # Then manually trigger Terraform Apply (Prod)
   ```

---

**Setup Complete! 🎉**

You now have a secure, keyless CI/CD pipeline for deploying your GCP infrastructure with Terraform.
