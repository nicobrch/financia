# PowerShell Scripts for Windows

This folder contains PowerShell versions of the setup scripts for Windows users.

## Scripts

### setup-workload-identity.ps1
Main setup script that creates all GCP infrastructure for GitHub OIDC authentication:
- Workload Identity Pool and Provider
- Terraform service accounts (dev and prod)
- IAM role bindings
- GCS bucket for Terraform state
- Artifact Registry repository

**Usage**:
```powershell
.\scripts\setup-workload-identity.ps1
```

### quick-setup.ps1
Interactive setup guide that walks you through the entire setup process step-by-step.

**Usage**:
```powershell
.\scripts\quick-setup.ps1
```

## Prerequisites

- **gcloud CLI** installed and authenticated
- **PowerShell 5.1+** (comes with Windows)
- **Project Owner** or **Workload Identity Pool Admin** role in GCP

## Bash Scripts

The original bash scripts are also included for Linux/Mac users:
- `setup-workload-identity.sh`
- `quick-setup.sh`

**Usage on Linux/Mac**:
```bash
chmod +x scripts/*.sh
./scripts/setup-workload-identity.sh
```

## Notes

- PowerShell scripts use backticks (`) for line continuation
- Error handling uses `$ErrorActionPreference = "Stop"`
- Use `2>$null` instead of `2>/dev/null` for error suppression
- Environment variables accessed via `$env:VARIABLE_NAME`

## Execution Policy

If you get an error about execution policy, run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

This allows you to run local scripts you've created.
