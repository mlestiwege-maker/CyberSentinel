from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.models import TrafficEvent
from app.services.ingest_idempotency import IngestIdempotencyWindow


def _event(timestamp: datetime | None = None, bytes_in: int = 1000) -> TrafficEvent:
    return TrafficEvent(
        source_ip="10.0.0.8",
        destination_ip="172.16.0.6",
        protocol="TCP",
        destination_port=443,
        bytes_in=bytes_in,
        bytes_out=220,
        failed_logins=0,
        geo_anomaly=False,
        user_agent_risk=0.1,
        timestamp=timestamp or datetime.now(timezone.utc),
    )


def test_signature_is_stable_for_same_event_payload() -> None:
    now = datetime(2026, 4, 25, tzinfo=timezone.utc)
    event_a = _event(timestamp=now)
    event_b = _event(timestamp=now)

    sig_a = IngestIdempotencyWindow.signature_for_event(event_a)
    sig_b = IngestIdempotencyWindow.signature_for_event(event_b)

    assert sig_a == sig_b


def test_check_and_mark_flags_duplicate_within_ttl() -> None:
    window = IngestIdempotencyWindow(ttl_seconds=600, max_entries=1000)
    now = datetime(2026, 4, 25, tzinfo=timezone.utc)

    sig = window.signature_for_event(_event(timestamp=now))
    assert window.check_and_mark(sig, now=now) is False
    assert window.check_and_mark(sig, now=now + timedelta(seconds=120)) is True


def test_signature_expires_after_ttl() -> None:
    window = IngestIdempotencyWindow(ttl_seconds=60, max_entries=1000)
    now = datetime(2026, 4, 25, tzinfo=timezone.utc)

    sig = window.signature_for_event(_event(timestamp=now))
    assert window.check_and_mark(sig, now=now) is False
    assert window.check_and_mark(sig, now=now + timedelta(seconds=61)) is False


def test_capacity_trim_keeps_recent_signatures() -> None:
    window = IngestIdempotencyWindow(ttl_seconds=600, max_entries=500)
    now = datetime(2026, 4, 25, tzinfo=timezone.utc)

    for idx in range(650):
        sig = window.signature_for_event(_event(timestamp=now + timedelta(seconds=idx), bytes_in=idx + 1))
        window.mark(sig, now=now + timedelta(seconds=idx))

    assert window.size() <= 500
