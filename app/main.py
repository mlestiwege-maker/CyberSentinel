from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
from datetime import datetime

from fastapi import FastAPI, Query, WebSocket, WebSocketDisconnect
import time
from starlette.middleware.base import BaseHTTPMiddleware
from fastapi import Request
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.models import (
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
from app.services.notification_service import NotificationChannel, NotificationService
from app.services.packet_sniffer import get_sniffer
from app.services.feature_extractor import FeatureExtractor
from app.services.ml_threat_model import get_threat_model
from app.services.stats_collector import ResilienceStatsCollector
from app.services.threat_engine import ThreatEngine

engine = ThreatEngine()
stats_collector = ResilienceStatsCollector()
feature_extractor = FeatureExtractor()
packet_sniffer = get_sniffer()
threat_model = get_threat_model()

_ml_scheduler_task: asyncio.Task | None = None
_ml_scheduler_state: dict[str, object] = {
    "enabled": False,
    "interval_seconds": 300,
    "training_events": 100,
    "is_running": False,
    "last_run": None,
    "last_status": "idle",
    "last_error": None,
}


@asynccontextmanager
async def lifespan(_: FastAPI):
    await engine.start()
    _start_ml_scheduler()
    yield
    await _stop_ml_scheduler()
    await engine.stop()


def process_packet_features(features) -> None:
    """Callback to ingest captured packet features into threat engine."""
    try:
        # Convert packet features to traffic event
        event = feature_extractor.convert_to_traffic_event(features)
        
        # Non-blocking ingestion (schedule as task)
        asyncio.create_task(engine.ingest(event))
    except Exception as e:
        pass  # Silently fail to avoid blocking packet sniffer


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
async def test_notification(payload: NotificationTestRequest) -> NotificationTestResponse:
    # Legacy endpoint - send test notification to configured channels
    results = await NotificationService.send_notification(
        title="CyberSentinel Test Alert",
        message=payload.message or "This is a test notification from CyberSentinel.",
        severity="medium",
        details={
            "test_timestamp": datetime.now().isoformat(),
            "source": "notification_test",
        },
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
async def configure_channel(config: NotificationChannelConfig) -> dict[str, str]:
    """Configure a notification channel webhook."""
    success = NotificationService.set_channel_webhook(
        NotificationChannel(config.channel),
        config.webhook_url,
    )
    return {
        "channel": config.channel,
        "status": "configured" if success else "failed",
        "message": "Webhook URL configured successfully" if success else "Invalid webhook URL",
    }


@app.post("/api/v1/notifications/send", response_model=NotificationSendResponse)
async def send_notifications(
    title: str,
    message: str,
    severity: str = "medium",
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
async def start_packet_capture(request: PacketCaptureStartRequest) -> PacketCaptureResponse:
    """Start real-time network packet capture and threat detection."""
    try:
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
async def stop_packet_capture() -> PacketCaptureResponse:
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


@app.get("/api/v1/ml/model/info", response_model=MLModelInfo)
async def get_ml_model_info() -> MLModelInfo:
    """Get information about ML threat detection model."""
    return MLModelInfo(**threat_model.get_model_info())


@app.post("/api/v1/ml/model/train", response_model=MLTrainingResponse)
async def train_ml_model(request: MLTrainingRequest) -> MLTrainingResponse:
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
async def configure_ml_scheduler(payload: MLSchedulerConfigRequest) -> MLSchedulerStatusResponse:
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
async def tune_ml_threshold(payload: MLThresholdTuneRequest) -> MLThresholdTuneResponse:
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
async def switch_ml_model_version(payload: MLSwitchVersionRequest) -> MLModelVersionsResponse:
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
