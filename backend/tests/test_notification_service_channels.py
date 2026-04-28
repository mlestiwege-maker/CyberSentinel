from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

from app.services.notification_service import NotificationChannel, NotificationService


def _reset_notification_service_state() -> None:
    NotificationService._last_sent_at = {}
    NotificationService._recent_signatures = {
        channel: {} for channel in NotificationChannel
    }


def test_send_notification_auto_selects_configured_non_webhook_channels(monkeypatch):
    _reset_notification_service_state()
    monkeypatch.setattr("app.services.notification_service.settings.notify_email", "soc@example.com")
    monkeypatch.setattr("app.services.notification_service.settings.smtp_server", "smtp.example.com")
    monkeypatch.setattr("app.services.notification_service.settings.smtp_port", 587)
    monkeypatch.setattr("app.services.notification_service.settings.smtp_username", "soc@example.com")
    monkeypatch.setattr("app.services.notification_service.settings.smtp_password", "secret")

    monkeypatch.setattr("app.services.notification_service.settings.notify_system_enabled", True)

    async def fake_email(*args, **kwargs):
        return "success"

    async def fake_system(*args, **kwargs):
        return "success"

    monkeypatch.setattr(NotificationService, "_send_email", fake_email)
    monkeypatch.setattr(NotificationService, "_send_system", fake_system)

    # Keep webhook channels explicitly unconfigured to ensure auto-selection is config-driven.
    NotificationService._channel_configs[NotificationChannel.SLACK] = None
    NotificationService._channel_configs[NotificationChannel.TEAMS] = None

    results = asyncio.run(
        NotificationService.send_notification(
            title="Threat detected",
            message="Potential intrusion",
            severity="high",
        )
    )

    assert results.get("email") == "success"
    assert results.get("system") == "success"


def test_send_notification_respects_explicit_sms_channel(monkeypatch):
    _reset_notification_service_state()
    monkeypatch.setattr("app.services.notification_service.settings.notify_phone", "+1234567890")
    monkeypatch.setattr("app.services.notification_service.settings.twilio_account_sid", "sid")
    monkeypatch.setattr("app.services.notification_service.settings.twilio_auth_token", "token")
    monkeypatch.setattr("app.services.notification_service.settings.twilio_from_number", "+1098765432")

    async def fake_sms(*args, **kwargs):
        return "success"

    monkeypatch.setattr(NotificationService, "_send_sms", fake_sms)

    results = asyncio.run(
        NotificationService.send_notification(
            title="Critical threat",
            message="Ransomware behavior detected",
            severity="critical",
            channels=[NotificationChannel.SMS],
        )
    )

    assert results == {"sms": "success"}


def test_channel_status_marks_ready_channels(monkeypatch):
    _reset_notification_service_state()
    monkeypatch.setattr("app.services.notification_service.settings.notify_system_enabled", True)
    monkeypatch.setattr("app.services.notification_service.settings.notify_email", "soc@example.com")
    monkeypatch.setattr("app.services.notification_service.settings.smtp_server", "smtp.example.com")
    monkeypatch.setattr("app.services.notification_service.settings.smtp_port", 587)
    monkeypatch.setattr("app.services.notification_service.settings.smtp_username", "soc@example.com")
    monkeypatch.setattr("app.services.notification_service.settings.smtp_password", "secret")

    status = NotificationService.get_channel_status()

    assert status["system"] == "configured"
    assert status["email"] == "configured"


def test_set_channel_webhook_supports_email_address() -> None:
    ok = NotificationService.set_channel_webhook(
        NotificationChannel.EMAIL,
        "security-team@example.com",
    )
    bad = NotificationService.set_channel_webhook(
        NotificationChannel.EMAIL,
        "not-an-email",
    )

    assert ok is True
    assert bad is False


def test_duplicate_notifications_are_suppressed(monkeypatch):
    _reset_notification_service_state()
    monkeypatch.setattr("app.services.notification_service.settings.notify_system_enabled", True)
    monkeypatch.setattr("app.services.notification_service.settings.notify_channel_cooldown_seconds", 0)
    monkeypatch.setattr("app.services.notification_service.settings.notify_dedupe_window_seconds", 600)

    async def fake_system(*args, **kwargs):
        return "success"

    monkeypatch.setattr(NotificationService, "_send_system", fake_system)

    first = asyncio.run(
        NotificationService.send_notification(
            title="Threat detected",
            message="Potential intrusion",
            severity="high",
            channels=[NotificationChannel.SYSTEM],
        )
    )
    second = asyncio.run(
        NotificationService.send_notification(
            title="Threat detected",
            message="Potential intrusion",
            severity="high",
            channels=[NotificationChannel.SYSTEM],
        )
    )

    assert first["system"] == "success"
    assert second["system"] == "suppressed_duplicate"


def test_rate_limited_notifications_are_suppressed(monkeypatch):
    _reset_notification_service_state()
    monkeypatch.setattr("app.services.notification_service.settings.notify_system_enabled", True)
    monkeypatch.setattr("app.services.notification_service.settings.notify_channel_cooldown_seconds", 60)
    monkeypatch.setattr("app.services.notification_service.settings.notify_dedupe_window_seconds", 0)

    async def fake_system(*args, **kwargs):
        return "success"

    monkeypatch.setattr(NotificationService, "_send_system", fake_system)

    signature = NotificationService._signature_for_notification(
        "Threat A",
        "msg",
        "high",
        None,
    )
    now = datetime.now(timezone.utc)
    NotificationService._last_sent_at[NotificationChannel.SYSTEM] = now - timedelta(seconds=5)
    NotificationService._recent_signatures[NotificationChannel.SYSTEM][signature] = now - timedelta(seconds=1000)

    result = asyncio.run(
        NotificationService.send_notification(
            title="Threat B",
            message="new msg",
            severity="high",
            channels=[NotificationChannel.SYSTEM],
        )
    )

    assert result["system"] == "suppressed_rate_limited"
