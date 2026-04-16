# CyberSentinel Frontend (Flutter)

CyberSentinel is a desktop/mobile cyberattack detection and threat monitoring system designed for financial institutions.

## Problem Context

Zimbabwean financial institutions are rapidly digitizing (online banking, mobile banking, and electronic payments), increasing both operational efficiency and cyber risk. Traditional security systems often depend on fixed rules and known signatures, which are weak against evolving threats such as:

- Zero-day exploits
- Ransomware
- Distributed Denial of Service (DDoS)
- Advanced fraud and lateral movement patterns

This project focuses on a banking context (e.g., CBZ Bank Bindura Branch as a case-study environment) where fast and accurate cyber threat detection is critical.

## Aim

Develop a desktop and mobile-based Cyberattack Detection and Threat Monitoring System that uses intelligent techniques to monitor network traffic, detect anomalies in real time, and send actionable alerts to administrators.

## Objectives

1. Capture and preprocess network traffic from a simulated banking environment.
2. Apply machine learning/anomaly detection models to identify suspicious behavior.
3. Classify anomalies and generate real-time alerts.
4. Provide Flutter-based desktop and mobile dashboards for SOC monitoring.
5. Evaluate detection performance for known and emerging threats.

## Current Frontend Capabilities

The Flutter app now provides a SOC UI connected to the Phase 2 backend (REST + WebSocket), with simulation fallback when backend is unavailable:

- **Dashboard**: real-time KPIs, trend graph, and latest threat alerts.
- **Alerts**: searchable/filterable threat feed with details view.
- **Monitoring**: live packet/anomaly metric table for network visibility.
- **Reports, Incidents, Settings**: management and response workflow views.
- **Cross-platform UI**: responsive navigation for desktop and mobile layouts.
- **Expert admin workflow**: operations console for threat drills, notification-channel tests, and manual sync.

## Architecture (Implemented Frontend Layer)

The app includes a reusable live threat feed stack:

- `lib/data/backend_api_client.dart`
	- Handles backend REST requests for summary, alerts, and metrics.
	- Builds WebSocket stream URL.
	- Supports `--dart-define=BACKEND_BASE_URL=...` override.
	- Includes timeout/retry logic and circuit-breaker protection for resilient operations.

- `lib/data/threat_feed_service.dart`
	- Syncs with backend APIs and `/api/v1/stream` updates.
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
