# Multi-Project Setup Guide

## Overview
The production environment now uses a separate GCP project: **prod-ai-agents-projects**.

This provides better isolation between development and production environments.

## Project Structure

### Development Environment
- **Project ID**: `dev-ai-agents-projects`
- **Service Account**: `terraform-dev@dev-ai-agents-projects.iam.gserviceaccount.com`
- **State Bucket**: `dev-ai-agents-projects-terraform-state`
- **Artifact Registry**: `us-central1-docker.pkg.dev/dev-ai-agents-projects/financia`
- **Cloud Run Service**: `financia-api-dev`

### Production Environment
- **Project ID**: `prod-ai-agents-projects`
- **Service Account**: `terraform-prod@prod-ai-agents-projects.iam.gserviceaccount.com`
- **State Bucket**: `prod-ai-agents-projects-terraform-state`
- **Artifact Registry**: `us-central1-docker.pkg.dev/prod-ai-agents-projects/financia`
- **Cloud Run Service**: `financia-api`

## Setup Instructions

### 1. Run the Setup Script

The setup script will create resources in both projects:

**PowerShell (Windows)**:
```powershell
.\scripts\setup-workload-identity.ps1
```

**Bash (Linux/Mac)**:
```bash
chmod +x scripts/setup-workload-identity.sh
./scripts/setup-workload-identity.sh
```

This script will:
- Create Workload Identity Pool and Provider in the **dev** project (used for GitHub OIDC)
- Create service accounts in **both** dev and prod projects
- Grant IAM permissions in **both** projects
- Create state buckets in **both** projects
- Create Artifact Registry repositories in **both** projects

### 2. Configure GitHub Secrets

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

#### Workload Identity Secrets (Global)
```
WIF_PROVIDER=projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-oidc-provider
WIF_SA_EMAIL_DEV=terraform-dev@dev-ai-agents-projects.iam.gserviceaccount.com
WIF_SA_EMAIL_PROD=terraform-prod@prod-ai-agents-projects.iam.gserviceaccount.com
```

#### Development Environment Secrets
```
GCP_PROJECT_ID_DEV=dev-ai-agents-projects
WHATSAPP_API_KEY_DEV=your-dev-key
GEMINI_API_KEY_DEV=your-dev-key
GOOGLE_CLIENT_ID_DEV=your-dev-client-id
GOOGLE_CLIENT_SECRET_DEV=your-dev-client-secret
GOOGLE_REFRESH_TOKEN_DEV=your-dev-refresh-token
SPREADSHEET_ID_DEV=your-dev-spreadsheet-id
WHATSAPP_WEBHOOK_VERIFY_TOKEN_DEV=your-dev-verify-token
```

#### Production Environment Secrets
```
GCP_PROJECT_ID_PROD=prod-ai-agents-projects
WHATSAPP_API_KEY_PROD=your-prod-key
GEMINI_API_KEY_PROD=your-prod-key
GOOGLE_CLIENT_ID_PROD=your-prod-client-id
GOOGLE_CLIENT_SECRET_PROD=your-prod-client-secret
GOOGLE_REFRESH_TOKEN_PROD=your-prod-refresh-token
SPREADSHEET_ID_PROD=your-prod-spreadsheet-id
WHATSAPP_WEBHOOK_VERIFY_TOKEN_PROD=your-prod-verify-token
```

### 3. Create GitHub Environments

Create two environments in your GitHub repository (Settings → Environments):

#### Dev Environment
- Name: `dev`
- Protection rules: None (automatic deployment)

#### Prod Environment
- Name: `prod`
- Protection rules:
  - ✅ Required reviewers (add yourself or team members)
  - ✅ Wait timer: 0 minutes
  - Environment secrets: (add prod-specific secrets here if needed)

### 4. Deploy to Environments

#### Deploy to Dev
1. Create a PR with Terraform changes
2. Terraform plan will run automatically for both dev and prod
3. Review the plan output in PR comments
4. Merge the PR
5. Manually trigger "Terraform Apply (Dev)" workflow
6. Type "apply-dev" to confirm

