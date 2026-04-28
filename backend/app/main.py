from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
from datetime import datetime
import logging
import threading

from fastapi import FastAPI, Query, WebSocket, WebSocketDisconnect, Depends, HTTPException
import time
from starlette.middleware.base import BaseHTTPMiddleware
from fastapi import Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import settings
from app.models import (
    AuthLoginRequest,
    AuthProfileResponse,
    AuthTokenResponse,
    IngestResponse,
    MLFeatureImportanceResponse,
    MLModelInfo,
    MLModelVersionsResponse,
    MLPredictionResponse,
    MLSchedulerConfigRequest,
    MLSchedulerStatusResponse,
    MLSwitchVersionRequest,
    MLThresholdTuneRequest,
    MLThresholdTuneResponse,
    MLModelVersionInfo,
    MLTrainingRequest,
    MLTrainingResponse,
    NetworkMetric,
    NotificationChannelConfig,
    NotificationChannelsResponse,
    NotificationSendResponse,
    NotificationTestRequest,
    NotificationTestResponse,
    PacketCaptureResponse,
    PacketCaptureStartRequest,
    PacketCaptureStatus,
    ThreatAlert,
    ThreatSummary,
    TrafficEvent,
    WeeklyReport,
)
from app.services.auth_service import AuthPrincipal, AuthService
from app.services.notification_service import NotificationChannel, NotificationService
from app.services.packet_sniffer import get_sniffer
from app.services.feature_extractor import FeatureExtractor
from app.services.ingest_dlq import IngestDLQ
from app.services.ml_threat_model import get_threat_model
from app.services.stats_collector import ResilienceStatsCollector
from app.services.threat_engine import ThreatEngine
from app.services.simulation.attack_simulator import AttackSimulator
from app.services.incident_response import IncidentResponseWorkflow, IncidentStatus

engine = ThreatEngine()
stats_collector = ResilienceStatsCollector()
feature_extractor = FeatureExtractor()
incident_workflow = IncidentResponseWorkflow()
packet_sniffer = get_sniffer()
threat_model = get_threat_model()
ingest_dlq = IngestDLQ()
simulator = AttackSimulator(engine)
logger = logging.getLogger(__name__)

_ml_scheduler_task: asyncio.Task | None = None
_dlq_replay_task: asyncio.Task | None = None
_app_event_loop: asyncio.AbstractEventLoop | None = None
_ml_scheduler_state: dict[str, object] = {
    "enabled": False,
    "interval_seconds": 300,
    "training_events": 100,
    "is_running": False,
    "last_run": None,
    "last_status": "idle",
    "last_error": None,
}
_dlq_state: dict[str, object] = {
    "enabled": True,
    "interval_seconds": 6,
    "batch_size": 20,
    "is_running": False,
    "last_run": None,
    "last_status": "idle",
    "last_error": None,
    "last_replayed": 0,
}

_auth_bearer = HTTPBearer(auto_error=False)


async def get_current_principal(
    credentials: HTTPAuthorizationCredentials | None = Depends(_auth_bearer),
) -> AuthPrincipal:
    """Resolve current authenticated user (or dev fallback when auth is disabled)."""
    if not settings.auth_enforced:
        return AuthPrincipal(username=settings.auth_admin_username, role="admin")

    if credentials is None:
        raise HTTPException(status_code=401, detail="Missing bearer token")

    principal = AuthService.verify_token(credentials.credentials)
    if principal is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    return principal


def require_roles(allowed_roles: set[str]):
    async def _dependency(principal: AuthPrincipal = Depends(get_current_principal)) -> AuthPrincipal:
        if principal.role not in allowed_roles:
            raise HTTPException(status_code=403, detail="Insufficient role for this action")
        return principal

    return _dependency


@asynccontextmanager
async def lifespan(_: FastAPI):
    global _app_event_loop
    _app_event_loop = asyncio.get_running_loop()
    await engine.start()
    _start_ml_scheduler()
    _start_dlq_replay()
    yield
    await _stop_dlq_replay()
    await _stop_ml_scheduler()
    await engine.stop()
    _app_event_loop = None


async def _ingest_with_retry(event: TrafficEvent, retries: int = 2) -> None:
    """Ingest event with lightweight retries for transient failures."""
    for attempt in range(retries + 1):
        try:
            await engine.ingest(event)
            return
        except Exception as e:
            if attempt >= retries:
                logger.warning("Packet event ingest failed after %s attempts: %s", retries + 1, e)
                ingest_dlq.enqueue(event, reason=f"ingest_failed:{e}")
                return
            await asyncio.sleep(0.05 * (attempt + 1))


