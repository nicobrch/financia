#
# Setup Script for GitHub OIDC -> GCP Workload Identity Federation
# This script creates the necessary infrastructure for keyless authentication
# between GitHub Actions and Google Cloud Platform.
#
# Prerequisites:
# - gcloud CLI installed and authenticated
# - Project Owner or Workload Identity Pool Admin role
# - GitHub repository name
#

$ErrorActionPreference = "Stop"

# Configuration
$DEV_PROJECT_ID = "dev-ai-agents-projects"
$PROD_PROJECT_ID = "prod-ai-agents-projects"
$PROJECT_ID = $DEV_PROJECT_ID  # Default to dev for WIF setup
$PROJECT_NUMBER = gcloud projects describe $PROJECT_ID --format="value(projectNumber)"
$POOL_NAME = "github-actions-pool"
$PROVIDER_NAME = "github-oidc-provider"
$GITHUB_REPO = "nicobrch/financia"  # Change to your repo: owner/repo
$LOCATION = "global"

Write-Host "========================================"
Write-Host "Setting up Workload Identity Federation"
Write-Host "========================================"
Write-Host "Project ID: $PROJECT_ID"
Write-Host "Project Number: $PROJECT_NUMBER"
Write-Host "GitHub Repo: $GITHUB_REPO"
Write-Host ""

# Enable required APIs
Write-Host "1. Enabling required APIs..."
gcloud services enable iamcredentials.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudresourcemanager.googleapis.com --project=$PROJECT_ID
gcloud services enable sts.googleapis.com --project=$PROJECT_ID
gcloud services enable artifactregistry.googleapis.com --project=$PROJECT_ID

Write-Host "APIs enabled for Dev project"

# Enable APIs for Prod project if it exists
$ErrorActionPreference = "Continue"
$prodProjectCheck = gcloud projects describe $PROD_PROJECT_ID 2>&1
$prodProjectExists = $LASTEXITCODE -eq 0
$ErrorActionPreference = "Stop"

if ($prodProjectExists) {
    gcloud services enable artifactregistry.googleapis.com --project=$PROD_PROJECT_ID
    Write-Host "APIs enabled for Prod project"
} else {
    Write-Host "Prod project does not exist - skipping API enablement"
}
Write-Host ""

# Create Workload Identity Pool
Write-Host "2. Creating Workload Identity Pool..."
$ErrorActionPreference = "Continue"
$poolCheck = gcloud iam workload-identity-pools describe $POOL_NAME --location=$LOCATION --project=$PROJECT_ID --format="value(name)" 2>&1
$poolExists = $LASTEXITCODE -eq 0
$ErrorActionPreference = "Stop"

if (-not $poolExists) {
    gcloud iam workload-identity-pools create $POOL_NAME `
        --project=$PROJECT_ID `
        --location=$LOCATION `
        --display-name="GitHub Actions Pool" `
        --description="Workload Identity Pool for GitHub Actions OIDC authentication"
    Write-Host "Workload Identity Pool created"
} else {
    Write-Host "Workload Identity Pool already exists"
}
Write-Host ""

# Create Workload Identity Provider
Write-Host "3. Creating OIDC Provider for GitHub..."
$ErrorActionPreference = "Continue"
$providerCheck = gcloud iam workload-identity-pools providers describe $PROVIDER_NAME --location=$LOCATION --workload-identity-pool=$POOL_NAME --project=$PROJECT_ID --format="value(name)" 2>&1
$providerExists = $LASTEXITCODE -eq 0
$ErrorActionPreference = "Stop"

