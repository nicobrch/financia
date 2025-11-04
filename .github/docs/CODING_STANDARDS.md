# Coding Standards

## Naming Conventions

### Files and Modules
- **Format**: `snake_case`
- **Examples**:
  - `intent_agent.py`
  - `gemini_service.py`
  - `whatsapp_handler.py`
  - `expense_model.py`

### Classes
- **Format**: `PascalCase`
- **Examples**:
  ```python
  class IntentRecognitionAgent:
      pass

  class ExpenseModel:
      pass

  class WhatsAppWebhookHandler:
      pass
  ```

### Functions and Methods
- **Format**: `snake_case`
- **Examples**:
  ```python
  async def process_whatsapp_message():
      pass

  def calculate_monthly_summary():
      pass

  async def transcribe_audio():
      pass
  ```

### Variables
- **Format**: `snake_case`
- **Examples**:
  ```python
  user_message = "I spent $10"
  intent_result = await analyze_intent(user_message)
  expense_data = extract_entities(user_message)
  ```

### Constants
- **Format**: `UPPER_SNAKE_CASE`
- **Examples**:
  ```python
  DEFAULT_CURRENCY = "USD"
  MAX_RETRIES = 3
  SPREADSHEET_ID = "abc123"
  GEMINI_MODEL_NAME = "gemini-pro"
  ```

### Private Methods
- **Format**: `_snake_case` (single underscore prefix)
- **Examples**:
  ```python
  def _build_prompt(self, text: str) -> str:
      pass

  async def _call_gemini_api(self, prompt: str) -> str:
      pass
  ```

## Type Hints

**Rule**: All function signatures MUST include type hints for parameters and return values.

### Basic Types
```python
def add_numbers(a: int, b: int) -> int:
    return a + b

async def fetch_data(url: str) -> dict:
    response = await httpx.get(url)
    return response.json()
```

### Complex Types
```python
from typing import Optional, List, Dict, Union, Tuple

def process_expenses(
    expenses: List[ExpenseModel],
    filters: Optional[Dict[str, str]] = None
) -> Tuple[float, int]:
    total = sum(e.amount for e in expenses)
    count = len(expenses)
    return total, count

async def get_expense(
    expense_id: str
) -> Optional[ExpenseModel]:
    expense = await db.get(expense_id)
    return expense if expense else None
```

### Pydantic Models
```python
from pydantic import BaseModel, Field
from datetime import date

class ExpenseModel(BaseModel):
    amount: float = Field(gt=0, description="Expense amount")
    currency: str = Field(default="USD", max_length=3)
    category: str
    description: str = Field(max_length=500)
    date: date
    message_id: str

class IntentResult(BaseModel):
    intent: str
    confidence: float = Field(ge=0.0, le=1.0)
    context: Dict[str, str] = Field(default_factory=dict)
```

## Async/Await

**Rule**: ALL I/O operations MUST be async.

### API Calls
```python
import httpx

async def call_whatsapp_api(message: str) -> bool:
    async with httpx.AsyncClient() as client:
        response = await client.post(
            WHATSAPP_API_URL,
            json={"message": message}
        )
        return response.status_code == 200
```

### Database Operations
```python
async def add_expense_to_sheet(expense: ExpenseModel) -> None:
    await sheets_client.append(
        spreadsheet_id=SPREADSHEET_ID,
        range="MyExpenses!A:F",
        values=[[expense.date, expense.amount, expense.currency]]
    )
```

### Multiple Concurrent Operations
```python
import asyncio

async def process_batch(messages: List[str]) -> List[str]:
    tasks = [process_message(msg) for msg in messages]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    return results
```

### Agent Methods
```python
class IntentRecognitionAgent(Agent):
    async def analyze(self, text: str) -> IntentResult:
        prompt = self._build_prompt(text)
        response = await self.model.generate_content_async(prompt)
        return self._parse_response(response)
```

## Error Handling

### Basic Try-Except
```python
async def fetch_expense(expense_id: str) -> Optional[ExpenseModel]:
    try:
        result = await sheets_client.get_row(expense_id)
        return ExpenseModel(**result)
    except KeyError as e:
        logger.error(f"Missing field in expense data: {e}")
        return None
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
        return None
```

### Custom Exceptions
```python
class ExpenseError(Exception):
    """Base exception for expense operations"""
    pass

class InvalidAmountError(ExpenseError):
    """Raised when expense amount is invalid"""
    pass

class SheetNotFoundError(ExpenseError):
    """Raised when Google Sheet is not found"""
    pass

# Usage
def validate_amount(amount: float) -> None:
    if amount <= 0:
        raise InvalidAmountError(f"Amount must be positive, got {amount}")
```

### Retry Logic
```python
import tenacity

@tenacity.retry(
    stop=tenacity.stop_after_attempt(3),
    wait=tenacity.wait_exponential(multiplier=1, min=2, max=10),
    retry=tenacity.retry_if_exception_type(httpx.HTTPError)
)
async def call_gemini_with_retry(prompt: str) -> str:
    response = await gemini_client.generate_content_async(prompt)
    return response.text
```

