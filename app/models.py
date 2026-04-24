from __future__ import annotations

from datetime import datetime, timezone
from typing import Literal

from pydantic import BaseModel, Field


Severity = Literal["Critical", "High", "Medium", "Low"]
AlertStatus = Literal["Investigating", "Blocked", "Monitoring", "Contained", "Resolved"]


class TrafficEvent(BaseModel):
    source_ip: str
    destination_ip: str
    protocol: Literal["TCP", "UDP", "ICMP", "HTTP", "HTTPS"] = "TCP"
    destination_port: int = Field(ge=1, le=65535)
    bytes_in: int = Field(ge=0)
    bytes_out: int = Field(ge=0)
    failed_logins: int = Field(default=0, ge=0)
    geo_anomaly: bool = False
    user_agent_risk: float = Field(default=0.0, ge=0.0, le=1.0)
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class ThreatAlert(BaseModel):
    id: str
    time: datetime
    attack_type: str
    source_ip: str
    severity: Severity
    status: AlertStatus
    description: str
    confidence: float = Field(ge=0.0, le=1.0)


class NetworkMetric(BaseModel):
    time: datetime
    packets_per_second: int = Field(ge=0)
    anomaly_score: float = Field(ge=0.0, le=1.0)
    suspicious_connections: int = Field(ge=0)


class ThreatSummary(BaseModel):
    active_threats: int
    new_alerts: int
    resolved_today: int
    critical_open: int
    high_severity: int
    investigations: int
    auto_resolved: int
    anomalies: int
    packet_rate: int
    monitored_hosts: int


class WeeklyReport(BaseModel):
    mttd_seconds: int
    incidents_total: int
    detection_accuracy: float
    top_threat_type: str
    auto_resolved_events: int


class IngestResponse(BaseModel):
    accepted: bool
    anomaly_score: float = Field(ge=0.0, le=1.0)
    alert_generated: bool
    alert_id: str | None = None


class NotificationTestRequest(BaseModel):
    channel: Literal["email", "push", "both"] = "both"
    message: str = Field(min_length=4, max_length=200)


class NotificationTestResponse(BaseModel):
    accepted: bool
    channel: str
    dispatched_to: list[str]


class NotificationChannelConfig(BaseModel):
    channel: Literal["slack", "teams", "email"] = "slack"
    webhook_url: str = Field(min_length=10)


class NotificationChannelStatus(BaseModel):
    channel: str
    status: str  # "configured" or "not_configured"


class NotificationChannelsResponse(BaseModel):
    channels: dict[str, str]  # {"slack": "configured", "teams": "not_configured", ...}


class NotificationSendResponse(BaseModel):
    accepted: bool
    results: dict[str, str]  # {"slack": "success", "teams": "failed", ...}


class PacketCaptureStatus(BaseModel):
    """Status of packet capture service."""

    is_running: bool
    interface: str
    packets_captured: int
    buffered_features: int


class PacketCaptureStartRequest(BaseModel):
    """Request to start packet capture."""

    interface: str | None = None  # Use default if None


class PacketCaptureResponse(BaseModel):
    """Response for packet capture control."""

    status: str  # "started", "stopped", "error"
    message: str
    details: PacketCaptureStatus | None = None


class MLModelInfo(BaseModel):
    """Information about ML threat detection model."""

    model_name: str
    version: str
    features: list[str]
    contamination: float | None
    training_samples: int
    last_training: str | None
    anomaly_detection_method: str
    status: str  # "trained" or "untrained"


class MLTrainingRequest(BaseModel):
    """Request to train ML model."""

    training_events: int = 100  # Number of historical events to use


class MLTrainingResponse(BaseModel):
    """Response from ML model training."""

    success: bool
    events_trained: int = 0
    anomalies_detected: int = 0
    anomaly_rate: float = 0.0
    message: str = ""


class MLPredictionResponse(BaseModel):
    """Response from ML anomaly prediction."""

    is_anomaly: bool
    confidence: float
    recommendation: str