if (-not $providerExists) {
    gcloud iam workload-identity-pools providers create-oidc $PROVIDER_NAME `
        --project=$PROJECT_ID `
        --location=$LOCATION `
        --workload-identity-pool=$POOL_NAME `
        --display-name="GitHub OIDC Provider" `
        --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" `
        --attribute-condition="assertion.repository_owner=='nicobrch'" `
        --issuer-uri="https://token.actions.githubusercontent.com"
    Write-Host "OIDC Provider created"
} else {
    Write-Host "OIDC Provider already exists"
}
Write-Host ""

# Get Workload Identity Provider resource name
$WI_PROVIDER = "projects/$PROJECT_NUMBER/locations/$LOCATION/workloadIdentityPools/$POOL_NAME/providers/$PROVIDER_NAME"

Write-Host "4. Creating service accounts..."

# Create Terraform service account for dev
$TERRAFORM_SA_DEV = "terraform-dev@$PROJECT_ID.iam.gserviceaccount.com"
$ErrorActionPreference = "Continue"
$devSaCheck = gcloud iam service-accounts describe $TERRAFORM_SA_DEV --project=$PROJECT_ID 2>&1
$devSaExists = $LASTEXITCODE -eq 0
$ErrorActionPreference = "Stop"

if (-not $devSaExists) {
    gcloud iam service-accounts create terraform-dev `
        --project=$PROJECT_ID `
        --display-name="Terraform Service Account (Dev)" `
        --description="Service account for Terraform to manage dev environment"
    Write-Host "Terraform Dev SA created"
} else {
    Write-Host "Terraform Dev SA already exists"
}

# Create Terraform service account for prod (in prod project)
$TERRAFORM_SA_PROD = "terraform-prod@$PROD_PROJECT_ID.iam.gserviceaccount.com"
$ErrorActionPreference = "Continue"
$prodSaCheck = gcloud iam service-accounts describe $TERRAFORM_SA_PROD --project=$PROD_PROJECT_ID 2>&1
$prodSaExists = $LASTEXITCODE -eq 0
$ErrorActionPreference = "Stop"

