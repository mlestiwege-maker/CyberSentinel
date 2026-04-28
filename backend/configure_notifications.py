#!/usr/bin/env python3
"""
Interactive configuration script for email and SMS setup in CyberSentinel.
Guides you through collecting credentials and tests them.
"""

import os
import sys
from pathlib import Path

def read_secret(prompt: str) -> str:
    """Safely read sensitive input."""
    import getpass
    return getpass.getpass(prompt)

def read_input(prompt: str) -> str:
    """Read non-sensitive input."""
    return input(f"{prompt}: ").strip()

def validate_email(email: str) -> bool:
    """Basic email validation."""
    return "@" in email and "." in email.split("@")[-1]

def validate_phone(phone: str) -> bool:
    """Validate phone number format."""
    # Should start with + and contain 10-15 digits
    digits = "".join(c for c in phone if c.isdigit())
    return phone.startswith("+") and 10 <= len(digits) <= 15

def validate_twilio_sid(sid: str) -> bool:
    """Validate Twilio Account SID format."""
    return sid.startswith("AC") and len(sid) == 34

def configure_email():
    """Configure email (SMTP) settings."""
    print("\n" + "="*60)
    print("📧 EMAIL CONFIGURATION (SMTP)")
    print("="*60)
    
    print("\n🔗 If using Gmail:")
    print("   1. Go to: https://myaccount.google.com/apppasswords")
    print("   2. Select: Mail → Other")
    print("   3. Copy the 16-character password")
    print("   4. Paste below (remove spaces)")
    
    email = read_input("\n✉️  Email address for alerts")
    if not validate_email(email):
        print("❌ Invalid email format")
        return None
    
    smtp_user = read_input("📬 SMTP username (usually your email)")
    smtp_pass = read_secret("🔑 SMTP password (will not be displayed): ")
    
    if not smtp_pass:
        print("❌ Password cannot be empty")
        return None
    
    return {
        "notify_email": email,
        "smtp_username": smtp_user,
        "smtp_password": smtp_pass,
    }

def configure_twilio():
    """Configure Twilio SMS settings."""
    print("\n" + "="*60)
    print("📱 TWILIO SMS CONFIGURATION")
    print("="*60)
    
    print("\n🔗 Get free Twilio account:")
    print("   1. Sign up: https://www.twilio.com/console")
    print("   2. Verify your phone number")
    print("   3. Get your Account SID, Auth Token, and phone number")
    print("   4. Paste credentials below")
    
    account_sid = read_input("\n🆔 Twilio Account SID (starts with AC)")
    if not validate_twilio_sid(account_sid):
        print(f"❌ Invalid Account SID format (should be AC followed by 32 chars)")
        return None
    
    auth_token = read_secret("🔑 Twilio Auth Token (will not be displayed): ")
    if not auth_token or len(auth_token) < 32:
        print("❌ Auth Token seems invalid (too short)")
        return None
    
    from_number = read_input("📞 Twilio phone number (format: +1XXXXXXXXXX)")
    if not validate_phone(from_number):
        print(f"❌ Invalid phone format. Use +country-code + number (e.g., +1234567890)")
        return None
    
    to_number = read_input("📱 Your phone number to receive SMS (format: +1XXXXXXXXXX)")
    if not validate_phone(to_number):
        print(f"❌ Invalid phone format. Use +country-code + number")
        return None
    
    return {
        "twilio_account_sid": account_sid,
        "twilio_auth_token": auth_token,
        "twilio_from_number": from_number,
        "notify_phone": to_number,
    }

