# Financia - WhatsApp Expense Tracking Agent

Personal expense tracking application using WhatsApp as the interface, powered by AI agents (Google ADK + Gemini).

## 🚀 Quick Start

### Infrastructure Setup (First Time)

1. **Run Workload Identity Setup**
   ```bash
   chmod +x scripts/setup-workload-identity.sh
   ./scripts/setup-workload-identity.sh
   ```

2. **Configure GitHub Secrets**
   - Add infrastructure secrets (from setup script output)
   - Add application secrets (API keys, tokens)
   - See [INFRASTRUCTURE_SETUP.md](docs/INFRASTRUCTURE_SETUP.md)

3. **Create GitHub Environments**
   - Create `dev` environment (no protection)
   - Create `prod` environment (with reviewers)

4. **Deploy Infrastructure**
   - Create a PR (triggers terraform plan)
   - Merge PR
   - Manually trigger Terraform Apply workflows

📖 **Detailed Guide**: [docs/INFRASTRUCTURE_SETUP.md](docs/INFRASTRUCTURE_SETUP.md)

## 📁 Project Structure

```
financia/
├── main.py                          # FastAPI entry point
├── pyproject.toml & uv.lock        # UV dependency management
├── app/
│   ├── agents/                     # Google ADK agents (5 specialized agents)
│   ├── services/                   # Business logic (Gemini, Sheets, WhatsApp)
│   ├── models/                     # Pydantic models
│   └── utils/                      # Auth, config helpers
├── terraform/                      # Infrastructure as Code (GCP)
│   ├── main.tf                    # Root module
│   ├── modules/                   # Reusable modules (IAM, Cloud Run, etc.)
│   └── environments/              # Dev and prod configurations
├── tests/                          # Unit, integration, agent tests
├── docs/                           # Detailed documentation
├── scripts/                        # Setup and utility scripts
└── .github/workflows/              # CI/CD pipelines
```

## 🏗️ Architecture

### Multi-Agent System (Google ADK)

```
WhatsApp Message
    ↓
[Speech Agent] (if voice)
    ↓
[Intent Recognition Agent]
    ↓
[Entity Extraction Agent]
    ↓
[Data Persistence Agent]
    ↓
[Response Generation Agent]
    ↓
WhatsApp Response
```

### Infrastructure (GCP)

```
GitHub Actions (OIDC)
    ↓
Workload Identity Federation
    ↓
Terraform Service Accounts
    ↓
GCP Resources:
├── Cloud Run (Application)
├── Secret Manager (Credentials)
├── Google Sheets (Data Storage)
└── Cloud Monitoring (Alerts)
```

## 🛠️ Tech Stack

- **Language**: Python 3.11+ with UV package manager
- **Framework**: FastAPI (async/await)
- **AI/Agents**: Google ADK + Gemini API (multi-agent system)
- **Storage**: Google Sheets
- **Infrastructure**: Terraform (IaC) + GCP (Cloud Run, Secret Manager)
- **CI/CD**: GitHub Actions with Workload Identity Federation (keyless auth)
- **Interface**: WhatsApp Business API

## 🔐 Security Features

- ✅ **Keyless Authentication**: GitHub OIDC → GCP Workload Identity (no JSON keys)
- ✅ **Secret Management**: All credentials in GCP Secret Manager
- ✅ **Granular IAM**: Separate service accounts for dev/prod
- ✅ **HTTPS**: Automatic on Cloud Run
- ✅ **Input Validation**: Sanitize all WhatsApp inputs
- ✅ **Audit Logging**: All actions logged and traceable

## 🚢 Deployment

### CI/CD Pipeline

**Automatic (on PR)**:
```
Pull Request → Terraform Plan → Post plan in PR comment
```

**Manual (after merge)**:
```
Merge PR → Navigate to Actions → Terraform Apply → Type confirmation → Deploy
```

### Environments

- **Dev**: `financia-api-dev` - Testing environment
- **Prod**: `financia-api` - Production (requires approval)

### Deploying Changes

1. Create feature branch
2. Make changes
3. Create PR (automatic terraform plan)
4. Review plan output in PR
5. Merge PR
6. Manually trigger Terraform Apply workflow
7. Monitor deployment

📖 **Deployment Guide**: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

## 📊 Monitoring

- **Health Endpoint**: `/health`
- **Metrics**: Request count, latency, error rate
- **Alerts**: High error rate, high latency, service down
- **Dashboards**: Custom Cloud Monitoring dashboards