async def _replay_dlq_once() -> int:
    """Replay one DLQ batch and acknowledge successfully ingested records."""
    batch_size = int(_dlq_state.get("batch_size", 20))
    batch = ingest_dlq.peek_batch(limit=batch_size)
    if not batch:
        return 0

    ack_ids: set[str] = set()
    for record_id, event in batch:
        try:
            await engine.ingest(event)
            ack_ids.add(record_id)
        except Exception as e:
            logger.warning("DLQ replay ingest failed for record %s: %s", record_id, e)

    if ack_ids:
        ingest_dlq.ack(ack_ids)

    return len(ack_ids)


async def _dlq_replay_loop() -> None:
    """Background worker to replay persisted failed ingest events."""
    _dlq_state["is_running"] = True
    try:
        while True:
            await asyncio.sleep(max(2, int(_dlq_state.get("interval_seconds", 6))))

            if not bool(_dlq_state.get("enabled", True)):
                continue

            _dlq_state["last_run"] = datetime.now().isoformat()
            replayed = await _replay_dlq_once()
            _dlq_state["last_replayed"] = replayed
            _dlq_state["last_status"] = "succeeded"
            _dlq_state["last_error"] = None
    except asyncio.CancelledError:
        raise
    except Exception as e:
        _dlq_state["last_status"] = "failed"
        _dlq_state["last_error"] = str(e)
        logger.warning("DLQ replay loop failed: %s", e)
    finally:
        _dlq_state["is_running"] = False


def _start_dlq_replay() -> None:
    """Start background DLQ replay worker if not already running."""
    global _dlq_replay_task
    if _dlq_replay_task is not None and not _dlq_replay_task.done():
        return
    _dlq_replay_task = asyncio.create_task(_dlq_replay_loop())


async def _stop_dlq_replay() -> None:
    """Stop background DLQ replay worker."""
    global _dlq_replay_task
    if _dlq_replay_task is None:
        return
    _dlq_replay_task.cancel()
    try:
        await _dlq_replay_task
    except asyncio.CancelledError:
        pass
    _dlq_replay_task = None


def _schedule_packet_ingest(event: TrafficEvent) -> None:
    """Schedule packet ingestion safely from both async loop and sniffer threads."""
    loop = _app_event_loop
    if loop is None or not loop.is_running():
        logger.warning("Packet ingest skipped: app event loop is not running")
        return

    if threading.current_thread() is threading.main_thread():
        asyncio.create_task(_ingest_with_retry(event))
        return

    loop.call_soon_threadsafe(asyncio.create_task, _ingest_with_retry(event))


def process_packet_features(features) -> None:
    """Callback to ingest captured packet features into threat engine."""
    try:
        # Convert packet features to traffic event
        event = feature_extractor.convert_to_traffic_event(features)
        
        # Non-blocking ingestion (safe across sniffer thread + event loop)
        _schedule_packet_ingest(event)
    except Exception as e:
        logger.warning("Packet feature processing failed: %s", e)


def _alerts_to_training_events(limit: int) -> list[TrafficEvent]:
    """Convert recent alerts into synthetic training events for ML retraining."""
    recent_alerts = engine.get_alerts()[:limit]
    events: list[TrafficEvent] = []
    for alert in recent_alerts:
        events.append(
            TrafficEvent(
                source_ip=alert.source_ip,
                destination_ip="172.16.254.1",
                protocol="TCP",
                destination_port=445,
                bytes_in=150000 + int(alert.confidence * 100000),
                bytes_out=120000 + int(alert.confidence * 80000),
                failed_logins=int(alert.confidence * 5),
                geo_anomaly=alert.severity in {"Critical", "High"},
                user_agent_risk=alert.confidence,
                timestamp=alert.time,
            )
        )
    return events


async def _ml_scheduler_loop() -> None:
    """Background scheduler that periodically retrains the ML model."""
    _ml_scheduler_state["is_running"] = True
    try:
        while True:
            interval = int(_ml_scheduler_state.get("interval_seconds", 300))
            await asyncio.sleep(max(30, interval))

            if not bool(_ml_scheduler_state.get("enabled", False)):
                continue

            training_events = int(_ml_scheduler_state.get("training_events", 100))
            events = _alerts_to_training_events(training_events)
            if len(events) < 10:
                _ml_scheduler_state["last_run"] = datetime.now().isoformat()
                _ml_scheduler_state["last_status"] = "skipped"
                _ml_scheduler_state["last_error"] = "Insufficient events for retraining (need 10+)"
                continue

            stats = threat_model.train(events)
            _ml_scheduler_state["last_run"] = datetime.now().isoformat()
            if "error" in stats:
                _ml_scheduler_state["last_status"] = "failed"
                _ml_scheduler_state["last_error"] = str(stats.get("error"))
            else:
                _ml_scheduler_state["last_status"] = "succeeded"
                _ml_scheduler_state["last_error"] = None
    except asyncio.CancelledError:
        raise
    finally:
        _ml_scheduler_state["is_running"] = False


