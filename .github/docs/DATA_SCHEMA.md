# Data Schema & API Specifications

## Google Sheets Schema

### Sheet: `MyExpenses`

| Column | Data Type | Format | Required | Description | Example |
|--------|-----------|--------|----------|-------------|---------|
| Date | Date | YYYY-MM-DD | Yes | Transaction date | 2025-11-04 |
| Amount | Number | Decimal | Yes | Expense amount | 5.00 |
| Currency | String | ISO 4217 | Yes | Currency code (3 chars) | USD, CLP, EUR |
| Category | String | Lowercase | Yes | Expense category | food, transport |
| Description | String | Free text | Yes | Expense details | Coffee at Starbucks |
| WhatsApp Message ID | String | wamid.* | Yes | Message tracking ID | wamid.HBgLM... |

### Supported Categories
- `food` - Meals, groceries, restaurants
- `transport` - Public transport, gas, parking, rideshares
- `entertainment` - Movies, concerts, subscriptions, hobbies
- `shopping` - Clothing, electronics, household items
- `utilities` - Electricity, water, internet, phone
- `health` - Medical, pharmacy, fitness
- `other` - Miscellaneous expenses

### Sheet Configuration
- **Name**: `MyExpenses` (case-sensitive)
- **Header Row**: Row 1 contains column names
- **Data Rows**: Start from row 2
- **Permissions**: App service account must have Editor access

### Example Sheet Data
```
Date         | Amount | Currency | Category      | Description           | WhatsApp Message ID
2025-11-04   | 5.00   | USD      | food          | Coffee at Starbucks   | wamid.HBgLMzI...
2025-11-04   | 15.50  | USD      | transport     | Uber to work          | wamid.HBgLMzI...
2025-11-03   | 50.00  | USD      | shopping      | New shoes             | wamid.HBgLMzI...
```

---

## Pydantic Models

### ExpenseModel
```python
from pydantic import BaseModel, Field, validator
from datetime import date
from typing import Optional

class ExpenseModel(BaseModel):
    """Model for a single expense entry."""

    amount: float = Field(
        gt=0,
        le=1000000,
        description="Expense amount (must be positive)"
    )
    currency: str = Field(
        default="USD",
        min_length=3,
        max_length=3,
        description="ISO 4217 currency code"
    )
    category: str = Field(
        description="Expense category (food, transport, etc.)"
    )
    description: str = Field(
        max_length=500,
        description="Brief description of the expense"
    )
    date: date = Field(
        default_factory=date.today,
        description="Date of the expense"
    )
    message_id: str = Field(
        description="WhatsApp message ID for tracking"
    )

    @validator('currency')
    def validate_currency(cls, v):
        v = v.upper()
        if v not in ['USD', 'CLP', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD']:
            raise ValueError(f"Unsupported currency: {v}")
        return v

    @validator('category')
    def validate_category(cls, v):
        v = v.lower()
        valid_categories = ['food', 'transport', 'entertainment', 'shopping',
                           'utilities', 'health', 'other']
        if v not in valid_categories:
            return 'other'  # Default to 'other' for unknown categories
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "amount": 5.00,
                "currency": "USD",
                "category": "food",
                "description": "Coffee at Starbucks",
                "date": "2025-11-04",
                "message_id": "wamid.HBgLMzI..."
            }
        }
```

### QueryModel
```python
from pydantic import BaseModel, Field
from datetime import date
from typing import Optional

class QueryModel(BaseModel):
    """Model for expense query parameters."""

    period: str = Field(
        default="month",
        description="Query period: month, week, year, custom"
    )
    category: Optional[str] = Field(
        default=None,
        description="Filter by category"
    )
    start_date: Optional[date] = Field(
        default=None,
        description="Start date for custom period"
    )
    end_date: Optional[date] = Field(
        default=None,
        description="End date for custom period"
    )

    @validator('period')
    def validate_period(cls, v):
        valid_periods = ['month', 'week', 'year', 'custom']
        if v not in valid_periods:
            raise ValueError(f"Invalid period: {v}")
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "period": "month",
                "category": "food",
                "start_date": "2025-11-01",
                "end_date": "2025-11-30"
            }
        }
```

