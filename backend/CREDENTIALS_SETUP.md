# CyberSentinel Configuration Setup Guide
# This file helps you configure email (SMTP) and SMS (Twilio) for your system.
# Follow the instructions below and fill in your credentials.

## ✉️ EMAIL (SMTP) CONFIGURATION

### Step 1: Get Gmail App Password (Recommended)
1. Go to https://myaccount.google.com/apppasswords
2. Select: Apps → Mail, Device → Other (custom name)
3. Copy the 16-character password (remove spaces)
4. Paste it in SMTP_PASSWORD below

YOUR_EMAIL_HERE=your-email@gmail.com
YOUR_SMTP_PASSWORD_HERE=xxxx xxxx xxxx xxxx

---

## 📱 SMS (TWILIO) CONFIGURATION

### Step 2: Get Twilio Credentials
1. Sign up free: https://www.twilio.com/console
2. Verify your phone number
3. Copy from Twilio Console:
   - Account SID (looks like: AC...)
   - Auth Token (looks like: long string)
4. Get a Twilio phone number (free trial gives you one)
   - Format: +1XXXXXXXXXX (must include country code)

YOUR_TWILIO_ACCOUNT_SID_HERE=AC...
YOUR_TWILIO_AUTH_TOKEN_HERE=long_token_string
YOUR_TWILIO_PHONE_NUMBER_HERE=+1XXXXXXXXXX

---

## 📋 How to Apply These

Once you have your credentials, let me know:
1. Your email address for alerts
2. Your Gmail app password (or SMTP password)
3. Your Twilio Account SID
4. Your Twilio Auth Token
5. Your Twilio phone number to send from
6. The phone number to receive SMS alerts

I'll securely configure everything for you.