def _start_ml_scheduler() -> None:
    """Start background ML scheduler if not running."""
    global _ml_scheduler_task
    if _ml_scheduler_task is not None and not _ml_scheduler_task.done():
        return
    _ml_scheduler_task = asyncio.create_task(_ml_scheduler_loop())


async def _stop_ml_scheduler() -> None:
    """Stop background ML scheduler task."""
    global _ml_scheduler_task
    if _ml_scheduler_task is None:
        return
    _ml_scheduler_task.cancel()
    try:
        await _ml_scheduler_task
    except asyncio.CancelledError:
        pass
    _ml_scheduler_task = None


app = FastAPI(title=settings.app_name, version="0.2.0", lifespan=lifespan)

class ResilienceStatsMiddleware(BaseHTTPMiddleware):
    """Middleware to collect resilience statistics."""
    
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        try:
            response = await call_next(request)
            elapsed_ms = (time.time() - start_time) * 1000
            stats_collector.record_request(
                endpoint=request.url.path,
                success=response.status_code < 400,
                response_time_ms=elapsed_ms,
            )
            return response
        except Exception as e:
            elapsed_ms = (time.time() - start_time) * 1000
            stats_collector.record_request(
                endpoint=request.url.path,
                success=False,
                response_time_ms=elapsed_ms,
                error=str(e),
            )
            raise

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(ResilienceStatsMiddleware)

@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.app_env}
    
@app.get("/api/v1/health/resilience")
async def get_resilience_status() -> dict:
    """Get backend resilience and health statistics."""
    return stats_collector.get_health_status()


@app.post("/api/v1/auth/login", response_model=AuthTokenResponse)
async def auth_login(payload: AuthLoginRequest) -> AuthTokenResponse:
    """Authenticate gateway user and issue access token."""
    principal = AuthService.authenticate(payload.username, payload.password)
    if principal is None:
        raise HTTPException(status_code=401, detail="Invalid username or password")

    token, expires_at = AuthService.issue_token(principal)
    return AuthTokenResponse(
        access_token=token,
        expires_at=expires_at.isoformat(),
        username=principal.username,
        role=principal.role,
    )


@app.get("/api/v1/auth/me", response_model=AuthProfileResponse)
async def auth_me(principal: AuthPrincipal = Depends(get_current_principal)) -> AuthProfileResponse:
    """Return current authenticated principal profile."""
    return AuthProfileResponse(username=principal.username, role=principal.role)


@app.get("/api/v1/summary", response_model=ThreatSummary)
async def get_summary() -> ThreatSummary:
    return engine.get_summary()


@app.get("/api/v1/alerts", response_model=list[ThreatAlert])
async def get_alerts(
    severity: str | None = None,
    status: str | None = None,
    q: str | None = None,
    limit: int = Query(default=20, ge=1, le=200),
) -> list[ThreatAlert]:
    alerts = engine.get_alerts()

    if severity:
        alerts = [a for a in alerts if a.severity.lower() == severity.lower()]
    if status:
        alerts = [a for a in alerts if a.status.lower() == status.lower()]
    if q:
        needle = q.lower()
        alerts = [
            a
            for a in alerts
            if needle in a.id.lower()
            or needle in a.attack_type.lower()
            or needle in a.source_ip.lower()
            or needle in a.status.lower()
        ]

    return alerts[:limit]


@app.get("/api/v1/metrics/recent", response_model=list[NetworkMetric])
async def get_recent_metrics(limit: int = Query(default=12, ge=1, le=120)) -> list[NetworkMetric]:
    return engine.get_recent_metrics(limit=limit)


@app.get("/api/v1/reports/weekly", response_model=WeeklyReport)
async def get_weekly_report() -> WeeklyReport:
    return engine.get_weekly_report()


@app.post("/api/v1/ingest", response_model=IngestResponse)
async def ingest_traffic(event: TrafficEvent) -> IngestResponse:
    return await engine.ingest(event)


