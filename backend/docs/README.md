# Documentation

- `docs/monitoring-sequence.puml`: PlantUML sequence diagram showing how manual triggers and scheduled runs flow through FastAPI, ConfigService, MonitorService, APScheduler, and Facebook Graph API.

Render locally with PlantUML (requires Java):
```bash
plantuml docs/monitoring-sequence.puml
```
or use a PlantUML-capable editor/extension to preview.

## API quick reference (multi-page per user)

All endpoints require `Authorization: Bearer <token>` and a `page_id` query param to scope config/rules/monitoring to a Facebook Page. The `page_id` query must match the `pageId` field in payloads.

- `POST /api/auth/token` (form fields `username`, `password`) → `{access_token, token_type, theme_mode}`
- `GET /api/config?page_id={PAGE_ID}` → returns config for that user/page
- `POST /api/config?page_id={PAGE_ID}` → body `Config` (includes `pageId`)
- `GET /api/rules?page_id={PAGE_ID}` → list rules for that page
- `POST /api/rules?page_id={PAGE_ID}` → body `{ "<reel_id>": Rule, ... }`
- `POST /api/trigger-monitoring?page_id={PAGE_ID}` → run monitor once in background
- `GET/POST /api/monitoring/enabled?page_id={PAGE_ID}` → get/set monitoring toggle
- `GET/POST /api/monitoring/interval?page_id={PAGE_ID}` → get/set interval seconds for that page
- `GET /api/monitoring/status?page_id={PAGE_ID}` → status for that user/page job
- Data fetch helpers (page scoped via config): `/api/user-info`, `/api/reels`, `/api/posts`, `/api/comments/{reel_id}`, `/api/reply`, `/api/send-private-reply`, `/api/test-connection`

### Example per-page workflow (frontend/dev)

1) Authenticate:
```bash
TOKEN=$(curl -s -X POST "http://localhost:8000/api/auth/token" \
  -d "username=alice&password=supersecret" | jq -r .access_token)
```

2) Save config for a page:
```bash
curl -X POST "http://localhost:8000/api/config?page_id=123PAGE" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"accessToken":"FB_TOKEN","pageId":"123PAGE","version":"v20.0","useMockData":false}'
```

3) Save rules for that page:
```bash
curl -X POST "http://localhost:8000/api/rules?page_id=123PAGE" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"reel123":{"object_id":"reel123","match_words":["hi"],"reply_message":"Hello","enabled":true}}'
```

4) Enable monitoring and set interval for that page:
```bash
curl -X POST "http://localhost:8000/api/monitoring/enabled?page_id=123PAGE" \
  -H "Authorization: Bearer $TOKEN" -d "true"

curl -X POST "http://localhost:8000/api/monitoring/interval?page_id=123PAGE" \
  -H "Authorization: Bearer $TOKEN" -d "300"
```

5) Trigger a manual cycle:
```bash
curl -X POST "http://localhost:8000/api/trigger-monitoring?page_id=123PAGE" \
  -H "Authorization: Bearer $TOKEN"
```