### IntentResult
```python
from pydantic import BaseModel, Field
from typing import Dict

class IntentResult(BaseModel):
    """Result from intent recognition agent."""

    intent: str = Field(
        description="Recognized intent"
    )
    confidence: float = Field(
        ge=0.0,
        le=1.0,
        description="Confidence score (0.0 to 1.0)"
    )
    context: Dict[str, str] = Field(
        default_factory=dict,
        description="Additional context from analysis"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "intent": "add_expense",
                "confidence": 0.95,
                "context": {"reasoning": "User mentioned amount and item"}
            }
        }
```

### PersistenceResult
```python
from pydantic import BaseModel, Field
from typing import Optional, Dict

class PersistenceResult(BaseModel):
    """Result from data persistence operations."""

    success: bool = Field(
        description="Whether operation succeeded"
    )
    message: str = Field(
        description="Success or error message"
    )
    data: Optional[Dict] = Field(
        default=None,
        description="Additional data (e.g., query results)"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "message": "Expense added successfully",
                "data": {"row_number": 42}
            }
        }
```

### SummaryResult
```python
from pydantic import BaseModel, Field
from typing import Dict

class SummaryResult(BaseModel):
    """Result from summary calculations."""

    total_amount: float = Field(
        description="Total amount for period"
    )
    currency: str = Field(
        description="Currency of total"
    )
    count: int = Field(
        ge=0,
        description="Number of expenses"
    )
    breakdown: Dict[str, float] = Field(
        description="Amount by category"
    )
    period: str = Field(
        description="Summary period"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "total_amount": 450.50,
                "currency": "USD",
                "count": 23,
                "breakdown": {
                    "food": 180.00,
                    "transport": 120.00,
                    "entertainment": 90.50,
                    "shopping": 60.00
                },
                "period": "November 2025"
            }
        }
```

---

## API Endpoints

### POST /webhook
WhatsApp message webhook endpoint.

**Request Body** (from WhatsApp provider):
```json
{
  "object": "whatsapp_business_account",
  "entry": [{
    "id": "PHONE_NUMBER_ID",
    "changes": [{
      "value": {
        "messaging_product": "whatsapp",
        "metadata": {
          "display_phone_number": "16505551234",
          "phone_number_id": "PHONE_NUMBER_ID"
        },
        "messages": [{
          "from": "16505551234",
          "id": "wamid.HBgLMzI...",
          "timestamp": "1699027200",
          "type": "text",
          "text": {
            "body": "I spent $10 on coffee"
          }
        }]
      }
    }]
  }]
}
```

**Voice Message Request**:
```json
{
  "messages": [{
    "from": "16505551234",
    "id": "wamid.HBgLMzI...",
    "timestamp": "1699027200",
    "type": "audio",
    "audio": {
      "mime_type": "audio/ogg; codecs=opus",
      "sha256": "abc123...",
      "id": "AUDIO_ID",
      "voice": true
    }
  }]
}
```

**Response** (200 OK):
```json
{
  "success": true
}
```

**Implementation**:
```python
from fastapi import APIRouter, HTTPException, Request
from app.models.whatsapp import WhatsAppWebhook
from app.orchestrator import AgentOrchestrator

router = APIRouter()
orchestrator = AgentOrchestrator()

@router.post("/webhook")
async def whatsapp_webhook(webhook: WhatsAppWebhook):
    """
    Handle incoming WhatsApp messages.

    This endpoint receives messages from WhatsApp Business API,
    processes them through the agent pipeline, and sends responses.
    """
    try:
        # Extract message from webhook payload
        message = webhook.entry[0].changes[0].value.messages[0]

        # Process message asynchronously
        response = await orchestrator.process_message(message)

        # Send response back to WhatsApp
        await whatsapp_service.send_message(
            to=message.from_,
            text=response.text
        )

        return {"success": True}

    except Exception as e:
        logger.error(f"Webhook error: {e}", exc_info=True)
        # Still return 200 to acknowledge receipt
        return {"success": False, "error": str(e)}
```