@app.post("/api/v1/notifications/test", response_model=NotificationTestResponse)
async def test_notification(
    payload: NotificationTestRequest,
    principal: AuthPrincipal = Depends(require_roles({"admin", "responder"})),
) -> NotificationTestResponse:
    # Explicit per-channel selection for test dispatch.
    selected_channels = None
    if payload.channel == "email":
        selected_channels = [NotificationChannel.EMAIL]
    elif payload.channel == "sms":
        selected_channels = [NotificationChannel.SMS]
    elif payload.channel == "push":
        selected_channels = [NotificationChannel.PUSH]
    elif payload.channel == "system":
        selected_channels = [NotificationChannel.SYSTEM]
    elif payload.channel == "both":
        selected_channels = [NotificationChannel.EMAIL, NotificationChannel.PUSH]

    results = await NotificationService.send_notification(
        title="CyberSentinel Test Alert",
        message=payload.message or "This is a test notification from CyberSentinel.",
        severity="medium",
        details={
            "test_timestamp": datetime.now().isoformat(),
            "source": "notification_test",
        },
        channels=selected_channels,
    )
    
    return NotificationTestResponse(
        accepted=True,
        channel="multi",
        dispatched_to=list(results.keys()),
    )


@app.get("/api/v1/notifications/channels", response_model=NotificationChannelsResponse)
async def get_notification_channels() -> NotificationChannelsResponse:
    """Get status of all notification channels."""
    return NotificationChannelsResponse(
        channels=NotificationService.get_channel_status()
    )


@app.post("/api/v1/notifications/channels/configure")
async def configure_channel(
    config: NotificationChannelConfig,
    principal: AuthPrincipal = Depends(require_roles({"admin"})),
) -> dict[str, str]:
    """Configure a notification channel target (webhook/email/phone)."""
    success = NotificationService.set_channel_webhook(
        NotificationChannel(config.channel),
        config.webhook_url,
    )
    target_label = {
        "slack": "Webhook URL",
        "teams": "Webhook URL",
        "email": "Email recipient",
        "sms": "SMS phone",
    }.get(config.channel, "Channel target")
    return {
        "channel": config.channel,
        "status": "configured" if success else "failed",
        "message": (
            f"{target_label} configured successfully"
            if success
            else f"Invalid {target_label.lower()}"
        ),
    }


@app.post("/api/v1/notifications/send", response_model=NotificationSendResponse)
async def send_notifications(
    title: str,
    message: str,
    severity: str = "medium",
    principal: AuthPrincipal = Depends(require_roles({"admin", "responder"})),
) -> NotificationSendResponse:
    """Send notification to configured channels."""
    results = await NotificationService.send_notification(
        title=title,
        message=message,
        severity=severity,
    )
    
    return NotificationSendResponse(
        accepted=True,
        results=results,
    )


@app.post("/api/v1/capture/start", response_model=PacketCaptureResponse)
async def start_packet_capture(
    request: PacketCaptureStartRequest,
    principal: AuthPrincipal = Depends(require_roles({"admin", "responder"})),
) -> PacketCaptureResponse:
    """Start real-time network packet capture and threat detection."""
    try:
        global packet_sniffer

        if request.interface and not packet_sniffer.is_running:
            packet_sniffer = get_sniffer(request.interface)

        if packet_sniffer.is_running:
            return PacketCaptureResponse(
                status="already_started",
                message="Packet capture is already running",
                details=PacketCaptureStatus(**packet_sniffer.get_stats()),
            )

        # Start sniffer with packet processing callback
        packet_sniffer.start(callback=process_packet_features)

        return PacketCaptureResponse(
            status="started",
            message=f"Packet capture started on interface {packet_sniffer.interface}",
            details=PacketCaptureStatus(**packet_sniffer.get_stats()),
        )
    except Exception as e:
        return PacketCaptureResponse(
            status="error",
            message=f"Failed to start packet capture: {str(e)}",
            details=None,
        )


@app.post("/api/v1/capture/stop", response_model=PacketCaptureResponse)
async def stop_packet_capture(
    principal: AuthPrincipal = Depends(require_roles({"admin", "responder"})),
) -> PacketCaptureResponse:
    """Stop network packet capture."""
    try:
        if not packet_sniffer.is_running:
            return PacketCaptureResponse(
                status="not_running",
                message="Packet capture is not running",
                details=PacketCaptureStatus(**packet_sniffer.get_stats()),
            )

        packet_sniffer.stop()

        return PacketCaptureResponse(
            status="stopped",
            message="Packet capture stopped successfully",
            details=PacketCaptureStatus(**packet_sniffer.get_stats()),
        )
    except Exception as e:
        return PacketCaptureResponse(
            status="error",
            message=f"Failed to stop packet capture: {str(e)}",
            details=None,
        )


