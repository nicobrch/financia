# Financia Terraform Infrastructure

This directory contains Infrastructure as Code (IaC) for the Financia application using Terraform and GCP.

## 📂 Structure

```
terraform/
├── main.tf                    # Root module - orchestrates all modules
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── versions.tf                # Terraform and provider versions
├── providers.tf               # Provider configurations
├── environments/
│   ├── dev/
│   │   ├── backend.hcl       # Dev backend configuration
│   │   └── terraform.tfvars  # Dev variable values
│   └── prod/
│       ├── backend.hcl       # Prod backend configuration
│       └── terraform.tfvars  # Prod variable values
└── modules/
    ├── iam/                   # Service accounts and IAM roles
    ├── secret_manager/        # Secret Manager configuration
    ├── cloud_run/             # Cloud Run service
    └── monitoring/            # Logging and alerting
```

## 🚀 Quick Start

### Prerequisites

1. gcloud CLI authenticated
2. Terraform >= 1.5.0 installed
3. Workload Identity Federation configured (see `docs/INFRASTRUCTURE_SETUP.md`)

### Initialize Terraform (Dev)

```bash
cd terraform
terraform init -backend-config=environments/dev/backend.hcl
```

### Plan Changes

```bash
terraform plan -var-file=environments/dev/terraform.tfvars \
  -var="project_id=dev-ai-agents-projects" \
  -var="whatsapp_api_key=$WHATSAPP_API_KEY" \
  -var="gemini_api_key=$GEMINI_API_KEY" \
  -var="google_client_id=$GOOGLE_CLIENT_ID" \
  -var="google_client_secret=$GOOGLE_CLIENT_SECRET" \
  -var="google_refresh_token=$GOOGLE_REFRESH_TOKEN" \
  -var="spreadsheet_id=$SPREADSHEET_ID" \
  -var="whatsapp_webhook_verify_token=$WEBHOOK_TOKEN"
```

### Apply Changes (CAUTION!)

**Recommended**: Use GitHub Actions workflow instead

```bash
terraform apply -var-file=environments/dev/terraform.tfvars [... same vars as plan]
```

## 🏗️ Architecture

### Resources Managed

- **IAM**: Service accounts with granular permissions
- **Secret Manager**: Secure storage for API keys and credentials
- **Cloud Run**: Serverless application hosting
- **Monitoring**: Alerts, dashboards, and log sinks

### Multi-Environment Strategy

- **Dev**: Testing environment with minimal resources
- **Prod**: Production environment with high availability

Each environment has:
- Separate Terraform state file
- Dedicated service account
- Environment-specific configurations
- Isolated resources

## 📝 Module Documentation

### IAM Module

**Purpose**: Creates and manages service accounts

**Resources**:
- Application service account
- IAM role bindings (Secret Manager, Logging, Monitoring)

**Inputs**:
- `project_id`: GCP project ID
- `app_name`: Application name
- `environment`: Environment (dev/prod)

**Outputs**:
- `app_service_account_email`: Service account email

### Secret Manager Module

**Purpose**: Stores application secrets securely

**Resources**:
- Secret Manager secrets
- Secret versions
- IAM bindings for service account access

**Inputs**:
- `secrets`: Map of secret name → secret value
- `service_account_email`: SA that needs access

**Outputs**:
- `secret_ids`: Map of secret names to resource IDs

### Cloud Run Module

**Purpose**: Deploys and configures Cloud Run service

**Resources**:
- Cloud Run v2 service
- IAM binding for public access
- Health checks and probes

**Inputs**:
- `service_name`: Name of the service
- `image`: Container image URL
- `environment_variables`: Non-sensitive env vars
- `secret_environment_variables`: Secret references

**Outputs**:
- `service_url`: Public URL of the service
- `service_name`: Name of the deployed service

### Monitoring Module

**Purpose**: Sets up logging, alerting, and dashboards

**Resources**:
- Log sinks (prod only)
- Notification channels
- Alert policies (error rate, latency, downtime)
- Monitoring dashboard

**Inputs**:
- `service_name`: Service to monitor
- `notification_email`: Email for alerts

**Outputs**:
- `dashboard_url`: URL to monitoring dashboard

## 🔐 Security

### Sensitive Variables

**Never commit these to Git**:
- API keys
- OAuth credentials
- Tokens
- Spreadsheet IDs

**How to pass securely**:
1. **GitHub Actions**: Via GitHub Secrets
2. **Local development**: Via environment variables or `.tfvars` (gitignored)

### IAM Best Practices

- ✅ Separate service accounts per environment
- ✅ Least privilege permissions
- ✅ No JSON key files (use Workload Identity)
- ✅ Audit logs enabled

## 🧪 Testing

### Validate Configuration

```bash
terraform validate
```

### Format Code

```bash
terraform fmt -recursive
```

### Check for Drift

```bash
terraform plan -refresh-only
```

## 🔄 State Management

### Backend: GCS

- **Bucket**: `dev-ai-agents-projects-terraform-state`
- **Versioning**: Enabled
- **Encryption**: Google-managed

### State Files

- Dev: `terraform/state/dev/default.tfstate`
- Prod: `terraform/state/prod/default.tfstate`

### State Commands

```bash
# List resources
terraform state list

# Show resource
terraform state show module.cloud_run.google_cloud_run_v2_service.app

# Move resource
terraform state mv <old> <new>

# Remove resource from state (doesn't delete resource)
terraform state rm <resource>
```

## 📊 Outputs

After `terraform apply`, view outputs:

```bash
# All outputs
terraform output

# Specific output
terraform output service_url

# JSON format
terraform output -json
```

## 🚨 Emergency Procedures

### Force Unlock State

```bash
terraform force-unlock <LOCK_ID>
```

### Import Existing Resource

```bash
terraform import <resource_address> <resource_id>

# Example
terraform import module.cloud_run.google_cloud_run_v2_service.app \
  projects/dev-ai-agents-projects/locations/us-central1/services/financia-api-dev
```

### Refresh State

```bash
terraform refresh -var-file=environments/dev/terraform.tfvars
```

## 📚 Additional Resources

- [Full Setup Guide](../docs/INFRASTRUCTURE_SETUP.md)
- [Terraform GCP Provider Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloud Run Terraform Resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service)

## ⚠️ Important Notes

1. **Always run `terraform plan` before `apply`**
2. **Use GitHub Actions for production deployments**
3. **Review changes carefully in PR comments**
4. **Keep state file backups (GCS versioning)**
5. **Test changes in dev before prod**

## 🤝 Contributing

When making infrastructure changes:

1. Create a feature branch
2. Make changes to Terraform files
3. Run `terraform fmt` and `terraform validate`
4. Create a PR (triggers `terraform plan`)
5. Review plan output
6. After PR approval, manually trigger apply workflow

---

For complete setup instructions, see [docs/INFRASTRUCTURE_SETUP.md](../docs/INFRASTRUCTURE_SETUP.md)
