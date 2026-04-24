from __future__ import annotations

import asyncio
import random
from collections import Counter
from datetime import datetime, timedelta, timezone

from app.config import settings
from app.models import (
    IngestResponse,
    NetworkMetric,
    ThreatAlert,
    ThreatSummary,
    TrafficEvent,
    WeeklyReport,
)


class ThreatEngine:
    def __init__(self) -> None:
        self._alerts: list[ThreatAlert] = []
        self._metrics: list[NetworkMetric] = []
        self._attack_counter: Counter[str] = Counter()
        self._sequence = 0
        self._lock = asyncio.Lock()
        self._subscribers: set[asyncio.Queue[dict]] = set()
        self._task: asyncio.Task | None = None

    async def start(self) -> None:
        async with self._lock:
            if self._task is not None and not self._task.done():
                return
            self._seed_data()
            if settings.simulation_enabled:
                self._task = asyncio.create_task(self._simulation_loop())

    async def stop(self) -> None:
        async with self._lock:
            if self._task is not None:
                self._task.cancel()
                try:
                    await self._task
                except asyncio.CancelledError:
                    pass
                self._task = None

    def subscribe(self) -> asyncio.Queue[dict]:
        q: asyncio.Queue[dict] = asyncio.Queue(maxsize=100)
        self._subscribers.add(q)
        return q

    def unsubscribe(self, q: asyncio.Queue[dict]) -> None:
        self._subscribers.discard(q)

    def get_alerts(self) -> list[ThreatAlert]:
        return sorted(self._alerts, key=lambda a: self._as_utc(a.time), reverse=True)

    def get_recent_metrics(self, limit: int = 20) -> list[NetworkMetric]:
        sorted_metrics = sorted(self._metrics, key=lambda m: self._as_utc(m.time), reverse=True)
        return sorted_metrics[:limit]

    def get_summary(self) -> ThreatSummary:
        now = datetime.now(timezone.utc)
        latest_metric = self._metrics[-1] if self._metrics else None

        active = [a for a in self._alerts if a.status != "Resolved"]
        resolved_today = [a for a in self._alerts if a.status == "Resolved" and a.time.date() == now.date()]

        return ThreatSummary(
            active_threats=len(active),
            new_alerts=sum(1 for a in self._alerts if a.time.date() == now.date()),
            resolved_today=len(resolved_today),
            critical_open=sum(1 for a in active if a.severity == "Critical"),
            high_severity=sum(1 for a in self._alerts if a.severity == "High"),
            investigations=sum(1 for a in self._alerts if a.status == "Investigating"),
            auto_resolved=sum(1 for a in self._alerts if a.status == "Resolved"),
            anomalies=sum(1 for a in self._alerts if a.status in {"Investigating", "Monitoring"}),
            packet_rate=latest_metric.packets_per_second if latest_metric else 0,
            monitored_hosts=128 + random.randint(0, 24),
        )

    def get_weekly_report(self) -> WeeklyReport:
        top_threat = self._attack_counter.most_common(1)
        return WeeklyReport(
            mttd_seconds=138,
            incidents_total=len(self._alerts),
            detection_accuracy=94.8,
            top_threat_type=top_threat[0][0] if top_threat else "N/A",
            auto_resolved_events=sum(1 for a in self._alerts if a.status == "Resolved"),
        )

    async def ingest(self, event: TrafficEvent) -> IngestResponse:
        event_time = self._as_utc(event.timestamp)
        score = self._score_event(event)
        metric = NetworkMetric(
            time=event_time,
            packets_per_second=max(1000, int((event.bytes_in + event.bytes_out) / 7)),
            anomaly_score=round(score, 3),
            suspicious_connections=min(60, int(score * 35) + event.failed_logins),
        )
        self._append_metric(metric)

        alert_generated = score >= settings.alert_anomaly_threshold
        alert_id: str | None = None

        if alert_generated:
            alert = self._create_alert(event=event, score=score, event_time=event_time)
            self._append_alert(alert)
            alert_id = alert.id

        await self._broadcast(
            {
                "type": "ingest",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "anomaly_score": score,
                "alert_generated": alert_generated,
                "summary": self.get_summary().model_dump(),
            }
        )

        return IngestResponse(
            accepted=True,
            anomaly_score=round(score, 3),
            alert_generated=alert_generated,
            alert_id=alert_id,
        )

    def _seed_data(self) -> None:
        if self._metrics or self._alerts:
            return

        now = datetime.now(timezone.utc)
        for i in range(10):
            score = round(0.2 + random.random() * 0.65, 3)
            self._append_metric(
                NetworkMetric(
                    time=now - timedelta(minutes=10 - i),
                    packets_per_second=9000 + random.randint(2000, 8500),
                    anomaly_score=score,
                    suspicious_connections=2 + int(score * 20),
                )
            )

        samples = [
            ("DDoS", "Critical", "Blocked", 0.93),
            ("Ransomware", "High", "Investigating", 0.88),
            ("Phishing", "Medium", "Resolved", 0.71),
            ("Port Scan", "Low", "Monitoring", 0.62),
        ]
        for idx, (attack, severity, status, conf) in enumerate(samples):
            self._sequence += 1
            alert = ThreatAlert(
                id=f"ALT-{now.year}-{self._sequence:04d}",
                time=now - timedelta(minutes=idx * 9),
                attack_type=attack,
                source_ip=f"10.48.{12 + idx}.{30 + idx}",
                severity=severity,
                status=status,
                description=f"{attack} behavior flagged by anomaly model and threat classifier.",
                confidence=conf,
            )
            self._append_alert(alert)

    async def _simulation_loop(self) -> None:
        while True:
            await asyncio.sleep(4)
            event = self._generate_synthetic_event()
            await self.ingest(event)

    def _generate_synthetic_event(self) -> TrafficEvent:
        heavy = random.random() > 0.72
        return TrafficEvent(
            source_ip=f"10.{20 + random.randint(0, 50)}.{random.randint(0, 255)}.{random.randint(1, 254)}",
            destination_ip=f"172.16.{random.randint(0, 64)}.{random.randint(1, 254)}",
            protocol=random.choice(["TCP", "UDP", "HTTPS", "HTTP"]),
            destination_port=random.choice([22, 53, 80, 443, 445, 8080]),
            bytes_in=random.randint(5000, 250000 if heavy else 80000),
            bytes_out=random.randint(3000, 180000 if heavy else 60000),
            failed_logins=random.randint(0, 9 if heavy else 4),
            geo_anomaly=random.random() > 0.84,
            user_agent_risk=round(random.random(), 3),
        )

    def _score_event(self, event: TrafficEvent) -> float:
        total_traffic = event.bytes_in + event.bytes_out
        traffic_component = min(1.0, total_traffic / 320000)
        login_component = min(1.0, event.failed_logins / 8)
        port_component = 0.3 if event.destination_port in {22, 445, 3389} else 0.1
        geo_component = 0.22 if event.geo_anomaly else 0.0
        ua_component = event.user_agent_risk * 0.35

        score = (
            traffic_component * 0.36
            + login_component * 0.26
            + port_component
            + geo_component
            + ua_component
        )
        return float(max(0.0, min(1.0, score)))

    def _create_alert(self, event: TrafficEvent, score: float, event_time: datetime) -> ThreatAlert:
        self._sequence += 1
        attack = self._classify_attack(event, score)
        severity = self._severity_from_score(score)
        status = random.choice(["Investigating", "Blocked", "Monitoring", "Contained"])

        return ThreatAlert(
            id=f"ALT-{event_time.year}-{self._sequence:04d}",
            time=event_time,
            attack_type=attack,
            source_ip=event.source_ip,
            severity=severity,
            status=status,
            description=f"Potential {attack} detected. Adaptive model confidence elevated due to anomalous network behavior.",
            confidence=round(score, 3),
        )

    def _classify_attack(self, event: TrafficEvent, score: float) -> str:
        if event.destination_port == 445 and score > 0.85:
            return "Ransomware"
        if event.destination_port in {80, 443, 8080} and event.bytes_in > 150000:
            return "DDoS"
        if event.failed_logins >= 5:
            return "Brute Force"
        if event.geo_anomaly and event.user_agent_risk > 0.7:
            return "Credential Abuse"
        return random.choice(["Port Scan", "Phishing", "SQL Injection", "Malware Beaconing"])

    def _severity_from_score(self, score: float) -> str:
        if score >= settings.alert_critical_threshold:
            return "Critical"
        if score >= settings.alert_anomaly_threshold:
            return "High"
        if score >= 0.6:
            return "Medium"
        return "Low"

    def _append_alert(self, alert: ThreatAlert) -> None:
        self._alerts.append(alert)
        self._attack_counter[alert.attack_type] += 1
        if len(self._alerts) > 250:
            self._alerts = self._alerts[-250:]

    def _append_metric(self, metric: NetworkMetric) -> None:
        self._metrics.append(metric)
        if len(self._metrics) > 500:
            self._metrics = self._metrics[-500:]

    async def _broadcast(self, payload: dict) -> None:
        if not self._subscribers:
            return

        stale: list[asyncio.Queue[dict]] = []
        for q in self._subscribers:
            try:
                q.put_nowait(payload)
            except asyncio.QueueFull:
                stale.append(q)

        for q in stale:
            self._subscribers.discard(q)

    def _as_utc(self, dt: datetime) -> datetime:
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
