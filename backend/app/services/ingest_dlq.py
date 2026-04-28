from __future__ import annotations

from datetime import datetime, timezone
import json
from pathlib import Path
import threading
import uuid

from app.models import TrafficEvent


class IngestDLQ:
    """Persistent dead-letter queue for failed ingest events."""

    def __init__(self, file_path: Path | None = None, max_items: int = 5000) -> None:
        self.file_path = file_path or (Path(__file__).parent.parent / "data" / "ingest_dlq.jsonl")
        self.max_items = max(100, max_items)
        self._lock = threading.Lock()
        self.file_path.parent.mkdir(parents=True, exist_ok=True)
        if not self.file_path.exists():
            self.file_path.touch()

    def enqueue(self, event: TrafficEvent, reason: str) -> str:
        """Persist a failed event into the DLQ and return its record ID."""
        record_id = str(uuid.uuid4())
        record = {
            "id": record_id,
            "queued_at": datetime.now(timezone.utc).isoformat(),
            "reason": reason,
            "event": event.model_dump(mode="json"),
        }

        with self._lock:
            records = self._load_records_unlocked()
            records.append(record)
            if len(records) > self.max_items:
                records = records[-self.max_items :]
            self._rewrite_records_unlocked(records)

        return record_id

    def pending_count(self) -> int:
        with self._lock:
            return len(self._load_records_unlocked())

    def peek_batch(self, limit: int = 20) -> list[tuple[str, TrafficEvent]]:
        """Return up to `limit` queued events without removing them."""
        capped = max(1, min(limit, 200))
        with self._lock:
            records = self._load_records_unlocked()[:capped]

        batch: list[tuple[str, TrafficEvent]] = []
        for record in records:
            record_id = str(record.get("id", ""))
            raw_event = record.get("event", {})
            if not record_id:
                continue
            try:
                event = TrafficEvent.model_validate(raw_event)
                batch.append((record_id, event))
            except Exception:
                # Keep unreadable records in file to avoid destructive behavior.
                continue

        return batch

    def ack(self, record_ids: set[str]) -> int:
        """Remove acknowledged records from DLQ and return removed count."""
        if not record_ids:
            return 0

        with self._lock:
            records = self._load_records_unlocked()
            kept = [r for r in records if str(r.get("id", "")) not in record_ids]
            removed = len(records) - len(kept)
            if removed > 0:
                self._rewrite_records_unlocked(kept)
            return removed

    def stats(self) -> dict[str, object]:
        """Return current DLQ status details for observability endpoints."""
        with self._lock:
            records = self._load_records_unlocked()

        oldest = records[0]["queued_at"] if records else None
        newest = records[-1]["queued_at"] if records else None

        return {
            "pending": len(records),
            "oldest_queued_at": oldest,
            "newest_queued_at": newest,
            "storage_path": str(self.file_path),
            "max_items": self.max_items,
        }

    def _load_records_unlocked(self) -> list[dict]:
        records: list[dict] = []
        if not self.file_path.exists():
            return records

        for line in self.file_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                parsed = json.loads(line)
                if isinstance(parsed, dict):
                    records.append(parsed)
            except json.JSONDecodeError:
                continue

        return records

    def _rewrite_records_unlocked(self, records: list[dict]) -> None:
        payload = "\n".join(json.dumps(record, separators=(",", ":")) for record in records)
        if payload:
            payload = f"{payload}\n"
        self.file_path.write_text(payload, encoding="utf-8")
