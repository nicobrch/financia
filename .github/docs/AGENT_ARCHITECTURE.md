# Agent Architecture

## Overview
Financia uses a multi-agent system built with Google ADK. Each agent has a specialized responsibility, making the system modular, testable, and maintainable.

## Agent Communication Flow
```
WhatsApp Message
    ↓
[Speech Agent] (if voice message)
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

## Agent Specifications

### 1. Intent Recognition Agent (`app/agents/intent_agent.py`)

**Purpose**: Classify user messages into predefined intents

**Intents**:
- `add_expense` - User wants to log a new expense
- `get_monthly_summary` - User wants monthly spending summary
- `get_category_summary` - User wants spending breakdown by category
- `help` - User needs assistance
- `unknown` - Cannot determine intent

**Input**:
```python
text: str  # Raw message text from WhatsApp
```

**Output**:
```python
@dataclass
class IntentResult:
    intent: str
    confidence: float  # 0.0 to 1.0
    context: dict  # Additional context from analysis
```

**Gemini Prompt Pattern**:
```python
"""
Analyze this user message and classify the intent:
Message: "{text}"

Valid intents: add_expense, get_monthly_summary, get_category_summary, help, unknown

Respond with JSON:
{
  "intent": "add_expense",
  "confidence": 0.95,
  "reasoning": "User is reporting a purchase with amount"
}
"""
```

**Key Methods**:
- `async analyze(text: str) -> IntentResult`
- `_build_intent_prompt(text: str) -> str`
- `_parse_intent_response(response: GenerateContentResponse) -> IntentResult`

---

### 2. Entity Extraction Agent (`app/agents/entity_agent.py`)

**Purpose**: Extract structured data from natural language messages

**Entities**:
- `amount`: float (e.g., 5.00, 10.50)
- `currency`: str (USD, CLP, EUR)
- `category`: str (food, transport, entertainment, shopping, utilities, health, other)
- `description`: str (free-form text)
- `date`: datetime.date (default: today)
- `period`: str (for queries: "month", "week", "year")

**Input**:
```python
text: str
intent: str  # From Intent Recognition Agent
```

**Output**:
```python
@dataclass
class ExpenseModel:
    amount: float
    currency: str
    category: str
    description: str
    date: datetime.date
    message_id: str

@dataclass
class QueryModel:
    period: str  # "month", "week", "year"
    category: Optional[str]
    start_date: Optional[datetime.date]
    end_date: Optional[datetime.date]
```

**Gemini Prompt Pattern**:
```python
"""
Extract expense information from this message:
Message: "{text}"
Intent: {intent}

Extract:
- amount: numeric value
- currency: USD/CLP/etc (default: USD)
- category: food/transport/entertainment/shopping/utilities/health/other
- description: brief description
- date: YYYY-MM-DD (default: today)

Today's date: {datetime.now().date()}

Respond with JSON.
"""
```

**Key Methods**:
- `async extract(text: str, intent: str) -> Union[ExpenseModel, QueryModel]`
- `_build_extraction_prompt(text: str, intent: str) -> str`
- `_parse_extraction_response(response: GenerateContentResponse) -> Union[ExpenseModel, QueryModel]`

---

### 3. Text-to-Speech Agent (`app/agents/speech_agent.py`)

**Purpose**: Transcribe voice messages to text

**Input**:
```python
audio_url: str  # URL to audio file from WhatsApp
# OR
audio_data: bytes  # Raw audio data
```

**Output**:
```python
text: str  # Transcribed text
```

**Implementation Options**:
1. **Google Speech-to-Text API** (recommended for production)
2. **Gemini Audio Processing** (if available)
3. **WhatsApp built-in transcription** (if provider supports it)

**Key Methods**:
- `async transcribe(audio_url: str) -> str`
- `async transcribe_bytes(audio_data: bytes) -> str`
- `_download_audio(audio_url: str) -> bytes`

**Error Handling**:
- Retry logic for network failures
- Fallback to "Could not transcribe audio" message
- Log transcription failures for debugging

---

### 4. Data Persistence Agent (`app/agents/persistence_agent.py`)

**Purpose**: Manage all Google Sheets CRUD operations

**Responsibilities**:
- Add new expense rows to Google Sheets
- Query expenses by filters
- Calculate summaries and aggregations
- Validate data before writing

**Input**:
```python
# For adding expense
expense: ExpenseModel