---

### GET /webhook
WhatsApp webhook verification endpoint.

**Query Parameters**:
- `hub.mode`: "subscribe"
- `hub.verify_token`: Verification token (configured in WhatsApp)
- `hub.challenge`: Challenge string to return

**Response** (200 OK):
```
{hub.challenge value}
```

**Implementation**:
```python
@router.get("/webhook")
async def verify_webhook(
    request: Request,
    hub_mode: str = Query(alias="hub.mode"),
    hub_verify_token: str = Query(alias="hub.verify_token"),
    hub_challenge: str = Query(alias="hub.challenge")
):
    """
    Verify WhatsApp webhook subscription.

    This endpoint is called by WhatsApp to verify webhook ownership.
    """
    verify_token = os.getenv("WHATSAPP_WEBHOOK_VERIFY_TOKEN")

    if hub_mode == "subscribe" and hub_verify_token == verify_token:
        return int(hub_challenge)
    else:
        raise HTTPException(status_code=403, detail="Verification failed")
```

---

### GET /health
Health check endpoint.

**Response** (200 OK):
```json
{
  "status": "healthy",
  "timestamp": "2025-11-04T12:00:00Z",
  "services": {
    "gemini": "connected",
    "sheets": "connected",
    "whatsapp": "connected"
  }
}
```

**Implementation**:
```python
@router.get("/health")
async def health_check():
    """
    Health check endpoint for monitoring.

    Returns service status and connectivity to external services.
    """
    from datetime import datetime

    # Check external service connectivity
    services = {
        "gemini": await check_gemini_connection(),
        "sheets": await check_sheets_connection(),
        "whatsapp": "not_checked"  # Optional
    }

    all_healthy = all(s == "connected" for s in services.values() if s != "not_checked")

    return {
        "status": "healthy" if all_healthy else "degraded",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "services": services
    }
```

---

## Environment Variables

### Required
- `GCP_PROJECT_ID`: Google Cloud project ID
- `SPREADSHEET_ID`: Google Sheets document ID
- `WHATSAPP_WEBHOOK_VERIFY_TOKEN`: Token for webhook verification

### Secret Manager (Retrieved at Runtime)
- `WHATSAPP_API_KEY`: WhatsApp Business API credentials
- `GEMINI_API_KEY`: Google Gemini API key
- `GOOGLE_CLIENT_ID`: OAuth 2.0 client ID
- `GOOGLE_CLIENT_SECRET`: OAuth 2.0 client secret
- `GOOGLE_REFRESH_TOKEN`: OAuth 2.0 refresh token

### Optional
- `ENVIRONMENT`: Environment name (dev, prod)
- `LOG_LEVEL`: Logging level (DEBUG, INFO, WARNING, ERROR)
- `GEMINI_MODEL`: Gemini model name (default: gemini-pro)

---

## Error Responses

### Standard Error Format
```json
{
  "error": {
    "code": "INTENT_RECOGNITION_FAILED",
    "message": "Could not determine intent from message",
    "details": {
      "confidence": 0.3,
      "threshold": 0.5
    }
  }
}
```

### Common Error Codes
- `INTENT_RECOGNITION_FAILED`: Intent confidence too low
- `ENTITY_EXTRACTION_FAILED`: Could not extract required entities
- `PERSISTENCE_FAILED`: Error writing to Google Sheets
- `GEMINI_API_ERROR`: Gemini API call failed
- `SHEETS_API_ERROR`: Google Sheets API call failed
- `INVALID_MESSAGE_FORMAT`: WhatsApp message format invalid
- `RATE_LIMIT_EXCEEDED`: Too many requests

---

## WebSocket Support (Future)

For real-time updates, consider adding WebSocket support:

```python
from fastapi import WebSocket

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_json()
            response = await process_message(data)
            await websocket.send_json(response)
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        await websocket.close()
```