@app.get("/api/v1/capture/status", response_model=PacketCaptureStatus)
async def get_capture_status() -> PacketCaptureStatus:
    """Get current packet capture status."""
    return PacketCaptureStatus(**packet_sniffer.get_stats())


@app.get("/api/v1/capture/dlq/status")
async def get_capture_dlq_status() -> dict[str, object]:
    """Get ingest DLQ status and replay worker state."""
    return {
        "queue": ingest_dlq.stats(),
        "replay": dict(_dlq_state),
    }


@app.post("/api/v1/capture/dlq/replay")
async def replay_capture_dlq_once(
    principal: AuthPrincipal = Depends(require_roles({"admin"})),
) -> dict[str, object]:
    """Trigger one immediate DLQ replay batch."""
    replayed = await _replay_dlq_once()
    _dlq_state["last_run"] = datetime.now().isoformat()
    _dlq_state["last_replayed"] = replayed
    _dlq_state["last_status"] = "manual"
    _dlq_state["last_error"] = None
    return {
        "replayed": replayed,
        "queue": ingest_dlq.stats(),
    }


@app.get("/api/v1/ml/model/info", response_model=MLModelInfo)
async def get_ml_model_info() -> MLModelInfo:
    """Get information about ML threat detection model."""
    return MLModelInfo(**threat_model.get_model_info())


@app.post("/api/v1/ml/model/train", response_model=MLTrainingResponse)
async def train_ml_model(
    request: MLTrainingRequest,
    principal: AuthPrincipal = Depends(require_roles({"admin"})),
) -> MLTrainingResponse:
    """Train ML model on historical threat events."""
    try:
        training_events = _alerts_to_training_events(request.training_events)

        if len(training_events) < 10:
            return MLTrainingResponse(
                success=False,
                message=f"Insufficient training data: {len(training_events)} alerts (need 10+)",
            )

        # Train model
        stats = threat_model.train(training_events)

        if "error" in stats:
            return MLTrainingResponse(
                success=False,
                message=f"Training failed: {stats.get('error')}",
            )

        return MLTrainingResponse(
            success=True,
            events_trained=stats.get("events_trained", 0),
            anomalies_detected=stats.get("anomalies_detected", 0),
            anomaly_rate=stats.get("anomaly_rate", 0.0),
            message=(
                f"Model trained successfully "
                f"(version={stats.get('version_id', 'n/a')}, slot={stats.get('slot', 'n/a')})"
            ),
        )
    except Exception as e:
        return MLTrainingResponse(
            success=False,
            message=f"Training error: {str(e)}",
        )


@app.post("/api/v1/ml/predict", response_model=MLPredictionResponse)
async def predict_threat(event: TrafficEvent) -> MLPredictionResponse:
    """Get ML anomaly prediction for traffic event."""
    try:
        is_anomaly, confidence = threat_model.predict(event)
        
        # Generate recommendation
        if is_anomaly:
            if confidence > 0.8:
                recommendation = "Critical: Immediate investigation required"
            elif confidence > 0.6:
                recommendation = "High: Schedule investigation within 1 hour"
            else:
                recommendation = "Medium: Monitor and collect additional data"
        else:
            recommendation = "Normal traffic pattern"

        return MLPredictionResponse(
            is_anomaly=is_anomaly,
            confidence=confidence,
            recommendation=recommendation,
        )
    except Exception as e:
        return MLPredictionResponse(
            is_anomaly=False,
            confidence=0.0,
            recommendation=f"Prediction error: {str(e)}",
        )


@app.get("/api/v1/ml/scheduler/status", response_model=MLSchedulerStatusResponse)
async def get_ml_scheduler_status() -> MLSchedulerStatusResponse:
    """Get current status of async ML retraining scheduler."""
    return MLSchedulerStatusResponse(**_ml_scheduler_state)


@app.post("/api/v1/ml/scheduler/configure", response_model=MLSchedulerStatusResponse)
async def configure_ml_scheduler(
    payload: MLSchedulerConfigRequest,
    principal: AuthPrincipal = Depends(require_roles({"admin"})),
) -> MLSchedulerStatusResponse:
    """Configure async ML retraining scheduler behavior."""
    _ml_scheduler_state["enabled"] = payload.enabled
    _ml_scheduler_state["interval_seconds"] = payload.interval_seconds
    _ml_scheduler_state["training_events"] = payload.training_events
    _ml_scheduler_state["last_status"] = "configured"
    _ml_scheduler_state["last_error"] = None
    return MLSchedulerStatusResponse(**_ml_scheduler_state)