## Logging

### Basic Logging
```python
import logging

logger = logging.getLogger(__name__)

async def process_message(message: str) -> str:
    logger.info(f"Processing message: {message[:50]}...")

    try:
        result = await analyze_message(message)
        logger.info(f"Analysis complete: intent={result.intent}")
        return result
    except Exception as e:
        logger.error(f"Error processing message: {e}", exc_info=True)
        raise
```

### Structured Logging
```python
import structlog

logger = structlog.get_logger()

async def add_expense(expense: ExpenseModel) -> None:
    logger.info(
        "adding_expense",
        amount=expense.amount,
        currency=expense.currency,
        category=expense.category
    )

    try:
        await sheets_client.append(expense)
        logger.info("expense_added_successfully", expense_id=expense.message_id)
    except Exception as e:
        logger.error(
            "expense_add_failed",
            error=str(e),
            expense_id=expense.message_id
        )
        raise
```

### Log Levels
```python
# DEBUG - Detailed information for debugging
logger.debug(f"Gemini prompt: {prompt}")

# INFO - General informational messages
logger.info("Webhook received", sender_id=sender_id)

# WARNING - Warning messages for potentially problematic situations
logger.warning("Low confidence intent", confidence=0.3)

# ERROR - Error messages
logger.error("Failed to add expense", exc_info=True)

# CRITICAL - Critical errors
logger.critical("Database connection lost")
```

## Docstrings

### Function Docstrings
```python
async def add_expense(
    expense: ExpenseModel,
    sheet_id: str
) -> PersistenceResult:
    """
    Add a new expense to Google Sheets.

    Args:
        expense: The expense data to add
        sheet_id: Google Sheets spreadsheet ID

    Returns:
        PersistenceResult with success status and message

    Raises:
        SheetNotFoundError: If the specified sheet doesn't exist
        InvalidAmountError: If expense amount is invalid

    Example:
        >>> expense = ExpenseModel(amount=10.0, currency="USD", ...)
        >>> result = await add_expense(expense, "abc123")
        >>> assert result.success
    """
    pass
```

### Class Docstrings
```python
class IntentRecognitionAgent(Agent):
    """
    Agent responsible for classifying user intent from messages.

    This agent uses Gemini to analyze natural language messages and
    determine the user's intent (add_expense, get_summary, etc.).

    Attributes:
        model: GenerativeModel instance for Gemini API
        confidence_threshold: Minimum confidence score for intent

    Example:
        >>> agent = IntentRecognitionAgent()
        >>> result = await agent.analyze("I spent $10 on coffee")
        >>> assert result.intent == "add_expense"
    """
    pass
```

### Module Docstrings
```python
"""
Intent Recognition Agent

This module implements the Intent Recognition Agent, which classifies
user messages into predefined intents using Gemini AI.

Supported intents:
- add_expense: User wants to log an expense
- get_monthly_summary: User wants a monthly summary
- get_category_summary: User wants category breakdown
- help: User needs assistance
- unknown: Intent cannot be determined
"""
```

## Code Organization

### Import Order
```python
# 1. Standard library imports
import os
import logging
from datetime import datetime, date
from typing import Optional, List, Dict

# 2. Third-party imports
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from google.adk import Agent
from google.generativeai import GenerativeModel

# 3. Local application imports
from app.models.expense import ExpenseModel
from app.services.gemini import GeminiService
from app.utils.auth import get_sheets_client
```

### Function Length
- Keep functions under 50 lines
- Extract complex logic into helper functions
- One function = one responsibility

```python
# BAD: Too long and complex
async def process_message(message):
    if message.is_voice:
        # 20 lines of audio processing
        pass
    # 30 lines of intent recognition
    # 40 lines of entity extraction
    # 30 lines of persistence
    # 20 lines of response generation

# GOOD: Broken into smaller functions
async def process_message(message: WhatsAppMessage) -> WhatsAppResponse:
    text = await _get_message_text(message)
    intent = await _recognize_intent(text)
    entities = await _extract_entities(text, intent)
    result = await _persist_data(entities, intent)
    response = await _generate_response(result, intent)
    return response
```

### File Organization
```python
# app/agents/intent_agent.py

"""Intent Recognition Agent implementation."""

import logging
from typing import Optional
from google.adk import Agent
from google.generativeai import GenerativeModel
from app.models.intent import IntentResult

logger = logging.getLogger(__name__)

# Constants at top
DEFAULT_MODEL = "gemini-pro"
CONFIDENCE_THRESHOLD = 0.5

# Main class
class IntentRecognitionAgent(Agent):
    """Agent for classifying user intent."""

    def __init__(self, model_name: str = DEFAULT_MODEL):
        """Initialize the intent recognition agent."""
        super().__init__(name="IntentRecognizer")
        self.model = GenerativeModel(model_name)

    # Public methods first
    async def analyze(self, text: str) -> IntentResult:
        """Analyze text and return intent."""
        pass

    # Private methods last
    def _build_prompt(self, text: str) -> str:
        """Build Gemini prompt for intent classification."""
        pass

    def _parse_response(self, response: str) -> IntentResult:
        """Parse Gemini response into IntentResult."""
        pass
```

