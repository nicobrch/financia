# Financia - WhatsApp Expense Tracking Agent

## Project Overview
Financia is a personal **single-user** expense tracking application using WhatsApp as the interface. Users log expenses and query financial data through natural language (text/voice). The system uses AI agents (Google ADK + Gemini) to understand intent and stores data in Google Sheets.

**Key Principles**: Serverless-first • Cost-effective • Security-first • Multi-agent architecture

## Tech Stack Summary
- **Language**: Python 3.11+ with UV package manager
- **Framework**: FastAPI (async/await)
- **AI/Agents**: Google ADK + Gemini API (multi-agent system)
- **Storage**: Google Sheets
- **Infrastructure**: Terraform (IaC) + GCP (Cloud Run, Secret Manager)
- **Interface**: WhatsApp Business API

**Dependencies**: `uv`, `google-adk`, `fastapi`, `google-cloud-secret-manager`, `google-auth`, `google-api-python-client`, `pydantic`, `uvicorn`, `terraform`

## Multi-Agent Architecture (Google ADK)
The system uses 5 specialized agents orchestrated by FastAPI:

1. **Intent Recognition Agent** (`intent_agent.py`) - Classifies user intent from messages
2. **Entity Extraction Agent** (`entity_agent.py`) - Extracts structured data (amount, category, date, etc.)
3. **Text-to-Speech Agent** (`speech_agent.py`) - Transcribes voice messages
4. **Data Persistence Agent** (`persistence_agent.py`) - Manages Google Sheets CRUD operations
5. **Response Generation Agent** (`response_agent.py`) - Creates natural language responses

**Agent Flow**: WhatsApp Message → Speech Agent (if voice) → Intent Agent → Entity Agent → Persistence Agent → Response Agent → WhatsApp Response

📄 **Details**: See [docs/AGENT_ARCHITECTURE.md](docs/AGENT_ARCHITECTURE.md) for complete agent specifications and patterns

## Project Structure (Monorepo)
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
├── tests/                          # Unit, integration, agent tests
├── docs/                           # Detailed documentation
└── .github/workflows/              # CI/CD pipelines
```

## Coding Standards
- **Naming**: snake_case (files/functions), PascalCase (classes), UPPER_SNAKE_CASE (constants)
- **Type hints**: Mandatory for all function signatures
- **Async/await**: Required for all I/O operations
- **Data validation**: Use Pydantic models
- **Error handling**: Graceful with comprehensive logging
- **Style**: Follow PEP 8

📄 **Details**: See [docs/CODING_STANDARDS.md](docs/CODING_STANDARDS.md) for complete guidelines and examples

## Key Integrations

### Google Sheets Schema
**Sheet**: `MyExpenses` | **Columns**: Date, Amount, Currency, Category, Description, WhatsApp Message ID

### API Endpoints
- `POST /webhook` - WhatsApp message webhook (main entry point)
- `GET /health` - Health check endpoint

### Secret Manager Variables
- `WHATSAPP_API_KEY`, `GEMINI_API_KEY`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN`

📄 **Details**: See [docs/DATA_SCHEMA.md](docs/DATA_SCHEMA.md) for complete data structures and API specifications

## Security & Authentication
- **OAuth 2.0**: Google Drive/Sheets access with refresh tokens in Secret Manager
- **Secret Manager**: All credentials stored securely (never hardcode)
- **HTTPS**: Automatic on Cloud Run
- **IAM**: Least privilege service accounts
- **Input validation**: Sanitize all WhatsApp inputs

📄 **Details**: See [docs/SECURITY.md](docs/SECURITY.md) for OAuth flow and security best practices

## Infrastructure as Code (Terraform)
- **Monorepo**: Terraform configs in `terraform/` directory
- **Service Account**: `gcp-terraform@dev-ai-agents-projects.iam.gserviceaccount.com`
- **Resources**: Cloud Run, Secret Manager, IAM, Monitoring
- **CI/CD**: `terraform plan` on PRs, `terraform apply` on merge to main

📄 **Details**: See [docs/TERRAFORM.md](docs/TERRAFORM.md) for complete infrastructure setup and modules

## Deployment & CI/CD
**CI Pipeline**: Linting → Type checking → Tests → Terraform plan → Docker build → Push to Artifact Registry

**CD Pipeline**: Terraform apply → Deploy to Cloud Run → Smoke tests

📄 **Details**: See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for complete CI/CD configuration

## Common Patterns & Examples

### Creating a Google ADK Agent
```python
# app/agents/intent_agent.py
from google.adk import Agent
from google.generativeai import GenerativeModel

class IntentRecognitionAgent(Agent):
    def __init__(self, model_name: str = "gemini-pro"):
        super().__init__(name="IntentRecognizer")
        self.model = GenerativeModel(model_name)

    async def analyze(self, text: str) -> IntentResult:
        prompt = self._build_intent_prompt(text)
        response = await self.model.generate_content_async(prompt)
        return self._parse_intent_response(response)

    def _build_intent_prompt(self, text: str) -> str:
        return f"""
        Analyze this user message and determine the intent:
        Message: "{text}"

        Possible intents:
        - add_expense: Recording a new expense
        - get_monthly_summary: Request for monthly spending summary
        - get_category_summary: Request for spending by category
        - help: User needs assistance
        - unknown: Cannot determine intent

        Respond in JSON: {{"intent": "...", "confidence": 0.95}}
        """
```

