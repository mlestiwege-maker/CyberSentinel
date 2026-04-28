# CyberSentinel

A comprehensive, real-time cybersecurity threat detection and incident response platform featuring a dark-themed SOC (Security Operations Center) dashboard, advanced threat modeling, and multi-channel alerting.

**Live Branches:**
- `main` — production-ready monorepo (frontend + backend)
- `backend-main` — backend-only development branch
- `monorepo-backend-merge` — merge PR reference

---

## 📦 Project Structure

```
CyberSentinel/
├── lib/                           # Flutter frontend (Dart)
│   ├── main.dart
│   ├── screens/                   # Dashboard, terminal, alerts, incidents, reports, monitoring, settings
│   ├── widgets/                   # Reusable UI components (shell, drawer, KPI strip, graphs, tables)
│   └── data/                      # API clients, threat feed service, auth/incident data models
├── backend/                       # FastAPI backend (Python)
│   ├── app/
│   │   ├── main.py                # FastAPI app with auth, RBAC, threat detection
│   │   ├── config.py              # Environment settings
│   │   ├── models.py              # Pydantic data models
│   │   ├── services/              # Auth, notifications, packet sniffing, threat modeling, DLQ, resilience
│   │   └── models/                # ML threat model artifacts
│   ├── tests/                     # Comprehensive unit tests (auth, features, DLQ, idempotency, notifications)
│   └── requirements.txt           # Python dependencies
├── pubspec.yaml                   # Flutter dependencies
├── android/, ios/, linux/, windows/, web/  # Platform-specific build configs
└── test/                          # Flutter widget tests

```

---

## 🎯 Key Features

### Frontend (Flutter)
- **Dark SOC Dashboard** — Real-time threat feeds, incident overview, attack map, system resources
- **Operational Terminal** — Command-based threat operations (drills, packet capture, ML tuning)
- **Multi-screen UI** — Alerts, incidents, reports, monitoring, settings with unified navigation
- **Responsive Design** — Works on desktop (Linux, macOS, Windows), web, iOS, Android
- **Theme Support** — Light/dark theme toggle with optimized contrast

### Backend (FastAPI)
- **JWT Authentication & RBAC** — Role-based access control (admin, analyst, responder)
- **Real-time Threat Detection** — ML-powered anomaly detection with configurable thresholds
- **Multi-channel Notifications** — Email, SMS (Twilio), Slack, Teams, Firebase Cloud Messaging, system alerts
- **Packet Sniffing & Feature Extraction** — Network-level threat detection
- **Dead-Letter Queue (DLQ) & Idempotency** — Resilient event processing
- **Circuit Breaker & Stats Collector** — Health monitoring and resilience metrics
- **Incident Response Workflows** — Playbooks, assignment, status tracking

---

## 🚀 Quick Start

### Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate  # or: venv\Scripts\activate (Windows)
pip install -r requirements.txt
```

**Configure `.env`:**
```bash
cp .env .env.local
# Edit .env.local with your settings:
# - SMTP credentials for email alerts
# - Twilio SID/token for SMS
# - Firebase project ID for push notifications
# - Auth secrets and role passwords
```

**Run the backend:**
```bash
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Backend API docs: http://localhost:8000/docs

### Frontend Setup

```bash
pub get
flutter pub get
```

**Run Flutter:**
```bash
# Web
flutter run -d web

# Linux desktop
flutter run -d linux

# macOS
flutter run -d macos

# iOS
flutter run -d ios

# Android
flutter run -d android
```

---

## 🧪 Testing

### Backend Tests

```bash
cd backend
pytest tests/ -v
```

Tests cover:
- Authentication and RBAC
- Notification channels (email, SMS, Slack, Teams, FCM)
- Packet feature extraction
- Dead-letter queue recovery
- Event idempotency

### Frontend Tests

```bash
flutter test
```

Widget tests validate:
- App navigation and routing
- Dashboard panels and KPI display
- Threat feed updates
- Terminal command handling

---

## 🔧 Configuration

### Backend Environment (`.env`)

```env
# App
APP_NAME=CyberSentinel Backend
APP_ENV=development
SIMULATION_ENABLED=true

# Threat Detection Thresholds
ALERT_ANOMALY_THRESHOLD=0.78
ALERT_CRITICAL_THRESHOLD=0.90

# Notifications
NOTIFY_EMAIL=security-admin@example.com
NOTIFY_PHONE=
NOTIFY_PUSH_TOPIC=cybersentinel-alerts

# SMTP (Email)
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=

# Twilio (SMS)
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_FROM_NUMBER=

# Firebase (Push)
FIREBASE_CREDENTIALS_PATH=
FIREBASE_PROJECT_ID=cybersentinel-3dd13

# Auth / RBAC
AUTH_ENFORCED=true
AUTH_SECRET_KEY=change-me-in-env
AUTH_ADMIN_PASSWORD=admin123
AUTH_RESPONDER_PASSWORD=responder123
AUTH_ANALYST_PASSWORD=analyst123
```

### Frontend Configuration

Theme and API base URL are configurable in `lib/main.dart`:
```dart
// API_BASE_URL defaults to http://localhost:8000
// Theme defaults to dark; toggle via settings screen
```

---

## 📱 Deployment