@app.get("/api/v1/ml/feature-importance", response_model=MLFeatureImportanceResponse)
async def get_ml_feature_importance() -> MLFeatureImportanceResponse:
    """Get SHAP-style feature importance for active model version."""
    details = threat_model.get_feature_importance()
    return MLFeatureImportanceResponse(**details)


@app.post("/api/v1/ml/threshold/tune", response_model=MLThresholdTuneResponse)
async def tune_ml_threshold(
    payload: MLThresholdTuneRequest,
    principal: AuthPrincipal = Depends(require_roles({"admin"})),
) -> MLThresholdTuneResponse:
    """Automatically tune alert threshold based on observed false-positive rate."""
    tuned = threat_model.tune_threshold(
        target_false_positive_rate=payload.target_false_positive_rate,
        alerts=engine.get_alerts(),
    )
    return MLThresholdTuneResponse(**tuned)


@app.get("/api/v1/ml/model/versions", response_model=MLModelVersionsResponse)
async def get_ml_model_versions() -> MLModelVersionsResponse:
    """Get trained model versions and current active version."""
    versions_data = threat_model.get_model_versions()
    return MLModelVersionsResponse(
        active_version=versions_data.get("active_version"),
        versions=[MLModelVersionInfo(**item) for item in versions_data.get("versions", [])],
    )


@app.post("/api/v1/ml/model/switch", response_model=MLModelVersionsResponse)
async def switch_ml_model_version(
    payload: MLSwitchVersionRequest,
    principal: AuthPrincipal = Depends(require_roles({"admin"})),
) -> MLModelVersionsResponse:
    """Switch active model version for inference (A/B testing support)."""
    switched = threat_model.switch_active_version(payload.version_id)
    if not switched:
        versions_data = threat_model.get_model_versions()
        return MLModelVersionsResponse(
            active_version=versions_data.get("active_version"),
            versions=[MLModelVersionInfo(**item) for item in versions_data.get("versions", [])],
        )

    versions_data = threat_model.get_model_versions()
    return MLModelVersionsResponse(
        active_version=versions_data.get("active_version"),
        versions=[MLModelVersionInfo(**item) for item in versions_data.get("versions", [])],
    )


@app.post("/api/v1/ml/model/ab-test")
async def run_ml_ab_test(event: TrafficEvent) -> dict:
    """Run A/B prediction for a traffic event against latest A and B versions."""
    return threat_model.predict_ab(event)


@app.websocket("/api/v1/stream")
async def threat_stream(ws: WebSocket) -> None:
    await ws.accept()
    queue = engine.subscribe()

    await ws.send_json(
        {
            "type": "snapshot",
            "summary": engine.get_summary().model_dump(mode="json"),
            "alerts": [a.model_dump(mode="json") for a in engine.get_alerts()[:5]],
            "metrics": [m.model_dump(mode="json") for m in engine.get_recent_metrics(limit=5)],
        }
    )

    try:
        while True:
            event = await queue.get()
            await ws.send_json(event)
            await asyncio.sleep(0)
    except WebSocketDisconnect:
        engine.unsubscribe(queue)
    finally:
        engine.unsubscribe(queue)


@app.post("/api/v1/simulate/{scenario}", tags=["Simulation"])
async def simulate_attack(
    scenario: str,
    duration: int = Query(30, ge=5, le=120, description="Simulation duration in seconds"),
    intensity: str = Query("high", description="Attack intensity: low, medium, high, critical"),
    principal: AuthPrincipal = Depends(require_roles({"admin", "responder"})),
):
    """
    Simulate a cyber attack for demonstration and testing purposes.
    
    Available scenarios:
    - ddos: Distributed Denial of Service attack
    - port_scan: Network port scanning
    - brute_force: Brute force login attempts
    - suspicious: Data exfiltration patterns
    - ransomware: Ransomware propagation
    - malware_beaconing: C2 beaconing communication
    """
    if scenario not in simulator.SCENARIOS:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown scenario. Available: {', '.join(simulator.SCENARIOS.keys())}"
        )
    
    # Validate custom intensity
    if intensity not in ["low", "medium", "high", "critical"]:
        raise HTTPException(status_code=400, detail="Invalid intensity level")
    
    # Override intensity in scenario for this simulation
    try:
        result = simulator.start_simulation(scenario, custom_duration=duration)
        result["custom_intensity"] = intensity
        result["requested_duration"] = duration
        
        logger.info(
            "Attack simulation started: %s (duration=%ss, intensity=%s)",
            scenario, duration, intensity
        )
        
        return {
            "success": True,
            "simulation": result,
            "message": f"Simulation '{scenario}' started successfully",
            "alerts_to_generate": result["packet_count"],
            "estimated_duration": duration
        }
    except Exception as e:
        logger.error("Failed to start simulation '%s': %s", scenario, e)
        raise HTTPException(status_code=500, detail=f"Failed to start simulation: {str(e)}")


