# Infrastructure Setup Checklist

Use this checklist to ensure all steps are completed for the GitHub OIDC + GCP Workload Identity Federation setup.

## 📋 Pre-Setup

- [ ] GCP Project ID: `dev-ai-agents-projects`
- [ ] GitHub Repository: `nicobrch/financia`
- [ ] gcloud CLI installed and authenticated
- [ ] Terraform >= 1.5.0 installed
- [ ] Project Owner or Workload Identity Admin permissions

## 🏗️ Infrastructure Setup

### 1. Run Workload Identity Setup Script

- [ ] Make script executable: `chmod +x scripts/setup-workload-identity.sh`
- [ ] Run script: `./scripts/setup-workload-identity.sh`
- [ ] Verify no errors in output
- [ ] Copy Workload Identity Provider resource name
- [ ] Copy service account emails (dev and prod)
- [ ] Copy GCS state bucket name

### 2. Verify GCP Resources Created

- [ ] Workload Identity Pool exists
  ```bash
  gcloud iam workload-identity-pools describe github-actions-pool \
    --project=dev-ai-agents-projects \
    --location=global
  ```

- [ ] Workload Identity Provider exists
  ```bash
  gcloud iam workload-identity-pools providers describe github-oidc-provider \
    --project=dev-ai-agents-projects \
    --location=global \
    --workload-identity-pool=github-actions-pool
  ```

- [ ] Terraform service accounts exist
  ```bash
  gcloud iam service-accounts list --project=dev-ai-agents-projects | grep terraform
  ```

- [ ] GCS state bucket exists with versioning
  ```bash
  gsutil ls gs://dev-ai-agents-projects-terraform-state/
  gsutil versioning get gs://dev-ai-agents-projects-terraform-state/
  ```

- [ ] Artifact Registry repository exists
  ```bash
  gcloud artifacts repositories list --project=dev-ai-agents-projects --location=us-central1
  ```

## 🔐 GitHub Configuration

### 3. Add Infrastructure Secrets

Navigate to: **GitHub Repository → Settings → Secrets and variables → Actions → New repository secret**

- [ ] `WIF_PROVIDER` - Workload Identity Provider resource name
- [ ] `WIF_SA_EMAIL_DEV` - `terraform-dev@dev-ai-agents-projects.iam.gserviceaccount.com`
- [ ] `WIF_SA_EMAIL_PROD` - `terraform-prod@dev-ai-agents-projects.iam.gserviceaccount.com`
- [ ] `GCP_PROJECT_ID` - `dev-ai-agents-projects`
- [ ] `GCS_TERRAFORM_STATE_BUCKET` - `dev-ai-agents-projects-terraform-state`

### 4. Add Application Secrets

- [ ] `WHATSAPP_API_KEY` - WhatsApp Business API key
- [ ] `GEMINI_API_KEY` - Google Gemini API key
- [ ] `GOOGLE_CLIENT_ID` - OAuth 2.0 client ID
- [ ] `GOOGLE_CLIENT_SECRET` - OAuth 2.0 client secret
- [ ] `GOOGLE_REFRESH_TOKEN` - OAuth 2.0 refresh token
- [ ] `WHATSAPP_WEBHOOK_VERIFY_TOKEN` - Webhook verification token
- [ ] `SPREADSHEET_ID_DEV` - Dev Google Sheets spreadsheet ID
- [ ] `SPREADSHEET_ID_PROD` - Prod Google Sheets spreadsheet ID

### 5. Configure GitHub Environments

Navigate to: **GitHub Repository → Settings → Environments**

**Dev Environment:**
- [ ] Create environment named `dev`
- [ ] No protection rules required (optional: add reviewers)
- [ ] Verify environment is active

**Prod Environment:**
- [ ] Create environment named `prod`
- [ ] Add required reviewers (yourself + optional team members)
- [ ] (Optional) Add wait timer: 5 minutes
- [ ] Verify environment is active

## 🧪 Testing

### 6. Test Workload Identity (Local)

- [ ] Impersonate dev service account
  ```bash
  gcloud auth print-access-token \
    --impersonate-service-account=terraform-dev@dev-ai-agents-projects.iam.gserviceaccount.com
  ```

- [ ] Impersonate prod service account
  ```bash
  gcloud auth print-access-token \
    --impersonate-service-account=terraform-prod@dev-ai-agents-projects.iam.gserviceaccount.com
  ```

### 7. Test Terraform Locally (Optional)

- [ ] Navigate to terraform directory: `cd terraform`
- [ ] Initialize Terraform
  ```bash
  terraform init -backend-config=environments/dev/backend.hcl
  ```
- [ ] Validate configuration: `terraform validate`
- [ ] Format check: `terraform fmt -check -recursive`
- [ ] Run plan (requires env vars) - see `terraform/README.md`

### 8. Test GitHub Actions Workflows

