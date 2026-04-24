from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "CyberSentinel Backend"
    app_env: str = "development"
    alert_anomaly_threshold: float = 0.78
    alert_critical_threshold: float = 0.90
    simulation_enabled: bool = True
    notify_email: str = "security-admin@example.com"
    notify_push_topic: str = "cybersentinel-alerts"


settings = Settings()