@app.post("/api/v1/simulate/ddos", tags=["Simulation"])
async def simulate_ddos(
    duration: int = Query(30, ge=5, le=120),
):
    """Simulate a Distributed Denial of Service (DDoS) attack."""
    return await simulate_attack("ddos", duration=duration, intensity="high")


@app.post("/api/v1/simulate/port-scan", tags=["Simulation"])
async def simulate_port_scan(
    duration: int = Query(15, ge=5, le=60),
):
    """Simulate a port scanning reconnaissance attack."""
    return await simulate_attack("port_scan", duration=duration, intensity="medium")


@app.post("/api/v1/simulate/brute-force", tags=["Simulation"])
async def simulate_brute_force(
    duration: int = Query(20, ge=5, le=90),
):
    """Simulate brute force login attempts."""
    return await simulate_attack("brute_force", duration=duration, intensity="medium")


@app.post("/api/v1/simulate/suspicious", tags=["Simulation"])
async def simulate_suspicious(
    duration: int = Query(25, ge=5, le=120),
):
    """Simulate suspicious traffic patterns (potential data exfiltration)."""
    return await simulate_attack("suspicious", duration=duration, intensity="high")


@app.get("/api/v1/simulations", tags=["Simulation"])
async def get_simulations(
    status: str = Query(None, description="Filter by status: running, completed, stopped"),
):
    """Get all simulations."""
    simulations = simulator.get_all_simulations()
    if status:
        simulations = [s for s in simulations if s["status"] == status]
    return {"success": True, "simulations": simulations, "total": len(simulations)}


@app.get("/api/v1/simulations/active", tags=["Simulation"])
async def get_active_simulations():
    """Get currently running simulations."""
    simulations = simulator.get_active_simulations()
    return {"success": True, "simulations": simulations, "count": len(simulations)}


@app.get("/api/v1/simulations/scenarios", tags=["Simulation"])
async def get_scenarios():
    """Get all available attack scenarios."""
    scenarios = simulator.get_scenarios()
    return {"success": True, "scenarios": scenarios}


@app.post("/api/v1/simulations/{simulation_id}/stop", tags=["Simulation"])
async def stop_simulation(
    simulation_id: str,
    principal: AuthPrincipal = Depends(require_roles({"admin", "responder"})),
):
    """Stop a running simulation."""
    simulation = simulator.stop_simulation(simulation_id)
    logger.info("Simulation stopped: %s", simulation_id)
    return {"success": True, "simulation": simulation}


@app.get("/api/v1/simulations/{simulation_id}", tags=["Simulation"])
async def get_simulation(
    simulation_id: str,
):
    """Get details of a specific simulation."""
    simulation = simulator.get_simulation(simulation_id)
    if not simulation:
        raise HTTPException(status_code=404, detail="Simulation not found")
    return {"success": True, "simulation": simulation}


@app.get("/api/v1/simulate", tags=["Simulation"])
async def demo_simulation(
    principal: AuthPrincipal = Depends(require_roles({"admin", "responder"})),
):
    """
    Run a quick demo simulation with all attack types (sequential).
    Great for demonstrating the full system capabilities.
    """
    scenarios = ["port_scan", "brute_force", "suspicious", "ddos"]
    results = []
    
    for scenario in scenarios:
        try:
            result = simulator.start_simulation(scenario, custom_duration=10)
            results.append(result)
            await asyncio.sleep(2)  # Brief pause between scenarios
        except Exception as e:
            logger.error("Demo simulation failed for %s: %s", scenario, e)
    
    logger.info("Demo simulation completed: %d scenarios", len(results))
    
    return {
        "success": True,
        "message": "Demo simulation started",
        "scenarios_run": scenarios,
        "simulations": results
    }


@app.post("/api/v1/incidents", tags=["Incident Response"])
async def create_incident(
    title: str,
    description: str,
    severity: str,
    source_ip: Optional[str] = None,
    affected_systems: Optional[List[str]] = None,
    tags: Optional[List[str]] = None,
    principal: AuthPrincipal = Depends(require_roles({"admin", "responder"})),
):
    """Create a new incident manually."""
    try:
        incident = incident_workflow.create_manual_incident(
            title=title,
            description=description,
            severity=severity,
            source_ip=source_ip,
            affected_systems=affected_systems,
            tags=tags,
        )
        logger.info("Incident created: %s - %s", incident.incident_id, title)
        return {"success": True, "incident": incident.to_dict()}
    except Exception as e:
        logger.error("Failed to create incident: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/incidents/from_alert")
