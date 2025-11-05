"""
Financia - WhatsApp Expense Tracking API
FastAPI application for managing expenses via WhatsApp
"""

import os
from fastapi import FastAPI, Request, Query, HTTPException
from fastapi.responses import PlainTextResponse
import logging

# Configure logging
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Financia API",
    description="WhatsApp-based expense tracking application",
    version="0.1.0",
)


@app.get("/")
async def root():
    """Root endpoint - API information"""
    return {
        "name": "Financia API",
        "version": "0.1.0",
        "status": "running",
        "environment": os.getenv("ENVIRONMENT", "unknown"),
    }


@app.get("/health")
async def health_check():
    """
    Health check endpoint for Cloud Run startup/liveness probes
    Returns 200 OK if the service is healthy
    """
    return {
        "status": "healthy",
        "service": "financia-api",
        "environment": os.getenv("ENVIRONMENT", "unknown"),
    }


@app.get("/webhook")
async def verify_webhook(
    request: Request,
    hub_mode: str = Query(None, alias="hub.mode"),
    hub_verify_token: str = Query(None, alias="hub.verify_token"),
    hub_challenge: str = Query(None, alias="hub.challenge"),
):
    """
    WhatsApp webhook verification endpoint

    WhatsApp will call this endpoint to verify the webhook URL.
    We need to return the challenge string if the verify token matches.
    """
    logger.info(
        f"Webhook verification request: mode={hub_mode}, token_provided={bool(hub_verify_token)}"
    )

    # Get the configured verify token from environment
    expected_token = os.getenv("WHATSAPP_WEBHOOK_VERIFY_TOKEN")

    if not expected_token:
        logger.error("WHATSAPP_WEBHOOK_VERIFY_TOKEN not configured")
        raise HTTPException(status_code=500, detail="Webhook token not configured")

    # Verify the request
    if hub_mode == "subscribe" and hub_verify_token == expected_token:
        logger.info("Webhook verification successful")
        # Return the challenge as plain text
        return PlainTextResponse(content=hub_challenge, status_code=200)
    else:
        logger.warning(
            f"Webhook verification failed: mode={hub_mode}, token_match={hub_verify_token == expected_token}"
        )
        raise HTTPException(status_code=403, detail="Verification failed")


@app.post("/webhook")
async def receive_webhook(request: Request):
    """
    WhatsApp webhook endpoint for receiving messages

    This endpoint receives WhatsApp messages and processes them.
    For now, it's a placeholder that acknowledges receipt.
    """
    try:
        body = await request.json()
        logger.info(f"Received webhook: {body}")

        # TODO: Implement agent orchestration
        # 1. Extract message from webhook
        # 2. Process with intent recognition agent
        # 3. Extract entities
        # 4. Persist to Google Sheets
        # 5. Generate response
        # 6. Send back to WhatsApp

        return {"status": "received"}

    except Exception as e:
        logger.error(f"Error processing webhook: {e}", exc_info=True)
        # Still return 200 to acknowledge receipt
        return {"status": "error", "message": str(e)}


@app.get("/readiness")
async def readiness_check():
    """
    Readiness probe endpoint
    Returns 200 when the service is ready to accept traffic
    """
    # TODO: Add checks for:
    # - Secret Manager connectivity
    # - Google Sheets API connectivity
    # - Gemini API connectivity

    return {
        "status": "ready",
        "checks": {
            "api": "ok",
            "secrets": "not_checked",
            "sheets": "not_checked",
            "gemini": "not_checked",
        },
    }


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", 8080))

    logger.info(f"Starting Financia API on port {port}")

    uvicorn.run(
        app, host="0.0.0.0", port=port, log_level=os.getenv("LOG_LEVEL", "info").lower()
    )
