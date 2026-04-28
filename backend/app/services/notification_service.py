"""
Notification service for sending alerts to multiple channels.
Supports: Slack, Teams, Email (SMTP), SMS (Twilio), Push (FCM), System notifications.
"""

import asyncio
import hashlib
import json
import platform
import smtplib
import subprocess
import shutil
from datetime import datetime, timedelta, timezone
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from enum import Enum
from typing import Optional
import threading

import httpx

try:
    from twilio.rest import Client as TwilioClient

    TWILIO_AVAILABLE = True
except ImportError:
    TWILIO_AVAILABLE = False
    TwilioClient = None

try:
    import firebase_admin
    from firebase_admin import messaging

    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    firebase_admin = None
    messaging = None

from ..config import settings


class NotificationChannel(str, Enum):
    """Supported notification channels."""
    SLACK = "slack"
    TEAMS = "teams"
    EMAIL = "email"
    SMS = "sms"
    PUSH = "push"  # Firebase Cloud Messaging
    SYSTEM = "system"  # Local OS/system notification


class NotificationService:
    """Service for sending notifications to configured channels."""

    # Channel webhooks and configs (set via environment or API)
    _channel_configs = {
        NotificationChannel.SLACK: None,
        NotificationChannel.TEAMS: None,
        NotificationChannel.EMAIL: None,
        NotificationChannel.SMS: None,
        NotificationChannel.PUSH: None,
        NotificationChannel.SYSTEM: None,
    }

    # Twilio client singleton
    _twilio_client = None
    # Firebase app initialized flag
    _firebase_initialized = False
    # Notification storm controls
    _storm_lock = threading.Lock()
    _last_sent_at: dict[NotificationChannel, datetime] = {}
    _recent_signatures: dict[NotificationChannel, dict[str, datetime]] = {
        channel: {} for channel in NotificationChannel
    }

    @classmethod
    def _get_twilio_client(cls):
        """Get or create Twilio client."""
        if not TWILIO_AVAILABLE:
            return None
        if cls._twilio_client is None:
            if settings.twilio_account_sid and settings.twilio_auth_token:
                cls._twilio_client = TwilioClient(
                    settings.twilio_account_sid,
                    settings.twilio_auth_token,
                )
        return cls._twilio_client

    @classmethod
    def _init_firebase(cls):
        """Initialize Firebase Admin SDK if not already done."""
        if not FIREBASE_AVAILABLE:
            return False
        if cls._firebase_initialized:
            return True
        try:
            if settings.firebase_credentials_path:
                cred = firebase_admin.credentials.Certificate(
                    settings.firebase_credentials_path
                )
                firebase_admin.initialize_app(
                    cred,
                    {'projectId': settings.firebase_project_id},
                )
            elif settings.firebase_service_account_json:
                import json
                cred = firebase_admin.credentials.Certificate(
                    json.loads(settings.firebase_service_account_json)
                )
                firebase_admin.initialize_app(
                    cred,
                    {'projectId': settings.firebase_project_id},
                )
            else:
                # Try default credentials (for Google Cloud environments)
                firebase_admin.initialize_app()
            cls._firebase_initialized = True
            return True
        except Exception as e:
            print(f"[FCM ERROR] Failed to initialize Firebase: {e}")
            return False
    
    @classmethod
    def set_channel_webhook(cls, channel: NotificationChannel, webhook_url: str) -> bool:
        """
        Set or update webhook URL for a channel.
        
        Args:
            channel: Target notification channel
            webhook_url: Webhook URL for the channel
            
        Returns:
            True if configuration was successful
        """
        value = (webhook_url or "").strip()
        if not value:
            return False

        if channel in {NotificationChannel.SLACK, NotificationChannel.TEAMS}:
            if not value.startswith("http"):
                return False
            cls._channel_configs[channel] = value
            return True

        if channel == NotificationChannel.EMAIL:
            if "@" not in value or "." not in value.split("@")[-1]:
                return False
            settings.notify_email = value
            cls._channel_configs[channel] = value
            return True

        if channel == NotificationChannel.SMS:
            normalized = value.replace(" ", "")
            if len(normalized) < 7:
                return False
            settings.notify_phone = normalized
            cls._channel_configs[channel] = normalized
            return True

        return False

    @classmethod
    def _is_channel_ready(cls, channel: NotificationChannel) -> bool:
        """Return True if the target channel is currently configured/available."""
        if channel == NotificationChannel.SLACK:
            return bool(cls._channel_configs[NotificationChannel.SLACK])

        if channel == NotificationChannel.TEAMS:
            return bool(cls._channel_configs[NotificationChannel.TEAMS])

        if channel == NotificationChannel.EMAIL:
            return bool(
                settings.notify_email
                and settings.smtp_server
                and settings.smtp_port
                and settings.smtp_username
                and settings.smtp_password
            )

        if channel == NotificationChannel.SMS:
            return bool(
                TWILIO_AVAILABLE
                and settings.notify_phone
                and settings.twilio_account_sid
                and settings.twilio_auth_token
                and settings.twilio_from_number
            )

        if channel == NotificationChannel.PUSH:
            return bool(FIREBASE_AVAILABLE and settings.notify_push_topic)

        if channel == NotificationChannel.SYSTEM:
            return bool(getattr(settings, "notify_system_enabled", True))

        return False

    @classmethod
    def _resolve_channels(cls, channels: Optional[list[NotificationChannel]]) -> list[NotificationChannel]:
        """Resolve effective channel list (explicit or auto-detected configured channels)."""
        if channels is None:
            return [ch for ch in NotificationChannel if cls._is_channel_ready(ch)]

        # Keep caller-specified channels in order, but only once.
        resolved: list[NotificationChannel] = []
        for ch in channels:
            if ch not in resolved:
                resolved.append(ch)
        return resolved

    @classmethod
    def _signature_for_notification(
        cls,
        title: str,
        message: str,
        severity: str,
        details: Optional[dict],
    ) -> str:
        payload = {
            "title": title,
            "message": message,
            "severity": severity.lower().strip(),
            "details": details or {},
        }
        canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(canonical.encode("utf-8")).hexdigest()

    @classmethod
    def _prune_signatures(cls, channel: NotificationChannel, now: datetime, dedupe_seconds: int) -> None:
        cutoff = now - timedelta(seconds=dedupe_seconds)
        stale = [
            signature
            for signature, seen_at in cls._recent_signatures[channel].items()
            if seen_at < cutoff
        ]
        for signature in stale:
            cls._recent_signatures[channel].pop(signature, None)

    @classmethod
    def _should_dispatch(
        cls,
        channel: NotificationChannel,
        signature: str,
    ) -> tuple[bool, str]:
        now = datetime.now(timezone.utc)
        cooldown = max(0, int(getattr(settings, "notify_channel_cooldown_seconds", 20)))
        dedupe_window = max(0, int(getattr(settings, "notify_dedupe_window_seconds", 120)))

        with cls._storm_lock:
            cls._prune_signatures(channel, now, dedupe_window)

            if dedupe_window > 0 and signature in cls._recent_signatures[channel]:
                return False, "suppressed_duplicate"

            last_sent = cls._last_sent_at.get(channel)
            if cooldown > 0 and last_sent is not None:
                if now - last_sent < timedelta(seconds=cooldown):
                    return False, "suppressed_rate_limited"

            cls._last_sent_at[channel] = now
            if dedupe_window > 0:
                cls._recent_signatures[channel][signature] = now

        return True, "ready"
    
    @classmethod
    def get_channel_status(cls) -> dict:
        """
        Get status of all notification channels.
        
        Returns:
            Dict with channel status {channel: configured/not_configured}
        """
        return {
            channel.value: "configured" if cls._is_channel_ready(channel) else "not_configured"
            for channel in NotificationChannel
        }
    
    @classmethod
    async def send_notification(
        cls,
        title: str,
        message: str,
        severity: str = "medium",
        details: Optional[dict] = None,
        channels: Optional[list[NotificationChannel]] = None,
    ) -> dict:
        """
        Send notification to configured channels.
        
        Args:
            title: Notification title
            message: Notification body
            severity: Severity level (critical, high, medium, low)
            details: Additional contextual details
            channels: Specific channels to target (None = all configured)
            
        Returns:
            Dict with send results {channel: success/failed}
        """
        channels = cls._resolve_channels(channels)
        
        results: dict[str, str] = {}
        tasks = []
        scheduled_channels: list[NotificationChannel] = []
        signature = cls._signature_for_notification(title, message, severity, details)
        
        for channel in channels:
            should_dispatch, state = cls._should_dispatch(channel, signature)
            if not should_dispatch:
                results[channel.value] = state
                continue

            if channel == NotificationChannel.SLACK:
                tasks.append(cls._send_slack(title, message, severity, details))
                scheduled_channels.append(channel)
            elif channel == NotificationChannel.TEAMS:
                tasks.append(cls._send_teams(title, message, severity, details))
                scheduled_channels.append(channel)
            elif channel == NotificationChannel.EMAIL:
                tasks.append(cls._send_email(title, message, severity, details))
                scheduled_channels.append(channel)
            elif channel == NotificationChannel.SMS:
                tasks.append(cls._send_sms(title, message, severity, details))
                scheduled_channels.append(channel)
            elif channel == NotificationChannel.PUSH:
                tasks.append(cls._send_push(title, message, severity, details))
                scheduled_channels.append(channel)
            elif channel == NotificationChannel.SYSTEM:
                tasks.append(cls._send_system(title, message, severity, details))
                scheduled_channels.append(channel)
        
        if tasks:
            result_list = await asyncio.gather(*tasks, return_exceptions=True)
            for channel, result in zip(scheduled_channels, result_list):
                if isinstance(result, Exception):
                    results[channel.value] = f"failed: {result}"
                else:
                    results[channel.value] = str(result)
        
        return results
    
    @classmethod
    async def _send_slack(
        cls,
        title: str,
        message: str,
        severity: str,
        details: Optional[dict],
    ) -> str:
        """Send notification to Slack webhook."""
        webhook_url = cls._channel_configs[NotificationChannel.SLACK]
        if not webhook_url:
            return "not_configured"
        
        severity_color = {
            "critical": "#FF0000",
            "high": "#FF6600",
            "medium": "#FFAA00",
            "low": "#00CC00",
        }.get(severity.lower(), "#0099CC")
        
        payload = {
            "attachments": [
                {
                    "color": severity_color,
                    "title": title,
                    "text": message,
                    "fields": [
                        {"title": "Severity", "value": severity, "short": True},
                        {"title": "Time", "value": datetime.now().isoformat(), "short": True},
                    ],
                    "footer": "CyberSentinel",
                    "footer_icon": "https://platform.slack-edge.com/img/default_application_icon.png",
                }
            ]
        }
        
        # Add details if provided
        if details:
            for key, value in details.items():
                payload["attachments"][0]["fields"].append({
                    "title": key.title(),
                    "value": str(value),
                    "short": True,
                })
        
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.post(webhook_url, json=payload)
                return "success" if response.status_code in [200, 204] else "failed"
        except Exception as e:
            return f"failed: {str(e)}"
    
    @classmethod
    async def _send_teams(
        cls,
        title: str,
        message: str,
        severity: str,
        details: Optional[dict],
    ) -> str:
        """Send notification to Microsoft Teams webhook."""
        webhook_url = cls._channel_configs[NotificationChannel.TEAMS]
        if not webhook_url:
            return "not_configured"
        
        severity_color = {
            "critical": "FF0000",
            "high": "FF6600",
            "medium": "FFAA00",
            "low": "00CC00",
        }.get(severity.lower(), "0099CC")
        
        facts = [
            {"name": "Severity", "value": severity},
            {"name": "Time", "value": datetime.now().isoformat()},
        ]
        
        if details:
            for key, value in details.items():
                facts.append({"name": key.title(), "value": str(value)})
        
        payload = {
            "@type": "MessageCard",
            "@context": "https://schema.org/extensions",
            "summary": title,
            "themeColor": severity_color,
            "sections": [
                {
                    "activityTitle": title,
                    "text": message,
                    "facts": facts,
                }
            ],
        }
        
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.post(webhook_url, json=payload)
                return "success" if response.status_code in [200, 204] else "failed"
        except Exception as e:
            return f"failed: {str(e)}"
    
    @classmethod
    async def _send_email(
        cls,
        title: str,
        message: str,
        severity: str,
        details: Optional[dict],
    ) -> str:
        """Send notification via SMTP email."""
        email_to = settings.notify_email
        
        if not email_to or not settings.smtp_username or not settings.smtp_password:
            return "not_configured"
        
        # Build email body
        email_body = f"""
CyberSentinel Security Alert

Title: {title}
Severity: {severity}
Message: {message}
Time: {datetime.now().isoformat()}

Details:
"""
        if details:
            for key, value in details.items():
                email_body += f"  {key}: {value}\n"
        
        # Build HTML body
        html_body = f"""
<html>
<body>
<h2>CyberSentinel Security Alert</h2>
<p><strong>Title:</strong> {title}</p>
<p><strong>Severity:</strong> <span style="color: {'red' if severity.lower() == 'critical' else 'orange' if severity.lower() == 'high' else 'gold' if severity.lower() == 'medium' else 'green'}">{severity.upper()}</span></p>
<p><strong>Message:</strong> {message}</p>
<p><strong>Time:</strong> {datetime.now().isoformat()}</p>
<hr>
<h3>Details:</h3>
<ul>
"""
        if details:
            for key, value in details.items():
                html_body += f"  <li><strong>{key.title()}:</strong> {value}</li>\n"
        html_body += "</ul></body></html>"
        
        # Create message
        msg = MIMEMultipart('alternative')
        msg['Subject'] = f"[CyberSentinel] {title}"
        msg['From'] = settings.smtp_username
        msg['To'] = email_to
        
        # Attach parts
        part1 = MIMEText(email_body, 'plain')
        part2 = MIMEText(html_body, 'html')
        msg.attach(part1)
        msg.attach(part2)
        
        # Send email
        try:
            if settings.smtp_use_tls:
                server = smtplib.SMTP(settings.smtp_server, settings.smtp_port)
                server.starttls()
                server.login(settings.smtp_username, settings.smtp_password)
            else:
                server = smtplib.SMTP(settings.smtp_server, settings.smtp_port)
                server.login(settings.smtp_username, settings.smtp_password)
            
            server.sendmail(settings.smtp_username, email_to, msg.as_string())
            server.quit()
            return "success"
        except Exception as e:
            print(f"[EMAIL ERROR] {str(e)}")
            return f"failed: {str(e)}"

    @classmethod
    async def _send_sms(
        cls,
        title: str,
        message: str,
        severity: str,
        details: Optional[dict],
    ) -> str:
        """Send notification via Twilio SMS."""
        if not TWILIO_AVAILABLE:
            return "twilio_not_installed"
        
        if not settings.twilio_account_sid or not settings.twilio_auth_token:
            return "not_configured"
        
        phone_to = settings.notify_phone
        if not phone_to:
            return "phone_not_configured"
        
        client = cls._get_twilio_client()
        if client is None:
            return "twilio_init_failed"
        
        # Build SMS body (keep it short)
        sms_body = f"[CyberSentinel] {severity.upper()}: {title}\n{message[:100]}"
        if details:
            sms_body += f"\nTime: {datetime.now().strftime('%H:%M:%S')}"
        
        try:
            message = client.messages.create(
                body=sms_body,
                from_=settings.twilio_from_number,
                to=phone_to,
            )
            return "success" if message.sid else "failed"
        except Exception as e:
            print(f"[SMS ERROR] {str(e)}")
            return f"failed: {str(e)}"

    @classmethod
    async def _send_push(
        cls,
        title: str,
        message: str,
        severity: str,
        details: Optional[dict],
    ) -> str:
        """Send push notification via Firebase Cloud Messaging."""
        if not FIREBASE_AVAILABLE:
            return "firebase_not_installed"
        
        if not cls._init_firebase():
            return "firebase_not_initialized"
        
        try:
            # Build notification
            notification = messaging.Notification(
                title=title,
                body=message[:200],  # FCM has body length limits
            )
            
            # Build data payload
            data = {
                "severity": severity,
                "timestamp": datetime.now().isoformat(),
            }
            if details:
                for key, value in details.items():
                    data[key] = str(value)[:100]  # Limit data size
            
            # Send to topic (all devices subscribed to this topic)
            if settings.notify_push_topic:
                message = messaging.Message(
                    notification=notification,
                    data=data,
                    topic=settings.notify_push_topic,
                )
                response = messaging.send(message)
                return "success" if response else "failed"
            
            return "topic_not_configured"
        except Exception as e:
            print(f"[FCM ERROR] {str(e)}")
            return f"failed: {str(e)}"

    @classmethod
    async def _send_system(
        cls,
        title: str,
        message: str,
        severity: str,
        details: Optional[dict],
    ) -> str:
        """Send a local OS-level system notification."""
        if not getattr(settings, "notify_system_enabled", True):
            return "not_configured"

        body = f"{severity.upper()}: {message[:180]}"
        system_name = platform.system().lower()

        def _run() -> str:
            try:
                if "linux" in system_name:
                    notifier = shutil.which("notify-send")
                    if not notifier:
                        return "not_supported"
                    subprocess.run([notifier, title, body], check=True)
                    return "success"

                if "darwin" in system_name:
                    script = (
                        'display notification "'
                        + body.replace('"', "'")
                        + '" with title "'
                        + title.replace('"', "'")
                        + '"'
                    )
                    subprocess.run(["osascript", "-e", script], check=True)
                    return "success"

                if "windows" in system_name:
                    # Fallback notification via msg.exe for local sessions.
                    msg = shutil.which("msg")
                    if not msg:
                        return "not_supported"
                    subprocess.run([msg, "*", f"{title}: {body}"], check=True)
                    return "success"

                return "not_supported"
            except Exception as exc:
                return f"failed: {exc}"

        return await asyncio.to_thread(_run)