async def create_incident_from_alert(
    alert_id: str,
    principal: AuthPrincipal = Depends(require_roles({"admin", "responder"})),
):
    """Create incident from an existing alert."""
    try:
        alerts = engine.get_alerts()
        alert = next((a for a in alerts if a.id == alert_id), None)
        if not alert:
            raise HTTPException(status_code=404, detail="Alert not found")
        incident = incident_workflow.create_incident_from_alert(alert)
        logger.info("Incident created from alert: %s", incident.incident_id)
        return {"success": True, "incident": incident.to_dict()}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to create incident from alert: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/incidents", tags=["Incident Response"])
async def get_incidents(status: Optional[str] = None):
    """Get all incidents, optionally filtered by status."""
    incidents = incident_workflow.get_all_incidents(status)
    return {"success": True, "incidents": incidents, "total": len(incidents)}


@app.get("/api/v1/incidents/active", tags=["Incident Response"])
async def get_active_incidents():
    """Get all non-closed incidents."""
    incidents = incident_workflow.get_active_incidents()
    return {"success": True, "incidents": incidents, "count": len(incidents)}


@app.get("/api/v1/incidents/{incident_id}", tags=["Incident Response"])
async def get_incident(incident_id: str):
    """Get incident details by ID."""
    incident = incident_workflow.get_incident(incident_id)
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")
    return {"success": True, "incident": incident}


@app.post("/api/v1/incidents/{incident_id}/status", tags=["Incident Response"])
async def update_incident_status(
    incident_id: str,
    status: str,
    notes: Optional[str] = None,
    principal: AuthPrincipal = Depends(require_roles({"admin", "responder"})),
):
    """Update incident status (Open → Investigating → Resolved → Closed)."""
    try:
        incident = incident_workflow.update_status(incident_id, status, notes)
        logger.info("Incident %s status updated: %s", incident_id, status)
        return {"success": True, "incident": incident.to_dict()}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error("Failed to update incident status: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/incidents/{incident_id}/assign", tags=["Incident Response"])
async def assign_incident(
    incident_id: str,
    analyst_id: str,
    principal: AuthPrincipal = Depends(require_roles({"admin", "responder"})),
):
    """Assign incident to an analyst."""
    try:
        incident = incident_workflow.assign_analyst(incident_id, analyst_id)
        logger.info("Incident %s assigned to %s", incident_id, analyst_id)
        return {"success": True, "incident": incident.to_dict()}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error("Failed to assign incident: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/incidents/{incident_id}/notes", tags=["Incident Response"])
async def add_incident_note(
    incident_id: str,
    note: str,
    author: Optional[str] = "System",
    principal: AuthPrincipal = Depends(require_roles({"admin", "responder", "analyst"})),
):
    """Add a note to an incident."""
    try:
        incident = incident_workflow.add_note(incident_id, note, author)
        logger.info("Note added to incident %s", incident_id)
        return {"success": True, "incident": incident.to_dict()}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to add note: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v1/incidents/{incident_id}/response_action", tags=["Incident Response"])
async def add_response_action(
    incident_id: str,
    action: str,
    actor: str,
    status: Optional[str] = "completed",
    principal: AuthPrincipal = Depends(require_roles({"admin", "responder"})),
):
    """Add a response action taken for an incident."""
    try:
        incident = incident_workflow.add_response_action(incident_id, action, actor, status)
        logger.info("Response action added to incident %s", incident_id)
        return {"success": True, "incident": incident.to_dict()}
    except Exception as e:
        logger.error("Failed to add response action: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v1/incidents/analysts", tags=["Incident Response"])
async def get_analyst_workload():
    """Get current analyst workload."""
    return {"success": True, "analysts": incident_workflow.get_analyst_workload()}


@app.get("/api/v1/incidents/sla", tags=["Incident Response"])
async def get_sla_summary():
    """Get SLA compliance summary."""
    return {"success": True, "sla": incident_workflow.get_sla_summary()}


@app.get("/api/v1/incidents/severity/{severity}", tags=["Incident Response"])
async def get_incidents_by_severity(severity: str):
    """Get incidents filtered by severity."""
    incidents = incident_workflow.get_incidents_by_severity(severity)
    return {"success": True, "incidents": incidents, "severity": severity}
