"""
Notification service for sending alerts to multiple channels.
Supports: Slack, Teams, Email webhooks.
"""

import asyncio
import json
from datetime import datetime
from enum import Enum
from typing import Optional

import httpx

from ..config import settings


class NotificationChannel(str, Enum):
    """Supported notification channels."""
    SLACK = "slack"
    TEAMS = "teams"
    EMAIL = "email"


class NotificationService:
    """Service for sending notifications to configured channels."""
    
    # Channel webhooks and configs (set via environment or API)
    _channel_configs = {
        NotificationChannel.SLACK: None,
        NotificationChannel.TEAMS: None,
        NotificationChannel.EMAIL: None,
    }
    
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
        if not webhook_url or not webhook_url.startswith("http"):
            return False
        cls._channel_configs[channel] = webhook_url
        return True
    
    @classmethod
    def get_channel_status(cls) -> dict:
        """
        Get status of all notification channels.
        
        Returns:
            Dict with channel status {channel: configured/not_configured}
        """
        return {
            channel.value: "configured" if cls._channel_configs[channel] else "not_configured"
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
        if channels is None:
            channels = [ch for ch in NotificationChannel if cls._channel_configs[ch]]
        
        results = {}
        tasks = []
        
        for channel in channels:
            if channel == NotificationChannel.SLACK:
                tasks.append(cls._send_slack(title, message, severity, details))
            elif channel == NotificationChannel.TEAMS:
                tasks.append(cls._send_teams(title, message, severity, details))
            elif channel == NotificationChannel.EMAIL:
                tasks.append(cls._send_email(title, message, severity, details))
        
        if tasks:
            result_list = await asyncio.gather(*tasks, return_exceptions=True)
            for channel, result in zip(channels, result_list):
                results[channel.value] = result
        
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
        """Send notification via email (stub for production integration)."""
        # In production, would use smtplib or sendgrid/ses
        # For now, this is a placeholder that logs to console
        email_to = settings.notify_email
        
        email_body = f"""
CyberSentinel Alert

Title: {title}
Severity: {severity}
Message: {message}
Time: {datetime.now().isoformat()}

Details:
"""
        if details:
            for key, value in details.items():
                email_body += f"  {key}: {value}\n"
        
        # Simulate email send
        print(f"[EMAIL] To: {email_to}")
        print(f"[EMAIL] Subject: {title}")
        print(f"[EMAIL] Body:\n{email_body}")
        
        return "success"  # Simulate success for now
