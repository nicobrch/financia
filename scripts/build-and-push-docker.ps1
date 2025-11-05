# Build and Push Docker Image to Artifact Registry
# This script builds the Docker image locally and pushes it to GCP Artifact Registry

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod")]
    [string]$Environment = "dev",

    [Parameter(Mandatory=$false)]
    [string]$ProjectId = "dev-ai-agents-projects",

    [Parameter(Mandatory=$false)]
    [string]$Tag = "latest"
)

$ErrorActionPreference = "Stop"

Write-Host "Building and Pushing Docker Image" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Project ID: $ProjectId" -ForegroundColor Yellow
Write-Host "Tag: $Tag" -ForegroundColor Yellow
Write-Host ""

# Check if Docker is running
Write-Host "Checking Docker..." -ForegroundColor Yellow
try {
    docker info | Out-Null
    Write-Host "[OK] Docker is running" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}
Write-Host ""

# Check if gcloud is authenticated
Write-Host "Checking gcloud authentication..." -ForegroundColor Yellow
$currentAccount = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Not authenticated. Please run: gcloud auth login" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Authenticated as: $currentAccount" -ForegroundColor Green
Write-Host ""

# Set project
Write-Host "Setting project..." -ForegroundColor Yellow
gcloud config set project $ProjectId | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to set project" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Project set to: $ProjectId" -ForegroundColor Green
Write-Host ""

# Configure Docker for Artifact Registry
Write-Host "Configuring Docker for Artifact Registry..." -ForegroundColor Yellow
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to configure Docker authentication" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Docker authentication configured" -ForegroundColor Green
Write-Host ""

# Build the image
$imageName = "us-central1-docker.pkg.dev/$ProjectId/financia/api"
$fullImageName = "${imageName}:${Tag}"

Write-Host "Building Docker image..." -ForegroundColor Cyan
Write-Host "Image: $fullImageName" -ForegroundColor Yellow
Write-Host ""

docker build -t $fullImageName .
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Docker build failed" -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "[OK] Docker image built successfully" -ForegroundColor Green
Write-Host ""

# Push the image
Write-Host "Pushing image to Artifact Registry..." -ForegroundColor Cyan
docker push $fullImageName
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Docker push failed" -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "[OK] Image pushed successfully" -ForegroundColor Green
Write-Host ""

# Also tag as latest if not already
if ($Tag -ne "latest") {
    Write-Host "Tagging as 'latest'..." -ForegroundColor Yellow
    docker tag $fullImageName "${imageName}:latest"
    docker push "${imageName}:latest"
    Write-Host "[OK] Tagged and pushed as 'latest'" -ForegroundColor Green
    Write-Host ""
}

Write-Host "Success!" -ForegroundColor Green
Write-Host ""
Write-Host "Image Details:" -ForegroundColor Cyan
Write-Host "  Repository: $imageName" -ForegroundColor White
Write-Host "  Tag: $Tag" -ForegroundColor White
Write-Host "  Full name: $fullImageName" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Run Terraform apply to deploy this image" -ForegroundColor White
Write-Host "  2. Or trigger the Terraform Apply workflow in GitHub Actions" -ForegroundColor White
Write-Host ""