if (-not $prodSaExists) {
    gcloud iam service-accounts create terraform-prod `
        --project=$PROD_PROJECT_ID `
        --display-name="Terraform Service Account (Prod)" `
        --description="Service account for Terraform to manage prod environment"
    Write-Host "Terraform Prod SA created"
} else {
    Write-Host "Terraform Prod SA already exists"
}
Write-Host ""

# Grant IAM permissions to Terraform Dev SA
Write-Host "5. Granting IAM permissions to Terraform Dev SA..."
$roles = @(
    "roles/run.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/secretmanager.admin",
    "roles/storage.admin",
    "roles/logging.admin",
    "roles/monitoring.admin",
    "roles/cloudscheduler.admin",
    "roles/artifactregistry.admin"
)

foreach ($role in $roles) {
    gcloud projects add-iam-policy-binding $PROJECT_ID `
        --member="serviceAccount:$TERRAFORM_SA_DEV" `
        --role="$role" `
        --condition=None `
        --quiet
}
Write-Host "Permissions granted to Dev SA"
Write-Host ""

# Grant IAM permissions to Terraform Prod SA (in prod project)
Write-Host "6. Granting IAM permissions to Terraform Prod SA..."
$ErrorActionPreference = "Continue"
$prodProjectCheck = gcloud projects describe $PROD_PROJECT_ID 2>&1
$prodProjectExists = $LASTEXITCODE -eq 0
$ErrorActionPreference = "Stop"

if ($prodProjectExists) {
    foreach ($role in $roles) {
        gcloud projects add-iam-policy-binding $PROD_PROJECT_ID `
            --member="serviceAccount:$TERRAFORM_SA_PROD" `
            --role="$role" `
            --condition=None `
            --quiet
    }
    Write-Host "Permissions granted to Prod SA"
} else {
    Write-Host "Prod project does not exist yet - skipping Prod SA permissions"
}
Write-Host ""

# Allow GitHub Actions (dev environment) to impersonate Terraform Dev SA
Write-Host "7. Binding Workload Identity to Terraform Dev SA (dev environment)..."
gcloud iam service-accounts add-iam-policy-binding $TERRAFORM_SA_DEV `
    --project=$PROJECT_ID `
    --role="roles/iam.workloadIdentityUser" `
    --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/$LOCATION/workloadIdentityPools/$POOL_NAME/attribute.repository/$GITHUB_REPO"
Write-Host "Dev SA bound to GitHub Actions"
Write-Host ""

# Allow GitHub Actions (prod environment) to impersonate Terraform Prod SA (in prod project)
Write-Host "8. Binding Workload Identity to Terraform Prod SA (prod environment)..."
if ($prodSaExists) {
    gcloud iam service-accounts add-iam-policy-binding $TERRAFORM_SA_PROD `
        --project=$PROD_PROJECT_ID `
        --role="roles/iam.workloadIdentityUser" `
        --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/$LOCATION/workloadIdentityPools/$POOL_NAME/attribute.repository/$GITHUB_REPO"
    Write-Host "Prod SA bound to GitHub Actions"
} else {
    Write-Host "Prod SA does not exist - skipping binding"
}
Write-Host ""

# Create GCS buckets for Terraform state (one per project)
Write-Host "9. Creating GCS buckets for Terraform state..."

# Dev state bucket
$STATE_BUCKET_DEV = "$DEV_PROJECT_ID-terraform-state"
$ErrorActionPreference = "Continue"
$devBucketCheck = gcloud storage buckets describe "gs://$STATE_BUCKET_DEV" 2>&1
$devBucketExists = $LASTEXITCODE -eq 0
$ErrorActionPreference = "Stop"

if (-not $devBucketExists) {
    gcloud storage buckets create "gs://$STATE_BUCKET_DEV" `
        --project=$DEV_PROJECT_ID `
        --location=us-central1 `
        --uniform-bucket-level-access
    gcloud storage buckets update "gs://$STATE_BUCKET_DEV" --versioning
    Write-Host "Dev state bucket created with versioning enabled"
} else {
    Write-Host "Dev state bucket already exists"
}

# Prod state bucket
$STATE_BUCKET_PROD = "$PROD_PROJECT_ID-terraform-state"
if ($prodProjectExists) {
    $ErrorActionPreference = "Continue"
    $prodBucketCheck = gcloud storage buckets describe "gs://$STATE_BUCKET_PROD" 2>&1
    $prodBucketExists = $LASTEXITCODE -eq 0
    $ErrorActionPreference = "Stop"

    if (-not $prodBucketExists) {
        gcloud storage buckets create "gs://$STATE_BUCKET_PROD" `
            --project=$PROD_PROJECT_ID `
            --location=us-central1 `
            --uniform-bucket-level-access
        gcloud storage buckets update "gs://$STATE_BUCKET_PROD" --versioning
        Write-Host "Prod state bucket created with versioning enabled"
    } else {
        Write-Host "Prod state bucket already exists"
    }
} else {
    Write-Host "Prod project does not exist - skipping Prod state bucket"
}

# Grant Terraform SAs access to their respective state buckets
gcloud storage buckets add-iam-policy-binding "gs://$STATE_BUCKET_DEV" `
    --member="serviceAccount:$TERRAFORM_SA_DEV" `
    --role="roles/storage.objectAdmin"
if ($prodProjectExists -and $prodBucketExists) {
    gcloud storage buckets add-iam-policy-binding "gs://$STATE_BUCKET_PROD" `
        --member="serviceAccount:$TERRAFORM_SA_PROD" `
        --role="roles/storage.objectAdmin"
}
Write-Host "Terraform SAs granted access to state buckets"
Write-Host ""

# Create Artifact Registry repositories for Docker images (one per project)
Write-Host "10. Creating Artifact Registry repositories..."

# Dev Artifact Registry
$ARTIFACT_REPO = "financia"
$ErrorActionPreference = "Continue"
$devRepoCheck = gcloud artifacts repositories describe $ARTIFACT_REPO --project=$DEV_PROJECT_ID --location=us-central1 2>&1
$devRepoExists = $LASTEXITCODE -eq 0
$ErrorActionPreference = "Stop"

if (-not $devRepoExists) {
    gcloud artifacts repositories create $ARTIFACT_REPO `
        --project=$DEV_PROJECT_ID `
        --repository-format=docker `
        --location=us-central1 `
        --description="Docker images for Financia application (Dev)"
    Write-Host "Dev Artifact Registry repository created"
} else {
    Write-Host "Dev Artifact Registry repository already exists"
}

# Prod Artifact Registry
if ($prodProjectExists) {
    $ErrorActionPreference = "Continue"
    $prodRepoCheck = gcloud artifacts repositories describe $ARTIFACT_REPO --project=$PROD_PROJECT_ID --location=us-central1 2>&1
    $prodRepoExists = $LASTEXITCODE -eq 0
    $ErrorActionPreference = "Stop"

    if (-not $prodRepoExists) {
        gcloud artifacts repositories create $ARTIFACT_REPO `
            --project=$PROD_PROJECT_ID `
            --repository-format=docker `
            --location=us-central1 `
            --description="Docker images for Financia application (Prod)"
        Write-Host "Prod Artifact Registry repository created"
    } else {
        Write-Host "Prod Artifact Registry repository already exists"
    }
} else {
    Write-Host "Prod project does not exist - skipping Prod Artifact Registry"
}

# Grant Terraform SAs access to their respective Artifact Registries
gcloud artifacts repositories add-iam-policy-binding $ARTIFACT_REPO `
    --project=$DEV_PROJECT_ID `
    --location=us-central1 `
    --member="serviceAccount:$TERRAFORM_SA_DEV" `
    --role="roles/artifactregistry.admin" `
    --quiet

if ($prodProjectExists -and $prodRepoExists) {
    gcloud artifacts repositories add-iam-policy-binding $ARTIFACT_REPO `
        --project=$PROD_PROJECT_ID `
        --location=us-central1 `
        --member="serviceAccount:$TERRAFORM_SA_PROD" `
        --role="roles/artifactregistry.admin" `
        --quiet
}
Write-Host "Terraform SAs granted access to Artifact Registries"
Write-Host ""

Write-Host "========================================"
Write-Host "Setup Complete!"
Write-Host "========================================"
Write-Host ""
Write-Host "Add these secrets to your GitHub repository:"
Write-Host "Repository -> Settings -> Secrets and variables -> Actions"
Write-Host ""
Write-Host "Name: WIF_PROVIDER"
Write-Host "Value: $WI_PROVIDER"
Write-Host ""
Write-Host "Name: WIF_SA_EMAIL_DEV"
Write-Host "Value: $TERRAFORM_SA_DEV"
Write-Host ""
Write-Host "Name: WIF_SA_EMAIL_PROD"
Write-Host "Value: $TERRAFORM_SA_PROD"
Write-Host ""
Write-Host "Name: GCP_PROJECT_ID_DEV"
Write-Host "Value: $DEV_PROJECT_ID"
Write-Host ""
Write-Host "Name: GCP_PROJECT_ID_PROD"
Write-Host "Value: $PROD_PROJECT_ID"
Write-Host ""
Write-Host "Name: GCS_TERRAFORM_STATE_BUCKET_DEV"
Write-Host "Value: $STATE_BUCKET_DEV"
Write-Host ""
Write-Host "Name: GCS_TERRAFORM_STATE_BUCKET_PROD"
Write-Host "Value: $STATE_BUCKET_PROD"
Write-Host ""
Write-Host "Also add your application secrets (sensitive values):"
Write-Host "- WHATSAPP_API_KEY"
Write-Host "- GEMINI_API_KEY"
Write-Host "- GOOGLE_CLIENT_ID"
Write-Host "- GOOGLE_CLIENT_SECRET"
Write-Host "- GOOGLE_REFRESH_TOKEN"
Write-Host "- WHATSAPP_WEBHOOK_VERIFY_TOKEN"
Write-Host "- SPREADSHEET_ID_DEV"
Write-Host "- SPREADSHEET_ID_PROD"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Add the secrets above to GitHub"
Write-Host "2. Initialize Terraform: cd terraform; terraform init"
Write-Host "3. Create a pull request to trigger terraform plan"
Write-Host "4. Merge and manually approve terraform apply workflow"