Access monitoring: [Cloud Console](https://console.cloud.google.com/monitoring?project=dev-ai-agents-projects)

## 🧪 Development

### Local Setup

```bash
# Install UV
curl -LsSf https://astral.sh/uv/install.sh | sh  # Unix
# or
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"  # Windows

# Install dependencies
uv sync

# Run locally
uv run uvicorn main:app --reload

# Run tests
uv run pytest
```

### Environment Variables

Copy `.env.example` to `.env` and fill in values:
```bash
GCP_PROJECT_ID=dev-ai-agents-projects
SPREADSHEET_ID=your-google-sheets-id
WHATSAPP_API_KEY=your-whatsapp-key
GEMINI_API_KEY=your-gemini-key
# ... see .env.example for complete list
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [INFRASTRUCTURE_SETUP.md](docs/INFRASTRUCTURE_SETUP.md) | Complete infrastructure setup guide |
| [INFRASTRUCTURE_CHECKLIST.md](docs/INFRASTRUCTURE_CHECKLIST.md) | Step-by-step setup checklist |
| [INFRASTRUCTURE_SUMMARY.md](docs/INFRASTRUCTURE_SUMMARY.md) | Overview of infrastructure |
| [SETUP_COMMANDS.md](docs/SETUP_COMMANDS.md) | Copy-paste setup commands |
| [AGENT_ARCHITECTURE.md](docs/AGENT_ARCHITECTURE.md) | Multi-agent system design |
| [CODING_STANDARDS.md](docs/CODING_STANDARDS.md) | Code style and conventions |
| [DATA_SCHEMA.md](docs/DATA_SCHEMA.md) | Data models and API specs |
| [SECURITY.md](docs/SECURITY.md) | Security and authentication |
| [TERRAFORM.md](docs/TERRAFORM.md) | Terraform infrastructure details |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | CI/CD and deployment guide |

## 🎯 Key Features

- **Natural Language Processing**: Understand expense messages in plain English/Spanish
- **Voice Message Support**: Transcribe and process voice notes
- **Automatic Categorization**: AI-powered expense categorization
- **Monthly Summaries**: Get spending insights by period or category
- **Multi-Currency**: Support for USD, CLP, EUR, and more
- **Secure & Private**: Single-user application with end-to-end security
- **Serverless**: Auto-scaling, pay-per-use infrastructure
- **Infrastructure as Code**: Reproducible, version-controlled deployments

## 🔧 API Endpoints

- `POST /webhook` - WhatsApp message webhook (main entry point)
- `GET /webhook` - WhatsApp webhook verification
- `GET /health` - Health check endpoint

## 🗂️ Data Schema

### Google Sheets: `MyExpenses`

| Column | Type | Example |
|--------|------|---------|
| Date | Date | 2025-11-04 |
| Amount | Number | 5.00 |
| Currency | String | USD |
| Category | String | food |
| Description | String | Coffee at Starbucks |
| WhatsApp Message ID | String | wamid.HBgL... |

### Categories
- `food` - Meals, groceries, restaurants
- `transport` - Public transport, gas, parking
- `entertainment` - Movies, concerts, subscriptions
- `shopping` - Clothing, electronics, household
- `utilities` - Electricity, water, internet
- `health` - Medical, pharmacy, fitness
- `other` - Miscellaneous expenses

## 🤖 Agent Examples

### Adding an Expense
**User**: "I spent $10 on coffee"

**System**:
1. Intent Agent: Recognizes `add_expense`
2. Entity Agent: Extracts `amount=10.0`, `currency=USD`, `category=food`
3. Persistence Agent: Saves to Google Sheets
4. Response Agent: "✅ Expense added! 💰 $10.00 USD 📁 Food"

### Getting Summary
**User**: "What did I spend this month?"

**System**:
1. Intent Agent: Recognizes `get_monthly_summary`
2. Entity Agent: Extracts `period=month`
3. Persistence Agent: Queries Google Sheets
4. Response Agent: "📊 Monthly Summary - November 2025..."

## 🧰 Useful Commands

### Terraform
```bash
# Initialize
cd terraform && terraform init -backend-config=environments/dev/backend.hcl

# Plan
terraform plan -var-file=environments/dev/terraform.tfvars

# Validate
terraform validate

# Format
terraform fmt -recursive
```

### UV Package Manager
```bash
# Add dependency
uv add package-name

# Remove dependency
uv remove package-name

# Sync dependencies
uv sync

# Run command
uv run <command>
```

### gcloud CLI
```bash
# List Cloud Run services
gcloud run services list --region=us-central1

# View logs
gcloud run services logs read financia-api-dev --region=us-central1

# List secrets
gcloud secrets list --project=dev-ai-agents-projects
```

## 🚨 Troubleshooting

### Common Issues

**Issue**: Terraform authentication fails
- **Solution**: Verify Workload Identity Federation is set up correctly
- Run: `gcloud iam workload-identity-pools describe github-actions-pool ...`

**Issue**: GitHub Actions can't authenticate to GCP
- **Solution**: Check GitHub secrets are set correctly
- Verify: `WIF_PROVIDER`, `WIF_SA_EMAIL_DEV`, `WIF_SA_EMAIL_PROD`

**Issue**: Cloud Run deployment fails
- **Solution**: Check service account has correct IAM permissions
- Run: `gcloud projects get-iam-policy dev-ai-agents-projects`

📖 **Full Troubleshooting Guide**: [docs/INFRASTRUCTURE_SETUP.md](docs/INFRASTRUCTURE_SETUP.md#troubleshooting)

## 🎓 Best Practices

1. ✅ **Always test in dev before prod**
2. ✅ **Review terraform plan output before applying**
3. ✅ **Use manual approval for production deployments**
4. ✅ **Keep secrets in Secret Manager or GitHub Secrets**
5. ✅ **Monitor deployments via Cloud Monitoring**
6. ✅ **Use semantic commit messages**
7. ✅ **Write tests for new features**
8. ✅ **Document infrastructure changes**

## 📈 Future Enhancements

- Budget alerts and notifications
- Receipt image upload and OCR
- Spending trends and visualizations
- Export to CSV/PDF
- Recurring expense tracking
- Multiple Google Sheets support
- Multi-language support (beyond English/Spanish)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Make changes and test locally
4. Create PR (triggers terraform plan)
5. Wait for review and approval
6. Merge and deploy!

## 📄 License

This is a personal project. All rights reserved.

## 🙏 Acknowledgments

- Google ADK for agent framework
- Google Gemini for AI capabilities
- Google Cloud Platform for infrastructure
- WhatsApp Business API for messaging
- FastAPI for web framework
- UV for package management

---

**Made with ❤️ using AI agents and Infrastructure as Code**

For detailed setup instructions, see [docs/INFRASTRUCTURE_SETUP.md](docs/INFRASTRUCTURE_SETUP.md)
