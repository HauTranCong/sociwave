Facebook webhook test server (ngrok-only)
=========================================

This README focuses on using ngrok to expose the local webhook server over HTTPS so
you can register and verify the callback URL in Facebook's developer console quickly.

Prerequisites
-------------
- A running instance of the webhook server (see `facebook_webhook_server.py`).
- Python venv (recommended) with fastapi and uvicorn installed.
- An ngrok account (free tier) — you must sign up and install an authtoken.

Install and run the server locally (example using port 8000)
---------------------------------------------------------
1) Create and activate venv (if you haven't already):

   python3 -m venv .venv
   source .venv/bin/activate

2) Install dependencies:

   python -m pip install --upgrade pip
   python -m pip install fastapi uvicorn

3) Run the server on port 8000 (no sudo):

   FB_VERIFY_TOKEN=test_verify_token FB_APP_SECRET= python -m uvicorn facebook_webhook_server:app --host 127.0.0.1 --port 8000

Get ngrok and configure your authtoken
-------------------------------------
1) Register at https://dashboard.ngrok.com/signup (if you don't have an account).
2) Copy your authtoken from https://dashboard.ngrok.com/get-started/your-authtoken
3) On your server, install ngrok and configure the token:

   wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
   unzip ngrok-stable-linux-amd64.zip
   sudo mv ngrok /usr/local/bin/
   ngrok authtoken <YOUR_NGROK_AUTHTOKEN>

Start the ngrok tunnel
----------------------
Run ngrok to expose port 8000 (change port if necessary):

   ngrok http 8000

ngrok will print status and forwardable URLs. Look for the HTTPS forwarding URL, e.g.
`https://abcd-1234.ngrok.io`.

Register the callback URL in Facebook
-----------------------------------
- In Facebook App Dashboard → Webhooks (or Messenger product → Webhooks) set the callback URL to:
  `https://<YOUR_NGROK_HOST>/webhook` (for example: `https://abcd-1234.ngrok.io/webhook`)
- Set the Verify Token to the same value you used when starting the server (`test_verify_token` or your chosen value).
- Click "Verify and Save" in the console. The server (running locally) should log the verification request and reply with the challenge.

Quick test commands
-------------------
- Verify (simulate Facebook GET):

  curl -v "https://<YOUR_NGROK_HOST>/webhook?hub.mode=subscribe&hub.verify_token=test_verify_token&hub.challenge=CHALLENGE"

- POST event (dev mode, no FB_APP_SECRET):

  curl -v -X POST "https://<YOUR_NGROK_HOST>/webhook" -H "Content-Type: application/json" \
    -d '{"object":"page","entry":[{"messaging":[{"message":"TEST_MESSAGE"}]}]}'

- POST event with HMAC signature (when FB_APP_SECRET is set):

  export FB_APP_SECRET='your_app_secret'
  payload='{"object":"page","entry":[{"messaging":[{"message":"TEST_MESSAGE"}]}]}'
  sig=$(printf '%s' "$payload" | openssl dgst -sha256 -hmac "$FB_APP_SECRET" | sed 's/^.* //')
  curl -v -X POST "https://<YOUR_NGROK_HOST>/webhook" -H "Content-Type: application/json" \
    -H "X-Hub-Signature-256: sha256=$sig" -d "$payload"

Logging and debugging
---------------------
- Run uvicorn in foreground to see logs directly. If you run it as a service, redirect stdout/stderr to a log file and tail it:

  sudo /home/ubuntu/webhook/.venv/bin/python -m uvicorn facebook_webhook_server:app --host 0.0.0.0 --port 8000 >> /tmp/webhook.log 2>&1 &
  tail -f /tmp/webhook.log

Notes / reminders
-----------------
- ngrok requires an account and authtoken for usage. The free tier is sufficient for quick tests.
- For production use, set up nginx + TLS and register a permanent domain with Facebook rather than ngrok.

If you want, I can:
- generate a one-shot script that installs ngrok, configures authtoken, starts a tunnel and prints the callback URL, or
- produce systemd + nginx files for a production setup when you're ready.
