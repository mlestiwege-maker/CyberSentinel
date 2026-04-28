from __future__ import annotations

import base64
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import hmac
import hashlib
import json
from typing import Any

from app.config import settings


@dataclass(frozen=True)
class AuthPrincipal:
    username: str
    role: str


class AuthService:
    """Simple signed-token auth service for gateway pass / RBAC controls."""

    @staticmethod
    def _user_store() -> dict[str, tuple[str, str]]:
        return {
            settings.auth_admin_username: (settings.auth_admin_password, "admin"),
            settings.auth_responder_username: (settings.auth_responder_password, "responder"),
            settings.auth_analyst_username: (settings.auth_analyst_password, "analyst"),
        }

    @staticmethod
    def authenticate(username: str, password: str) -> AuthPrincipal | None:
        user = AuthService._user_store().get(username)
        if user is None:
            return None

        expected_password, role = user
        if not hmac.compare_digest(expected_password, password):
            return None

        return AuthPrincipal(username=username, role=role)

    @staticmethod
    def issue_token(principal: AuthPrincipal) -> tuple[str, datetime]:
        now = datetime.now(timezone.utc)
        expires_at = now + timedelta(minutes=max(15, settings.auth_token_ttl_minutes))

        header = {"alg": "HS256", "typ": "JWT"}
        payload = {
            "sub": principal.username,
            "role": principal.role,
            "iat": int(now.timestamp()),
            "exp": int(expires_at.timestamp()),
        }

        header_part = AuthService._b64url(json.dumps(header, separators=(",", ":")).encode("utf-8"))
        payload_part = AuthService._b64url(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
        signing_input = f"{header_part}.{payload_part}".encode("utf-8")
        signature = hmac.new(
            settings.auth_secret_key.encode("utf-8"),
            signing_input,
            hashlib.sha256,
        ).digest()
        signature_part = AuthService._b64url(signature)

        return f"{header_part}.{payload_part}.{signature_part}", expires_at

    @staticmethod
    def verify_token(token: str) -> AuthPrincipal | None:
        try:
            header_part, payload_part, signature_part = token.split(".")
        except ValueError:
            return None

        signing_input = f"{header_part}.{payload_part}".encode("utf-8")
        expected_signature = hmac.new(
            settings.auth_secret_key.encode("utf-8"),
            signing_input,
            hashlib.sha256,
        ).digest()
        expected_signature_part = AuthService._b64url(expected_signature)

        if not hmac.compare_digest(expected_signature_part, signature_part):
            return None

        payload_raw = AuthService._b64url_decode(payload_part)
        if payload_raw is None:
            return None

        try:
            payload: dict[str, Any] = json.loads(payload_raw)
        except json.JSONDecodeError:
            return None

        exp = int(payload.get("exp", 0))
        if exp <= int(datetime.now(timezone.utc).timestamp()):
            return None

        username = str(payload.get("sub", "")).strip()
        role = str(payload.get("role", "")).strip()
        if not username or role not in {"admin", "responder", "analyst"}:
            return None

        return AuthPrincipal(username=username, role=role)

    @staticmethod
    def _b64url(data: bytes) -> str:
        return base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")

    @staticmethod
    def _b64url_decode(value: str) -> str | None:
        padding = "=" * (-len(value) % 4)
        try:
            return base64.urlsafe_b64decode(value + padding).decode("utf-8")
        except Exception:
            return None
