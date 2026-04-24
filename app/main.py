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
    MLModelInfo,
    MLPredictionResponse,
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


@asynccontextmanager
async def lifespan(_: FastAPI):
    await engine.start()
    yield
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
        # Get recent alerts with consistent failures
        recent_alerts = engine.get_alerts()[:request.training_events]
        
        if len(recent_alerts) < 10:
            return MLTrainingResponse(
                success=False,
                message=f"Insufficient training data: {len(recent_alerts)} alerts (need 10+)",
            )

        # Convert alerts back to traffic events (synthetic representation)
        training_events: list[TrafficEvent] = []
        for alert in recent_alerts:
            event = TrafficEvent(
                source_ip=alert.source_ip,
                destination_ip="172.16.254.1",
                protocol="TCP",
                destination_port=445,
                bytes_in=150000 + (int(alert.confidence * 100000)),
                bytes_out=120000 + (int(alert.confidence * 80000)),
                failed_logins=int(alert.confidence * 5),
                geo_anomaly=alert.severity in {"Critical", "High"},
                user_agent_risk=alert.confidence,
                timestamp=alert.time,
            )
            training_events.append(event)

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
            message="Model trained successfully",
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