# For querying
query: QueryModel
```

**Output**:
```python
@dataclass
class PersistenceResult:
    success: bool
    message: str
    data: Optional[dict]  # For query results

@dataclass
class SummaryResult:
    total_amount: float
    currency: str
    count: int
    breakdown: dict[str, float]  # category -> amount
    period: str
```

**Key Methods**:
- `async add_expense(expense: ExpenseModel) -> PersistenceResult`
- `async get_monthly_summary(month: int, year: int) -> SummaryResult`
- `async get_category_summary(category: str, period: str) -> SummaryResult`
- `async query_expenses(query: QueryModel) -> List[ExpenseModel]`

**Google Sheets Operations**:
```python
# Append row
await sheets_service.spreadsheets().values().append(
    spreadsheetId=SPREADSHEET_ID,
    range="MyExpenses!A:F",
    valueInputOption="USER_ENTERED",
    body={"values": [[date, amount, currency, category, description, msg_id]]}
).execute()

# Query rows
result = await sheets_service.spreadsheets().values().get(
    spreadsheetId=SPREADSHEET_ID,
    range="MyExpenses!A:F"
).execute()
```

---

### 5. Response Generation Agent (`app/agents/response_agent.py`)

**Purpose**: Generate natural, conversational responses for WhatsApp

**Input**:
```python
result: Union[PersistenceResult, SummaryResult]
intent: str
language: str  # "en" or "es"
```

**Output**:
```python
text: str  # Formatted WhatsApp message with emoji
```

**Response Templates**:

**Success (add_expense)**:
```
✅ Expense added!
💰 Amount: $5.00 USD
📁 Category: Food
📝 Description: Coffee at Starbucks
📅 Date: Nov 4, 2025
```

**Monthly Summary**:
```
📊 Monthly Summary - November 2025

💰 Total: $450.50 USD (23 expenses)

Breakdown by category:
🍔 Food: $180.00 (40%)
🚗 Transport: $120.00 (27%)
🎬 Entertainment: $90.50 (20%)
🛒 Shopping: $60.00 (13%)
```

**Error**:
```
❌ Oops! Something went wrong.
{error_message}

Try again or type "help" for assistance.
```

**Key Methods**:
- `async generate(result: Union[PersistenceResult, SummaryResult], intent: str, language: str = "en") -> str`
- `_format_expense_confirmation(expense: ExpenseModel) -> str`
- `_format_summary(summary: SummaryResult) -> str`
- `_format_error(error: str) -> str`

**Gemini Usage**:
For complex summaries, use Gemini to generate conversational text:
```python
"""
Generate a friendly WhatsApp message for this expense summary:
Total: $450.50
Breakdown: Food $180, Transport $120, Entertainment $90.50, Shopping $60
Period: November 2025

Make it conversational, use emoji, keep it under 300 characters.
"""
```

---

## Agent Base Class Pattern

All agents should extend a common base class for consistency:

```python
# app/agents/base_agent.py
from abc import ABC, abstractmethod
from google.adk import Agent
from google.generativeai import GenerativeModel

class BaseFinanciaAgent(Agent, ABC):
    def __init__(self, name: str, model_name: str = "gemini-pro"):
        super().__init__(name=name)
        self.model = GenerativeModel(model_name)
        self.logger = logging.getLogger(f"agent.{name}")

    @abstractmethod
    async def process(self, *args, **kwargs):
        """Main processing method - implement in subclass"""
        pass

    async def _call_gemini(self, prompt: str) -> str:
        """Shared Gemini API call with error handling"""
        try:
            response = await self.model.generate_content_async(prompt)
            return response.text
        except Exception as e:
            self.logger.error(f"Gemini API error: {e}")
            raise