### Docker (Backend)

```bash
cd backend
docker build -t cybersentinel-backend .
docker run -p 8000:8000 --env-file .env cybersentinel-backend
```

### Flutter Web Build

```bash
flutter build web --release
# Deploy contents of build/web to your hosting
```

### Linux Desktop Build

```bash
flutter build linux --release
# Outputs to build/linux/x64/release/bundle/
```

---

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      CyberSentinel App                       │
│  (Flutter: Desktop, Web, Mobile)                             │
└──────────────────────┬──────────────────────────────────────┘
                       │ HTTP/REST
┌──────────────────────▼──────────────────────────────────────┐
│                  FastAPI Backend                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Auth Service (JWT, RBAC) → Feature Extractor           │ │
│  │ Threat Engine (ML) → Incident Response Workflows       │ │
│  │ Notification Service (Multi-Channel)                   │ │
│  │ Packet Sniffer → Resilience Collector & DLQ Recovery   │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security & Compliance

- **Sanitized Credentials** — `.env` does not include live secrets
- **Git Ignore** — Python cache (`__pycache__/`), venv, logs automatically excluded
- **JWT + RBAC** — All API endpoints protected by role-based access
- **Notification Anti-Spam** — Cooldown and deduplication on alert channels
- **Input Validation** — Pydantic models for strict API contract enforcement

---

## 📝 License

Your organization's license here.

---

## 🤝 Contributing

1. Create a branch: `git checkout -b feature/<name>`
2. Make changes and commit: `git commit -am "description"`
3. Push to remote: `git push origin feature/<name>`
4. Open a pull request against `main`

---

## 📞 Support & Feedback

For issues, questions, or feature requests, please open a GitHub issue or contact the development team.

---

**Last Updated:** 28 April 2026  
**Status:** Production-ready monorepo with integrated frontend + backend threat detection platform.
	- Automatically falls back to simulated telemetry if backend is unreachable.
	- Uses WebSocket-first live updates with periodic REST reconciliation to reduce backend load.
	- Exposes connection health and last-sync timestamps for operational visibility.
  - Produces summary KPIs for all screens.
  - Supports deterministic test behavior (no periodic timers during test runs).

UI modules consume this service to represent near-real-time SOC behavior.

## Run Backend + Frontend (Desktop and Mobile)

### 1) Start backend

From `cybersentinel_backend`:

1. Activate your Python virtual environment.
2. Install dependencies from `requirements.txt`.
3. Start server:
	 - `uvicorn app.main:app --reload --port 8000`

### 2) Start frontend

From the `cybersentinel_frontend` folder:

1. `flutter pub get`
2. Run with backend URL for your target platform:
	 - **Desktop (Linux/macOS/Windows):** `http://127.0.0.1:8000`
	 - **Android emulator:** `http://10.0.2.2:8000`
	 - **iOS simulator:** `http://127.0.0.1:8000`

Example:

- `flutter run --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8000`

For a physical mobile device, use your machine LAN IP, e.g.:

- `flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.50:8000`

## Quality Checks

- Static analysis: `flutter analyze`
- Tests: `flutter test`

## Integrated Backend Contract

Current frontend integration uses:

- `GET /api/v1/summary`
- `GET /api/v1/alerts?severity=&status=&q=&limit=`
- `GET /api/v1/metrics/recent?limit=`
- `GET /api/v1/reports/weekly`
- `POST /api/v1/ingest`
- `WS /api/v1/stream`

## Notes for Deployment

- Keep CORS enabled on backend when using separate frontend host/device.
- For production, place backend behind HTTPS and use secure WebSocket (`wss`).
- Configure notification recipients/topics in backend `.env`.

## Performance and Reliability Behavior

- **Efficient sync loop**: frontend prioritizes WebSocket stream events and avoids excessive REST polling.
- **Automatic degradation mode**: if backend connectivity drops, UI switches to local simulation to keep dashboards responsive.
- **Connection observability**: Dashboard shows `Live Backend` vs `Fallback Simulation` plus the latest sync time.
- **Admin transport diagnostics**: Monitoring console exposes failure counters and circuit-breaker state to expert operators.

## Administrator-Focused UX

This system is designed for experienced security administrators:

- Dense alert context (ID, source, severity, status, confidence) for rapid triage.
- Direct operational controls to run controlled threat drills and verify notification channels.
- Real-time telemetry and backend-health visibility to support incident response decisions.

## Role Model and Access Behavior

- **Administrator role**
	- Can execute active operations: threat drills, notification tests, and force-sync actions.
	- Has full SOC operations console access.
- **Analyst role**
	- Read-focused mode for monitoring and triage.
	- Active operational controls are disabled to reduce accidental high-impact actions.

Role can be switched in `Settings` under **Frontend operating role**.

## Audit Timeline

- Monitoring includes an **Operations Audit Timeline** with key events:
	- Role changes
	- Manual sync attempts
	- Threat drill executions
	- Notification-channel tests
	- WebSocket/transport state events
- This provides lightweight accountability and visibility for expert SOC workflows.

## Project Value

CyberSentinel improves cybersecurity posture in financial institutions by enabling:

- Faster threat detection
- Reduced response time
- Better visibility for SOC administrators
- Stronger protection of transactions and customer data
