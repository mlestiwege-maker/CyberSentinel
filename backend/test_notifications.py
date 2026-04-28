#!/usr/bin/env python3
"""
Test script for CyberSentinel real-time notifications.
Run: cd cybersentinel_backend && source ../.venv/bin/activate && python test_notifications.py
"""

import asyncio
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(__file__))

from app.services.notification_service import NotificationService, NotificationChannel
from app.config import settings


async def test_email():
    """Test email notification."""
    print("\n" + "="*50)
    print("TESTING EMAIL NOTIFICATION (SMTP)")
    print("="*50)
    
    if not settings.smtp_username or not settings.smtp_password:
        print("❌ SMTP not configured. Set these in .env:")
        print("   SMTP_SERVER=smtp.gmail.com")
        print("   SMTP_PORT=587")
        print("   SMTP_USERNAME=mlestiwege@gmail.com")
        print("   SMTP_PASSWORD=your_app_password")
        return False
    
    print(f"📧 Sending test email to: {settings.notify_email}")
    print(f"📧 SMTP Server: {settings.smtp_server}:{settings.smtp_port}")
    
    result = await NotificationService._send_email(
        title="CyberSentinel Test: Email Alert",
        message="This is a test email notification from CyberSentinel real-time notification system.",
        severity="High",
        details={
            "test": "true",
            "source": "notification_test",
            "timestamp": "2026-04-24T13:45:00",
        }
    )
    
    if "success" in str(result).lower():
        print(f"✅ Email sent successfully! ({result})")
        return True
    else:
        print(f"❌ Email failed: {result}")
        return False


async def test_sms():
    """Test SMS notification via Twilio."""
    print("\n" + "="*50)
    print("TESTING SMS NOTIFICATION (Twilio)")
    print("="*50)
    
    if not settings.twilio_account_sid or not settings.twilio_auth_token:
        print("❌ Twilio not configured. Set these in .env:")
        print("   TWILIO_ACCOUNT_SID=your_account_sid")
        print("   TWILIO_AUTH_TOKEN=your_auth_token")
        print("   TWILIO_FROM_NUMBER=your_twilio_number")
        print("   NOTIFY_PHONE=0712246543")
        return False
    
    print(f"📱 Sending test SMS to: {settings.notify_phone}")
    
    result = await NotificationService._send_sms(
        title="CyberSentinel Test: SMS Alert",
        message="Test SMS from CyberSentinel. Threat detected: Ransomware (confidence: 89%)",
        severity="Critical",
        details=None
    )
    
    if "success" in str(result).lower():
        print(f"✅ SMS sent successfully! ({result})")
        return True
    else:
        print(f"❌ SMS failed: {result}")
        return False


async def test_push():
    """Test push notification via Firebase FCM."""
    print("\n" + "="*50)
    print("TESTING PUSH NOTIFICATION (Firebase FCM)")
    print("="*50)
    
    if not settings.firebase_credentials_path and not settings.firebase_service_account_json:
        print("❌ Firebase not configured. Set these in .env:")
        print("   FIREBASE_CREDENTIALS_PATH=/path/to/service-account.json")
        print("   FIREBASE_PROJECT_ID=your_project_id")
        print("   NOTIFY_PUSH_TOPIC=cybersentinel-alerts")
        return False
    
    print(f"📲 Sending test push to topic: {settings.notify_push_topic}")
    
    result = await NotificationService._send_push(
        title="CyberSentinel Test: Push Alert",
        message="Test push notification. Medium severity threat detected from 192.168.1.100.",
        severity="Medium",
        details={
            "alert_id": "ALT-2026-0001",
            "attack_type": "Port Scan",
        }
    )
    
    if "success" in str(result).lower():
        print(f"✅ Push notification sent successfully! ({result})")
        return True
    else:
        print(f"❌ Push notification failed: {result}")
        return False


async def test_all_channels():
    """Test all notification channels at once (like real alert)."""
    print("\n" + "="*50)
    print("TESTING ALL CHANNELS (Simulated Threat Alert)")
    print("="*50)
    
    print("\n🚨 Simulating threat detection...")
    print("   Attack Type: Ransomware")
    print("   Severity: Critical")
    print("   Source IP: 192.168.1.100")
    print("   Confidence: 92.5%")
    
    results = await NotificationService.send_notification(
        title="Security Alert: Ransomware",
        message="Potential Ransomware detected. Adaptive model confidence elevated due to anomalous network behavior.",
        severity="Critical",
        details={
            "alert_id": "ALT-2026-0042",
            "attack_type": "Ransomware",
            "source_ip": "192.168.1.100",
            "confidence": "92.5%",
            "description": "Port 445 access detected from internal IP with high anomaly score.",
        }
    )
    
    print(f"\n📊 Results:")
    for channel, result in results.items():
        status = "✅" if "success" in str(result).lower() else "❌"
        print(f"   {status} {channel}: {result}")
    
    return results


async def main():
    """Run all tests."""
    print("\n" + "🔔 " * 20)
    print("CyberSentinel Real-Time Notifications - Test Suite")
    print("🔔 " * 20)
    
    # Check configuration
    print("\n📋 Current Configuration:")
    print(f"   Email (SMTP): {settings.smtp_username if settings.smtp_username else '❌ Not configured'}")
    print(f"   SMS (Twilio): {settings.twilio_account_sid[:20] + '...' if settings.twilio_account_sid else '❌ Not configured'}")
    print(f"   Push (Firebase): {'✅ Configured' if settings.firebase_credentials_path or settings.firebase_service_account_json else '❌ Not configured'}")
    print(f"   Target Email: {settings.notify_email}")
    print(f"   Target Phone: {settings.notify_phone if settings.notify_phone else '❌ Not set'}")
    
    # Run individual tests
    await test_email()
    await test_sms()
    await test_push()
    
    # Run combined test
    await test_all_channels()
    
    print("\n" + "="*50)
    print("TEST SUITE COMPLETE")
    print("="*50)
    print("\nNext steps:")
    print("1. Configure missing channels in .env file")
    print("2. Restart backend to load new configuration")
    print("3. Alerts will automatically trigger notifications when threats are detected")


if __name__ == "__main__":
    asyncio.run(main())
