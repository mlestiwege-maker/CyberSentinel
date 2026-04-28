# CyberSentinel Backend

FastAPI backend for intelligent cyberattack detection, live monitoring, alert streaming, and multi-channel notifications.

## 🎯 Features

- **Threat Detection** — ML-powered anomaly detection with configurable thresholds
- **Alert Management** — Real-time classification (Critical/High/Medium/Low) with severity scoring
- **Multi-Channel Notifications** — Email (SMTP), SMS (Twilio), Slack, Teams, FCM, system alerts
- **REST API** — Summary, alerts, metrics, reports, incident management
- **Real-time Streaming** — WebSocket `/api/v1/stream` for live dashboard updates
- **JWT + RBAC** — Role-based access control (admin, analyst, responder)
- **Packet Inspection** — Network traffic feature extraction and anomaly scoring
- **Dead-Letter Queue (DLQ)** — Resilient event processing with replay
- **Circuit Breaker** — Health monitoring and graceful degradation

---

## 📦 Quick Setup

### 1️⃣ Environment Setup

```bash
python -m venv venv
source venv/bin/activate  # or: venv\Scripts\activate (Windows)
pip install -r requirements.txt
```

### 2️⃣ Configure Email & SMS

**Interactive Configuration (Recommended):**
```bash
python configure_notifications.py
```

Or manually edit `.env`:

```env
# Email (SMTP)
NOTIFY_EMAIL=your-email@gmail.com
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=xxxx-xxxx-xxxx-xxxx  # Gmail App Password

# SMS (Twilio)
TWILIO_ACCOUNT_SID=AC...
TWILIO_AUTH_TOKEN=...
TWILIO_FROM_NUMBER=+1XXXXXXXXXX   # Your Twilio number
NOTIFY_PHONE=+1XXXXXXXXXX         # Recipient number
```

### 3️⃣ Start Backend

```bash
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**API Docs:** http://localhost:8000/docs

---

## 📧 Email Configuration (Gmail)

### Get Gmail App Password

1. Go to [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
2. Select: **Apps** → **Mail**, **Device** → **Other (custom name)**
3. Copy the 16-character password (remove spaces)
4. Paste into `SMTP_PASSWORD` in `.env`

```env
NOTIFY_EMAIL=your-email@gmail.com
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=xxxx xxxx xxxx xxxx
```

---

## 📱 SMS Configuration (Twilio)

### Get Twilio Credentials

1. **Sign up free:** https://www.twilio.com/console/sign-up
2. **Verify your phone number**
3. **From Twilio Console:**
   - Copy **Account SID** (AC followed by 32 chars)
   - Copy **Auth Token** (long string)
   - Get a **Twilio Phone Number** (free trial includes one)

```env
TWILIO_ACCOUNT_SID=AC1234567890abcdefghijklmnopqrst
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_FROM_NUMBER=+1234567890
NOTIFY_PHONE=+1234567890
```

---

## 🧪 Test Notifications

### Test All Channels

```bash
curl -X POST http://localhost:8000/api/v1/notifications/test \
  -H "Content-Type: application/json" \
  -d '{
    "channels": ["email", "sms", "slack", "teams", "push", "system"],
    "title": "CyberSentinel Test",
    "message": "Testing all notification channels"
  }'
```

### Test Specific Channel

```bash
# Email only
curl -X POST http://localhost:8000/api/v1/notifications/test \
  -H "Content-Type: application/json" \
  -d '{"channels": ["email"], "title": "Test", "message": "Email test"}'

# SMS only
curl -X POST http://localhost:8000/api/v1/notifications/test \
  -H "Content-Type: application/json" \
  -d '{"channels": ["sms"], "title": "Test", "message": "SMS test"}'
```

---

## 🔐 API Endpoints

### Authentication
- `POST /api/v1/auth/login` — Get JWT token
- `GET /api/v1/auth/profile` — Get user profile

### Threats & Alerts
- `GET /api/v1/summary` — Dashboard summary
- `GET /api/v1/alerts` — Query alerts
- `GET /api/v1/metrics/recent` — Network metrics
- `GET /api/v1/reports/weekly` — Weekly reports
- `POST /api/v1/ingest` — Submit threat data

### Notifications
- `POST /api/v1/notifications/test` — Test channels
- `POST /api/v1/notifications/send` — Send alert
- `POST /api/v1/notifications/channels/configure` — Configure channels

### Streaming
- `WS /api/v1/stream` — Real-time threat feed

### Incidents
- `GET /api/v1/incidents` — List incidents
- `POST /api/v1/incidents` — Create incident
- `GET /api/v1/incidents/{id}` — Get incident details

---

## 🧪 Run Tests

```bash
pytest tests/ -v

# Test specific service
pytest tests/test_notification_service_channels.py -v
pytest tests/test_auth_service.py -v
pytest tests/test_ingest_dlq.py -v
```

---

## 🐳 Docker Deployment

```bash
docker build -t cybersentinel-backend .
docker run -p 8000:8000 \
  --env-file .env \
  cybersentinel-backend
```

---

## 📋 Configuration Reference

| Variable | Purpose | Example |
|----------|---------|---------|
| `NOTIFY_EMAIL` | Alert recipient email | security@company.com |
| `SMTP_USERNAME` | SMTP account | your-email@gmail.com |
| `SMTP_PASSWORD` | SMTP app password | xxxx xxxx xxxx xxxx |
| `NOTIFY_PHONE` | SMS recipient | +12345678900 |
| `TWILIO_ACCOUNT_SID` | Twilio SID | AC... |
| `TWILIO_AUTH_TOKEN` | Twilio token | ... |
| `TWILIO_FROM_NUMBER` | Twilio phone | +12345678900 |
| `ALERT_ANOMALY_THRESHOLD` | Anomaly trigger | 0.78 |
| `ALERT_CRITICAL_THRESHOLD` | Critical threshold | 0.90 |
| `AUTH_ENFORCED` | Require JWT | true/false |

---

## 📝 License

Proprietary — CyberSentinel

---

## 🆘 Troubleshooting

### Email not sending?
- Check `SMTP_USERNAME` and `SMTP_PASSWORD` are correct
- Verify "Less secure app access" or use App Password (Gmail)
- Check firewall allows outbound port 587 (SMTP/TLS)

### SMS not working?
- Verify Twilio Account SID format (AC + 32 chars)
- Confirm phone numbers in E.164 format (+country code + number)
- Check Twilio account has credits/trial available
- Make sure `TWILIO_FROM_NUMBER` is verified in Twilio

### Test returns errors?
```bash
curl -v http://localhost:8000/api/v1/notifications/test
```
Check response for specific service error details.