### Processing WhatsApp Messages with Agents
```python
# app/api/webhooks.py
async def process_whatsapp_message(message: WhatsAppMessage) -> WhatsAppResponse:
    # 1. Handle voice messages
    if message.is_voice:
        text = await speech_agent.transcribe(message.audio_url)
    else:
        text = message.text

    # 2. Determine intent
    intent_result = await intent_agent.analyze(text)

    # 3. Extract entities
    entities = await entity_agent.extract(text, intent_result.intent)

    # 4. Execute action
    if intent_result.intent == "add_expense":
        result = await persistence_agent.add_expense(entities)
    elif intent_result.intent == "get_monthly_summary":
        result = await persistence_agent.get_monthly_summary(entities.period)
    elif intent_result.intent == "get_category_summary":
        result = await persistence_agent.get_category_summary(entities.category)

    # 5. Generate response
    response = await response_agent.generate(result, intent_result.intent)

    return WhatsAppResponse(text=response)
```

### Gemini Prompt Template
```python
INTENT_PROMPT = """
User message: "{user_message}"

Task: Identify the user's intent and extract relevant information.

Possible intents:
- add_expense: User wants to record a new expense
- get_monthly_summary: User wants to see spending summary for a period
- get_category_summary: User wants to see spending by category

Extract entities:
- amount: numeric value (e.g., 5, 10.50)
- currency: USD, CLP, etc.
- category: food, transport, entertainment, etc.
- description: free text
- date: YYYY-MM-DD (default: today)
- period: month, week, year (for summaries)

Respond in JSON format.
"""
```

### Google Sheets Operations
```python
async def add_expense(expense: ExpenseModel) -> None:
    values = [[
        expense.date.isoformat(),
        expense.amount,
        expense.currency,
        expense.category,
        expense.description,
        expense.message_id
    ]]

    await sheets_client.append(
        spreadsheet_id=SPREADSHEET_ID,
        range="MyExpenses!A:F",
        values=values
    )
```

## Troubleshooting & Common Issues

### Issue: OAuth Token Expired
- **Solution**: Implement automatic token refresh using refresh token from Secret Manager

### Issue: Gemini API Rate Limits
- **Solution**: Implement exponential backoff and caching for similar queries

### Issue: WhatsApp Webhook Timeouts
- **Solution**: Respond immediately with 200 OK, process message asynchronously

### Issue: Google Sheets API Quota
- **Solution**: Batch operations when possible, implement local caching

## Development Workflow

### Local Development
1. Install UV: `curl -LsSf https://astral.sh/uv/install.sh | sh` (Unix) or `powershell -c "irm https://astral.sh/uv/install.ps1 | iex"` (Windows)
2. Create project: `uv init` (if starting fresh)
3. Add dependencies: `uv add fastapi google-adk google-cloud-secret-manager google-auth google-api-python-client pydantic uvicorn`
4. Install dependencies: `uv sync`
5. Configure local `.env` file with test credentials
6. Run FastAPI locally: `uv run uvicorn main:app --reload`
7. Use ngrok or similar for WhatsApp webhook testing

### UV Commands Reference
- `uv add <package>` - Add a dependency to pyproject.toml
- `uv remove <package>` - Remove a dependency
- `uv sync` - Install/update all dependencies from pyproject.toml
- `uv run <command>` - Run a command in the project environment
- `uv pip install <package>` - Install a package (like pip)
- `uv lock` - Update uv.lock file

### Making Changes
1. Create feature branch from `main`
2. Write tests first (TDD)
3. Implement feature
4. Run tests and linting locally
5. Create PR with clear description
6. Wait for CI checks to pass
7. Merge to `main` (triggers deployment)

## Future Enhancements (Low Priority)
- Budget alerts and notifications
- Multi-currency support with automatic conversion
- Receipt image upload and OCR
- Spending trends and visualizations
- Export to CSV/PDF
- Recurring expense tracking
- Multiple Google Sheets support (different budgets)

## Important Reminders for Copilot
- This is a **single-user application** - no need for user management or multi-tenancy
- **Monorepo structure** - application code and Terraform infrastructure in the same repository
- **Terraform for infrastructure** - all GCP resources must be defined in Terraform, use service account `gcp-terraform@dev-ai-agents-projects.iam.gserviceaccount.com`
- **UV is the package manager** - use `uv add`, `uv sync`, `uv run` instead of pip commands
- **Google ADK for agents** - all intelligent components should be implemented as agents
- **Multi-agent architecture** - separate agents for intent, entity extraction, speech, persistence, and response generation
- **Cost optimization** is crucial - use free tiers and serverless architecture
- **Natural language understanding** is core - Gemini integration is critical through agents
- **Async/await** for all I/O operations (API calls, database operations)
- **Type hints** are mandatory for better code quality and IDE support
- **Security** - always use Secret Manager, never hardcode credentials
- **Testing** - write tests for new features, especially agent logic and Gemini prompt engineering
- **Logging** - comprehensive logging for debugging WhatsApp webhook issues and agent orchestration
