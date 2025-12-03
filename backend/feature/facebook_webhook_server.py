"""
Standalone Facebook webhook test server.

Usage:
  - Set environment variables FB_VERIFY_TOKEN and FB_APP_SECRET (optional for dev)
  - Run with: python -m uvicorn facebook_webhook_server:app --host 0.0.0.0 --port 80

This file is intentionally standalone so you can test the webhook on an EC2 Ubuntu
instance without integrating into the main app.
"""
from fastapi import FastAPI, Request, HTTPException, status
from fastapi.responses import PlainTextResponse, JSONResponse
import os
import hmac
import hashlib
import logging

logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"))
logger = logging.getLogger("facebook_webhook_server")

FB_VERIFY_TOKEN = os.environ.get("FB_VERIFY_TOKEN", "test_verify_token")
FB_APP_SECRET = os.environ.get("FB_APP_SECRET", "")

app = FastAPI(title="Facebook Webhook Test Server")


@app.get("/webhook")
def verify_webhook(request: Request):
    # Read raw query params so we support keys like 'hub.mode' that Facebook sends.
    q = request.query_params
    # Facebook sends hub.mode, hub.verify_token, hub.challenge. Accept plain names too.
    mode = q.get("hub.mode") or q.get("mode")
    verify_token = q.get("hub.verify_token") or q.get("verify_token")
    challenge = q.get("hub.challenge") or q.get("challenge")

    # Verbose debug logging: show headers, client address, and query params
    try:
        logger.info("Incoming GET from=%s headers=%s query=%s", request.client, dict(request.headers), dict(q))
    except Exception:
        logger.exception("Failed to log GET request details")
    logger.info("Webhook verification request mode=%s verify_token=%s", mode, verify_token)

    # Per Meta docs: only accept when mode === 'subscribe' and the verify token matches
    if mode == "subscribe" and verify_token == FB_VERIFY_TOKEN:
        logger.info("WEBHOOK_VERIFIED")
        return PlainTextResponse(content=challenge or "", status_code=200)

    logger.warning("Webhook verification failed: mode=%s verify_token=%s", mode, verify_token)
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Verification token mismatch")


def _validate_signature(raw_body: bytes, signature_header: str | None) -> bool:
    if not FB_APP_SECRET:
        logger.warning("FB_APP_SECRET not set; skipping signature validation (dev mode)")
        return True

    if not signature_header:
        logger.warning("Missing X-Hub-Signature header")
        return False

    try:
        method, signature = signature_header.split("=", 1)
    except Exception:
        return False

    secret = FB_APP_SECRET.encode("utf-8")
    if method.lower() == "sha1":
        mac = hmac.new(secret, msg=raw_body, digestmod=hashlib.sha1)
    elif method.lower() == "sha256":
        mac = hmac.new(secret, msg=raw_body, digestmod=hashlib.sha256)
    else:
        return False

    expected = mac.hexdigest()
    return hmac.compare_digest(expected, signature)


@app.post("/webhook")
async def handle_webhook(request: Request):
    # Verbose debug logging: show headers and client address
    try:
        logger.info("Incoming POST from=%s headers=%s", request.client, dict(request.headers))
    except Exception:
        logger.exception("Failed to log POST request headers")

    raw = await request.body()
    try:
        logger.info("Raw body (bytes) length=%d", len(raw))
        # log a truncated preview to avoid huge logs
        preview = raw[:1000].decode('utf-8', errors='replace')
        logger.info("Raw body preview: %s", preview)
    except Exception:
        logger.exception("Failed to log raw request body")
    signature = request.headers.get("X-Hub-Signature") or request.headers.get("X-Hub-Signature-256")

    if not _validate_signature(raw, signature):
        logger.warning("Signature validation failed")
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid signature")

    try:
        data = await request.json()
    except Exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid JSON")

    # Log payload for testing. In production, you'd process events here.
    logger.info("Received webhook event (parsed JSON): %s", data)

    # Facebook expects a 200 OK quickly; return a short JSON ack
    return JSONResponse({"status": "ok"})


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", "80"))
    host = os.environ.get("HOST", "0.0.0.0")
    logger.info("Starting Facebook webhook test server on %s:%s", host, port)
    uvicorn.run("facebook_webhook_server:app", host=host, port=port, log_level="info")