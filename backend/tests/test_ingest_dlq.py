from __future__ import annotations

from pathlib import Path

from app.models import TrafficEvent
from app.services.ingest_dlq import IngestDLQ


def _sample_event() -> TrafficEvent:
    return TrafficEvent(
        source_ip="10.10.1.20",
        destination_ip="172.16.0.10",
        protocol="TCP",
        destination_port=443,
        bytes_in=1200,
        bytes_out=400,
        failed_logins=0,
        geo_anomaly=False,
        user_agent_risk=0.12,
    )


def test_dlq_enqueue_peek_ack_cycle(tmp_path: Path) -> None:
    dlq = IngestDLQ(file_path=tmp_path / "ingest_dlq.jsonl", max_items=100)

    rid1 = dlq.enqueue(_sample_event(), reason="transient-timeout")
    rid2 = dlq.enqueue(_sample_event(), reason="temporary-engine-error")

    assert rid1 != rid2
    assert dlq.pending_count() == 2

    batch = dlq.peek_batch(limit=10)
    assert len(batch) == 2
    ids = {batch[0][0], batch[1][0]}

    removed = dlq.ack(ids)
    assert removed == 2
    assert dlq.pending_count() == 0


def test_dlq_max_items_caps_old_records(tmp_path: Path) -> None:
    dlq = IngestDLQ(file_path=tmp_path / "ingest_dlq.jsonl", max_items=100)

    for idx in range(107):
        event = _sample_event().model_copy(update={"bytes_in": 1000 + idx})
        dlq.enqueue(event, reason=f"err-{idx}")

    assert dlq.pending_count() == 100
    batch = dlq.peek_batch(limit=10)
    assert len(batch) == 10


def test_dlq_stats_include_path_and_queue_bounds(tmp_path: Path) -> None:
    file_path = tmp_path / "ingest_dlq.jsonl"
    dlq = IngestDLQ(file_path=file_path, max_items=50)

    stats = dlq.stats()
    assert stats["pending"] == 0
    assert stats["oldest_queued_at"] is None
    assert stats["newest_queued_at"] is None
    assert stats["storage_path"] == str(file_path)
    assert stats["max_items"] == 100  # enforced minimum guardrail
