from __future__ import annotations

from datetime import datetime, timedelta, timezone
import hashlib
import json

from app.models import TrafficEvent


class IngestIdempotencyWindow:
    """Tracks recent ingest signatures to avoid duplicate processing."""

    def __init__(self, ttl_seconds: int = 600, max_entries: int = 20000) -> None:
        self.ttl_seconds = max(30, ttl_seconds)
        self.max_entries = max(500, max_entries)
        self._seen: dict[str, datetime] = {}

    @staticmethod
    def signature_for_event(event: TrafficEvent) -> str:
        payload = event.model_dump(mode="json")
        canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(canonical.encode("utf-8")).hexdigest()

    def is_duplicate(self, signature: str, now: datetime | None = None) -> bool:
        now_utc = now.astimezone(timezone.utc) if now is not None else datetime.now(timezone.utc)
        self._prune(now_utc)
        return signature in self._seen

    def mark(self, signature: str, now: datetime | None = None) -> None:
        now_utc = now.astimezone(timezone.utc) if now is not None else datetime.now(timezone.utc)
        self._prune(now_utc)
        self._seen[signature] = now_utc
        if len(self._seen) > self.max_entries:
            self._trim_to_capacity()

    def check_and_mark(self, signature: str, now: datetime | None = None) -> bool:
        now_utc = now.astimezone(timezone.utc) if now is not None else datetime.now(timezone.utc)
        self._prune(now_utc)
        if signature in self._seen:
            return True

        self._seen[signature] = now_utc
        if len(self._seen) > self.max_entries:
            self._trim_to_capacity()
        return False

    def size(self) -> int:
        return len(self._seen)

    def _prune(self, now_utc: datetime) -> None:
        cutoff = now_utc - timedelta(seconds=self.ttl_seconds)
        stale = [sig for sig, at in self._seen.items() if at < cutoff]
        for sig in stale:
            self._seen.pop(sig, None)

    def _trim_to_capacity(self) -> None:
        if len(self._seen) <= self.max_entries:
            return

        # Keep most recent entries up to capacity.
        sorted_items = sorted(self._seen.items(), key=lambda item: item[1], reverse=True)
        self._seen = dict(sorted_items[: self.max_entries])
