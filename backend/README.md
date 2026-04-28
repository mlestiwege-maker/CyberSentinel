# CyberSentinel Backend (Phase 2)

FastAPI backend for intelligent cyberattack detection, live monitoring, and alert streaming.

## Features

- Network traffic ingestion endpoint with anomaly scoring
- Alert generation and classification (Critical/High/Medium/Low)
- REST API for dashboard summary, alerts, metrics, and reports
- Real-time WebSocket stream for frontend updates
- Notification hooks (email/push simulation)

## Run Locally

1. Create and activate a Python virtual environment.
2. Install dependencies from `requirements.txt`.
3. Start server:
   - `uvicorn app.main:app --reload --port 8000`

Backend root: `cybersentinel_backend/`

## API Contract

- `GET /health`
- `GET /api/v1/summary`
- `GET /api/v1/alerts?severity=&status=&q=&limit=`
- `GET /api/v1/metrics/recent?limit=`
- `GET /api/v1/reports/weekly`
- `POST /api/v1/ingest`
- `POST /api/v1/notifications/test`
- `WS /api/v1/stream`

## Notes

- Uses `.env` for thresholds and notification placeholders.
- In `development`, synthetic telemetry is generated continuously.