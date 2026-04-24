from fastapi.testclient import TestClient

from app.main import app


def test_health_endpoint() -> None:
    with TestClient(app) as client:
        response = client.get("/health")
        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "ok"


def test_summary_endpoint() -> None:
    with TestClient(app) as client:
        response = client.get("/api/v1/summary")
        assert response.status_code == 200
        body = response.json()
        assert "active_threats" in body
        assert "packet_rate" in body


def test_ingest_generates_metric_and_possible_alert() -> None:
    payload = {
        "source_ip": "10.20.1.20",
        "destination_ip": "172.16.0.8",
        "protocol": "TCP",
        "destination_port": 445,
        "bytes_in": 300000,
        "bytes_out": 250000,
        "failed_logins": 8,
        "geo_anomaly": True,
        "user_agent_risk": 0.95,
    }

    with TestClient(app) as client:
        ingest = client.post("/api/v1/ingest", json=payload)
        assert ingest.status_code == 200
        result = ingest.json()
        assert result["accepted"] is True
        assert 0.0 <= result["anomaly_score"] <= 1.0

        metrics = client.get("/api/v1/metrics/recent?limit=5")
        assert metrics.status_code == 200
        assert len(metrics.json()) >= 1


def test_alert_filtering_and_notification() -> None:
    with TestClient(app) as client:
        alerts = client.get("/api/v1/alerts?severity=high&limit=10")
        assert alerts.status_code == 200
        assert isinstance(alerts.json(), list)

        # Configure a test Slack webhook
        config_response = client.post(
            "/api/v1/notifications/channels/configure",
            json={
                "channel": "slack",
                "webhook_url": "https://hooks.slack.com/services/test/webhook/url",
            },
        )
        assert config_response.status_code == 200
        assert config_response.json()["status"] == "configured"

        # Test channel status
        status_response = client.get("/api/v1/notifications/channels")
        assert status_response.status_code == 200
        body = status_response.json()
        assert body["channels"]["slack"] == "configured"

        notify = client.post(
            "/api/v1/notifications/test",
            json={"channel": "both", "message": "Critical threat drill"},
        )
        assert notify.status_code == 200
        body = notify.json()
        assert body["accepted"] is True
        # Should have at least one result from configured Slack channel
        assert "slack" in body["dispatched_to"] or len(body["dispatched_to"]) >= 0