## Testing Standards

### Test File Naming
```
tests/
├── test_agents/
│   ├── test_intent_agent.py
│   └── test_entity_agent.py
├── test_services/
│   └── test_gemini_service.py
└── test_api/
    └── test_webhooks.py
```

### Test Function Naming
```python
# Format: test_<what>_<condition>_<expected_result>

def test_intent_recognition_with_clear_expense_returns_add_expense():
    pass

def test_entity_extraction_with_missing_amount_raises_error():
    pass

def test_persistence_with_valid_expense_returns_success():
    pass
```

### Test Structure (AAA Pattern)
```python
import pytest
from app.agents.intent_agent import IntentRecognitionAgent

@pytest.mark.asyncio
async def test_intent_recognition_identifies_add_expense():
    # Arrange
    agent = IntentRecognitionAgent()
    message = "I spent $10 on coffee"

    # Act
    result = await agent.analyze(message)

    # Assert
    assert result.intent == "add_expense"
    assert result.confidence > 0.8
```

### Fixtures
```python
# tests/conftest.py
import pytest
from app.agents.intent_agent import IntentRecognitionAgent

@pytest.fixture
async def intent_agent():
    """Provide an IntentRecognitionAgent instance."""
    return IntentRecognitionAgent()

@pytest.fixture
def sample_expense():
    """Provide a sample ExpenseModel."""
    return ExpenseModel(
        amount=10.0,
        currency="USD",
        category="food",
        description="Coffee",
        date=date.today(),
        message_id="test123"
    )
```

## Code Comments

### When to Comment
```python
# GOOD: Explain WHY, not WHAT
# Use exponential backoff to avoid rate limiting
await asyncio.sleep(2 ** attempt)

# Gemini sometimes returns markdown code blocks, strip them
response_text = response.text.strip("```json").strip("```")

# BAD: Obvious comments
# Increment counter
counter += 1

# Call the API
await api.call()
```

### TODO Comments
```python
# TODO(username): Add support for multiple currencies
# TODO(username): Implement caching for Gemini responses
# FIXME(username): Handle edge case when date is in future
# HACK(username): Temporary workaround until Gemini API is fixed
```

## Performance Best Practices

### Avoid Blocking Operations
```python
# BAD: Blocking
import time
time.sleep(5)  # Blocks entire event loop

# GOOD: Non-blocking
import asyncio
await asyncio.sleep(5)  # Allows other tasks to run
```

### Batch Operations
```python
# BAD: One at a time
for expense in expenses:
    await add_expense_to_sheet(expense)  # N API calls

# GOOD: Batch
await add_expenses_batch(expenses)  # 1 API call
```

### Use Connection Pooling
```python
# Use httpx AsyncClient with connection pooling
async with httpx.AsyncClient(
    timeout=30.0,
    limits=httpx.Limits(max_connections=100, max_keepalive_connections=20)
) as client:
    response = await client.post(url, json=data)
```

## Security Best Practices

### Never Hardcode Secrets
```python
# BAD
GEMINI_API_KEY = "sk-abc123..."

# GOOD
from app.utils.config import get_secret
GEMINI_API_KEY = await get_secret("GEMINI_API_KEY")
```

### Input Validation
```python
from pydantic import BaseModel, Field, validator

class ExpenseInput(BaseModel):
    amount: float = Field(gt=0, le=1000000)
    description: str = Field(max_length=500)

    @validator('description')
    def sanitize_description(cls, v):
        # Remove potentially harmful characters
        return v.replace('<', '').replace('>', '')
```

### SQL Injection Prevention (if using DB)
```python
# BAD
query = f"SELECT * FROM expenses WHERE id = {user_input}"

# GOOD
query = "SELECT * FROM expenses WHERE id = ?"
await db.execute(query, (user_input,))
```

## UV Package Manager Commands

```bash
# Add a new dependency
uv add fastapi

# Add development dependency
uv add --dev pytest

# Remove dependency
uv remove package-name

# Sync dependencies
uv sync

# Run command in UV environment
uv run uvicorn main:app --reload

# Run tests
uv run pytest

# Run linting
uv run ruff check .

# Run formatting
uv run black .
```

## Pre-commit Hooks

Create `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: local
    hooks:
      - id: ruff
        name: ruff
        entry: uv run ruff check --fix
        language: system
        types: [python]

      - id: black
        name: black
        entry: uv run black
        language: system
        types: [python]

      - id: mypy
        name: mypy
        entry: uv run mypy
        language: system
        types: [python]
```

Install hooks:
```bash
uv add --dev pre-commit
uv run pre-commit install
```