**Test Terraform Plan:**
- [ ] Create a test branch: `git checkout -b test/infrastructure-setup`
- [ ] Make a small change to `terraform/README.md`
- [ ] Commit and push: `git add . && git commit -m "test: trigger terraform plan" && git push`
- [ ] Create Pull Request
- [ ] Verify "Terraform Plan (Dev)" workflow runs
- [ ] Check PR comment has terraform plan output
- [ ] Verify no errors

**Test Terraform Apply (Dev):**
- [ ] Navigate to **Actions → Terraform Apply (Dev)**
- [ ] Click "Run workflow"
- [ ] Type `apply` in confirmation input
- [ ] Click "Run workflow"
- [ ] Monitor execution
- [ ] Verify completion and check outputs
- [ ] Visit service URL from outputs

**Test Terraform Apply (Prod) - CAUTION:**
- [ ] Navigate to **Actions → Terraform Apply (Prod)**
- [ ] Click "Run workflow"
- [ ] Type `apply-prod` in confirmation input
- [ ] Click "Run workflow"
- [ ] Approve deployment (if reviewers configured)
- [ ] Monitor execution
- [ ] Verify smoke tests pass
- [ ] Visit production service URL

## 📊 Verification

### 9. Verify Deployed Resources

**Cloud Run (Dev):**
- [ ] Service exists
  ```bash
  gcloud run services describe financia-api-dev --region=us-central1
  ```
- [ ] Service is accessible
  ```bash
  SERVICE_URL=$(gcloud run services describe financia-api-dev --region=us-central1 --format='value(status.url)')
  curl $SERVICE_URL/health
  ```

**Cloud Run (Prod):**
- [ ] Service exists
  ```bash
  gcloud run services describe financia-api --region=us-central1
  ```
- [ ] Service is accessible
  ```bash
  SERVICE_URL=$(gcloud run services describe financia-api --region=us-central1 --format='value(status.url)')
  curl $SERVICE_URL/health
  ```

**Secret Manager:**
- [ ] Secrets exist
  ```bash
  gcloud secrets list --project=dev-ai-agents-projects | grep -E "WHATSAPP|GEMINI|GOOGLE"
  ```

**Monitoring:**
- [ ] Alert policies exist
  ```bash
  gcloud alpha monitoring policies list --project=dev-ai-agents-projects
  ```
- [ ] Dashboards exist in [Cloud Console](https://console.cloud.google.com/monitoring/dashboards)

## 📝 Documentation

### 10. Update Project Documentation

- [ ] Review and update `terraform/environments/prod/terraform.tfvars`
  - Update `alert_notification_email` with your email
  - Update `container_image` tag when deploying new versions

- [ ] Document any custom configuration in project notes

- [ ] Save Workload Identity Provider resource name for reference

- [ ] Bookmark monitoring dashboards

## 🎯 Post-Setup Tasks

### 11. Configure WhatsApp Webhook

- [ ] Get Cloud Run service URL from Terraform outputs
- [ ] Configure WhatsApp webhook URL: `https://your-service-url.run.app/webhook`
- [ ] Set webhook verify token to match `WHATSAPP_WEBHOOK_VERIFY_TOKEN`

### 12. Set Up Monitoring Alerts

- [ ] Verify alert notification email is correct
- [ ] Test alert by triggering an error (e.g., invalid API call)
- [ ] Confirm email notifications are received

### 13. Enable Continuous Deployment (Optional)

If you want to auto-deploy on merge to main:
- [ ] Modify `.github/workflows/terraform-apply-dev.yml` to trigger on push to `develop`
- [ ] Modify `.github/workflows/terraform-apply-prod.yml` to trigger on push to `main`
- [ ] Add auto-confirmation (remove manual input)
- [ ] **CAUTION**: Only do this after thorough testing!

## ✅ Final Checklist

- [ ] All GitHub secrets added
- [ ] Both environments (dev/prod) configured
- [ ] Workload Identity Federation working
- [ ] Terraform plan runs successfully on PRs
- [ ] Terraform apply works for dev
- [ ] Terraform apply works for prod (with approval)
- [ ] Cloud Run services are accessible
- [ ] Health endpoints return 200 OK
- [ ] WhatsApp webhook configured
- [ ] Monitoring alerts configured
- [ ] Documentation reviewed

## 🎉 Success Criteria

You're done when:
1. ✅ PR triggers `terraform plan` automatically
2. ✅ Plan output appears in PR comments
3. ✅ Manual workflow triggers `terraform apply`
4. ✅ Dev deployment completes successfully
5. ✅ Prod deployment requires approval and completes successfully
6. ✅ Services are accessible at their URLs
7. ✅ No JSON keys or credentials stored in Git

---

**🎊 Congratulations!** Your infrastructure is now fully set up with secure, keyless deployments using GitHub OIDC and GCP Workload Identity Federation.

For troubleshooting, see [docs/INFRASTRUCTURE_SETUP.md](./INFRASTRUCTURE_SETUP.md)