```

## Agent Orchestration

The main orchestration happens in `app/api/webhooks.py`:

```python
# app/api/webhooks.py
class AgentOrchestrator:
    def __init__(self):
        self.speech_agent = SpeechAgent()
        self.intent_agent = IntentRecognitionAgent()
        self.entity_agent = EntityExtractionAgent()
        self.persistence_agent = DataPersistenceAgent()
        self.response_agent = ResponseGenerationAgent()

    async def process_message(self, whatsapp_message: WhatsAppMessage) -> WhatsAppResponse:
        try:
            # 1. Transcribe if voice
            if whatsapp_message.is_voice:
                text = await self.speech_agent.transcribe(whatsapp_message.audio_url)
            else:
                text = whatsapp_message.text

            # 2. Recognize intent
            intent_result = await self.intent_agent.analyze(text)

            if intent_result.confidence < 0.5:
                return WhatsAppResponse(text="I'm not sure what you mean. Can you rephrase?")

            # 3. Extract entities
            entities = await self.entity_agent.extract(text, intent_result.intent)

            # 4. Persist or query
            if intent_result.intent == "add_expense":
                result = await self.persistence_agent.add_expense(entities)
            elif intent_result.intent == "get_monthly_summary":
                result = await self.persistence_agent.get_monthly_summary(
                    month=entities.start_date.month,
                    year=entities.start_date.year
                )
            elif intent_result.intent == "get_category_summary":
                result = await self.persistence_agent.get_category_summary(
                    category=entities.category,
                    period=entities.period
                )

            # 5. Generate response
            response_text = await self.response_agent.generate(
                result,
                intent_result.intent,
                language="en"  # TODO: detect language
            )

            return WhatsAppResponse(text=response_text)

        except Exception as e:
            logger.error(f"Error processing message: {e}", exc_info=True)
            return WhatsAppResponse(text="❌ Sorry, something went wrong. Please try again.")
```

## Testing Agents

Each agent should have comprehensive unit tests:

```python
# tests/test_agents/test_intent_agent.py
import pytest
from app.agents.intent_agent import IntentRecognitionAgent

@pytest.mark.asyncio
async def test_intent_recognition_add_expense():
    agent = IntentRecognitionAgent()
    result = await agent.analyze("I spent $10 on coffee")

    assert result.intent == "add_expense"
    assert result.confidence > 0.8

@pytest.mark.asyncio
async def test_intent_recognition_monthly_summary():
    agent = IntentRecognitionAgent()
    result = await agent.analyze("What did I spend this month?")

    assert result.intent == "get_monthly_summary"
    assert result.confidence > 0.8
```

## Agent Best Practices

1. **Single Responsibility**: Each agent does one thing well
2. **Async/Await**: All I/O operations are async
3. **Error Handling**: Graceful degradation, never crash
4. **Logging**: Comprehensive logging for debugging
5. **Type Hints**: Strict typing for all methods
6. **Testing**: >80% test coverage for each agent
7. **Retry Logic**: Implement retries for external API calls
8. **Caching**: Cache Gemini responses for similar queries
9. **Monitoring**: Track agent performance metrics
10. **Versioning**: Version agent prompts and behaviors

## Agent Configuration

```python
# app/config.py
from pydantic import BaseSettings

class AgentConfig(BaseSettings):
    gemini_model: str = "gemini-pro"
    intent_confidence_threshold: float = 0.5
    max_retries: int = 3
    cache_ttl: int = 3600  # 1 hour

    # Agent-specific settings
    speech_agent_timeout: int = 30
    persistence_agent_batch_size: int = 100

    class Config:
        env_file = ".env"
        env_prefix = "AGENT_"

agent_config = AgentConfig()
```

## Future Agent Enhancements

- **Budget Alert Agent**: Monitor spending and send proactive alerts
- **Categorization Agent**: Smart auto-categorization based on description
- **Analytics Agent**: Generate insights and trends
- **Receipt OCR Agent**: Extract data from receipt images
- **Multi-language Agent**: Support multiple languages simultaneously
