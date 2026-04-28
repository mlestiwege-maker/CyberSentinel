from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "CyberSentinel Backend"
    app_env: str = "development"
    alert_anomaly_threshold: float = 0.78
    alert_critical_threshold: float = 0.90
    simulation_enabled: bool = True
    notify_email: str = "security-admin@example.com"
    notify_phone: str = ""
    notify_push_topic: str = "cybersentinel-alerts"
    notify_system_enabled: bool = True
    notify_channel_cooldown_seconds: int = 20
    notify_dedupe_window_seconds: int = 120

    # SMTP Configuration for Email Alerts
    smtp_server: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_use_tls: bool = True

    # Twilio Configuration for SMS Alerts
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_from_number: str = ""

    # Firebase Configuration for Push Notifications (FCM)
    firebase_credentials_path: str = ""
    firebase_service_account_json: str = ""
    firebase_project_id: str = ""

    # Authentication / RBAC gateway settings
    auth_enforced: bool = False
    auth_secret_key: str = "change-me-in-env"
    auth_token_ttl_minutes: int = 240
    auth_admin_username: str = "admin"
    auth_admin_password: str = "admin123"
    auth_responder_username: str = "responder"
    auth_responder_password: str = "responder123"
    auth_analyst_username: str = "analyst"
    auth_analyst_password: str = "analyst123"


settings = Settings()