#### Deploy to Prod
1. After successful dev deployment
2. Manually trigger "Terraform Apply (Prod)" workflow
3. Type "apply-prod" to confirm
4. Reviewers must approve the deployment
5. Terraform will apply changes to prod project

## Key Differences from Single-Project Setup

### Before (Single Project)
- Both dev and prod used `dev-ai-agents-projects`
- Shared state bucket
- Shared Artifact Registry
- Environments differentiated by service name only

### After (Multi-Project)
- Dev uses `dev-ai-agents-projects`
- Prod uses `prod-ai-agents-projects`
- Separate state buckets per project
- Separate Artifact Registries per project
- Complete isolation between environments

## Benefits

1. **Security Isolation**: Production resources are completely isolated from dev
2. **Billing Separation**: Costs are tracked separately per environment
3. **IAM Isolation**: Different service accounts and permissions per project
4. **State Separation**: Terraform state is isolated, preventing cross-environment issues
5. **Blast Radius**: Dev issues can't affect prod infrastructure

## Troubleshooting

### Error: Permission Denied in Prod Project
**Solution**: Ensure you have Owner/Editor role in the prod project before running setup script.

### Error: State Bucket Not Found
**Solution**: Run the setup script again - it will create the missing bucket.

### Error: Service Account Not Found
**Solution**: Check that the service account exists in the correct project:
```bash
# Dev project
gcloud iam service-accounts describe terraform-dev@dev-ai-agents-projects.iam.gserviceaccount.com --project=dev-ai-agents-projects

# Prod project
gcloud iam service-accounts describe terraform-prod@prod-ai-agents-projects.iam.gserviceaccount.com --project=prod-ai-agents-projects
```

### Workflow Fails with "Context access might be invalid"
This is a linter warning in VS Code - the secrets need to be added to GitHub before the workflow will work. The workflow will run successfully once secrets are configured.

## Migration from Single-Project Setup

If you previously had both environments in `dev-ai-agents-projects`:

1. **Backup current state**: Download current Terraform state files
2. **Run setup script**: Creates resources in prod project
3. **Import existing resources** (if needed):
   ```bash
   cd terraform
   terraform init -backend-config=environments/prod/backend.hcl
   terraform import module.cloud_run.google_cloud_run_v2_service.app projects/prod-ai-agents-projects/locations/us-central1/services/financia-api
   ```
4. **Update GitHub secrets**: Add prod-specific secrets with `_PROD` suffix
5. **Test workflows**: Trigger a plan to verify everything works

## Verification Checklist

After setup, verify:

- [ ] Dev service account exists in dev project
- [ ] Prod service account exists in prod project
- [ ] Dev state bucket exists in dev project
- [ ] Prod state bucket exists in prod project
- [ ] Dev Artifact Registry exists in dev project
- [ ] Prod Artifact Registry exists in prod project
- [ ] Workload Identity bindings are correct
- [ ] GitHub secrets are configured
- [ ] GitHub environments are created
- [ ] Terraform plan works for both environments
- [ ] Can deploy to dev successfully
- [ ] Can deploy to prod successfully (with approval)

## Cost Considerations

Running two projects will incur costs in both:
- Cloud Run: Charged per request and compute time
- State Storage: Minimal cost (< $0.01/month per bucket)
- Artifact Registry: Storage costs for Docker images
- Secret Manager: Minimal cost for secrets

Use Cloud Run's free tier wisely:
- Dev: Keep min_instances = 0
- Prod: Keep min_instances = 1 for better UX

## Next Steps

1. Run `.\scripts\setup-workload-identity.ps1`
2. Add GitHub secrets
3. Create GitHub environments
4. Test Terraform plan on a PR
5. Deploy to dev
6. Deploy to prod

For detailed step-by-step instructions, see `docs/INFRASTRUCTURE_SETUP.md`.