def update_env_file(config: dict) -> bool:
    """Update the .env file with new credentials."""
    env_path = Path(".env")
    
    if not env_path.exists():
        print(f"❌ .env file not found at {env_path.absolute()}")
        return False
    
    # Read current .env
    with open(env_path, "r") as f:
        lines = f.readlines()
    
    # Build replacement map
    replacements = {
        "NOTIFY_EMAIL": config.get("notify_email"),
        "SMTP_USERNAME": config.get("smtp_username"),
        "SMTP_PASSWORD": config.get("smtp_password"),
        "TWILIO_ACCOUNT_SID": config.get("twilio_account_sid"),
        "TWILIO_AUTH_TOKEN": config.get("twilio_auth_token"),
        "TWILIO_FROM_NUMBER": config.get("twilio_from_number"),
        "NOTIFY_PHONE": config.get("notify_phone"),
    }
    
    # Update lines
    updated_lines = []
    for line in lines:
        updated = False
        for key, value in replacements.items():
            if value and line.startswith(key + "="):
                updated_lines.append(f"{key}={value}\n")
                updated = True
                break
        if not updated:
            updated_lines.append(line)
    
    # Write back
    with open(env_path, "w") as f:
        f.writelines(updated_lines)
    
    print(f"\n✅ Updated {env_path}")
    return True

def test_configuration():
    """Test email and SMS configuration."""
    print("\n" + "="*60)
    print("🧪 TEST CONFIGURATION")
    print("="*60)
    
    try:
        from app.config import settings
        from app.services.notification_service import NotificationService
        
        print("\n📋 Current Configuration:")
        print(f"  Email: {settings.notify_email}")
        print(f"  SMTP: {settings.smtp_username}@{settings.smtp_server}:{settings.smtp_port}")
        print(f"  Twilio From: {settings.twilio_from_number}")
        print(f"  Twilio To: {settings.notify_phone}")
        
        # Check if channels are ready
        print("\n🔍 Channel Readiness:")
        
        email_ready = NotificationService._is_channel_ready(
            NotificationService._channel_configs.__class__.EMAIL 
            if hasattr(NotificationService._channel_configs.__class__, 'EMAIL') 
            else "email"
        )
        print(f"  Email channel: {'✅ Ready' if email_ready else '❌ Not ready'}")
        
        sms_ready = NotificationService._is_channel_ready(
            NotificationService._channel_configs.__class__.SMS 
            if hasattr(NotificationService._channel_configs.__class__, 'SMS')
            else "sms"
        )
        print(f"  SMS channel: {'✅ Ready' if sms_ready else '❌ Not ready'}")
        
        return email_ready and sms_ready
        
    except Exception as e:
        print(f"❌ Error testing configuration: {e}")
        return False

def main():
    """Main configuration flow."""
    print("\n")
    print("╔" + "="*58 + "╗")
    print("║" + " "*15 + "CyberSentinel Configuration Setup" + " "*10 + "║")
    print("╚" + "="*58 + "╝")
    
    config = {}
    
    # Email setup
    print("\n1️⃣  Would you like to configure EMAIL? (y/n)")
    if input().lower().startswith("y"):
        email_config = configure_email()
        if email_config:
            config.update(email_config)
            print("✅ Email configuration collected")
    
    # SMS setup
    print("\n2️⃣  Would you like to configure SMS (Twilio)? (y/n)")
    if input().lower().startswith("y"):
        sms_config = configure_twilio()
        if sms_config:
            config.update(sms_config)
            print("✅ SMS configuration collected")
    
    if not config:
        print("\n⚠️  No configuration provided")
        return
    
    # Update .env
    print("\n3️⃣  Saving to .env file...")
    if update_env_file(config):
        print("✅ Configuration saved")
    else:
        print("❌ Failed to save configuration")
        return
    
    # Optional: Test
    print("\n4️⃣  Would you like to test the configuration? (y/n)")
    if input().lower().startswith("y"):
        test_configuration()
    
    print("\n" + "="*60)
    print("✅ Configuration complete!")
    print("\nNext steps:")
    print("  1. Restart the backend: python -m uvicorn app.main:app --reload")
    print("  2. Send test notification: curl http://localhost:8000/api/v1/test-notification")
    print("="*60 + "\n")

if __name__ == "__main__":
    main()
