from __future__ import annotations

from datetime import datetime, timezone
import base64
import json

from app.services.auth_service import AuthPrincipal, AuthService


def test_authenticate_with_default_admin_credentials() -> None:
    principal = AuthService.authenticate("admin", "admin123")
    assert principal is not None
    assert principal.username == "admin"
    assert principal.role == "admin"


def test_authenticate_rejects_wrong_password() -> None:
    principal = AuthService.authenticate("admin", "wrong-password")
    assert principal is None


def test_issue_and_verify_token_roundtrip() -> None:
    principal = AuthPrincipal(username="responder", role="responder")
    token, expires_at = AuthService.issue_token(principal)

    verified = AuthService.verify_token(token)
    assert verified is not None
    assert verified.username == "responder"
    assert verified.role == "responder"
    assert expires_at > datetime.now(timezone.utc)


def test_verify_rejects_tampered_token() -> None:
    principal = AuthPrincipal(username="analyst", role="analyst")
    token, _ = AuthService.issue_token(principal)
    parts = token.split(".")
    assert len(parts) == 3

    payload_raw = base64.urlsafe_b64decode(parts[1] + "=").decode("utf-8")
    payload = json.loads(payload_raw)
    payload["role"] = "admin"
    tampered_payload = base64.urlsafe_b64encode(
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
    ).decode("utf-8").rstrip("=")

    tampered = f"{parts[0]}.{tampered_payload}.{parts[2]}"
    assert AuthService.verify_token(tampered) is None
