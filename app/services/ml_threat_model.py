"""Machine Learning threat detection using Isolation Forest."""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any

import joblib
import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler

from app.models import TrafficEvent


class MLThreatDetectionModel:
    """Isolation Forest-based network anomaly detection model."""

    MODEL_PATH = Path(__file__).parent.parent / "models" / "threat_model.pkl"
    SCALER_PATH = Path(__file__).parent.parent / "models" / "threat_scaler.pkl"

    # Feature extraction from traffic events
    FEATURES = [
        "bytes_in",
        "bytes_out",
        "failed_logins",
        "destination_port",
        "user_agent_risk",
    ]

    DEFAULT_ALERT_THRESHOLD = 0.78

    def __init__(self):
        """Initialize ML model."""
        self.model: IsolationForest | None = None
        self.scaler: StandardScaler | None = None
        self.training_history: list[tuple[datetime, int, float]] = []
        self._is_fitted = False
        self._alert_threshold = self.DEFAULT_ALERT_THRESHOLD
        self._versions: dict[str, dict[str, Any]] = {}
        self._active_version_id: str | None = None
        self._next_slot = "A"
        self._ensure_model_dir()
        self._load_or_initialize_model()

    @staticmethod
    def _ensure_model_dir() -> None:
        """Ensure models directory exists."""
        MLThreatDetectionModel.MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)

    def _load_or_initialize_model(self) -> None:
        """Load existing model or create new one."""
        if self.MODEL_PATH.exists() and self.SCALER_PATH.exists():
            try:
                self.model = joblib.load(self.MODEL_PATH)
                self.scaler = joblib.load(self.SCALER_PATH)
                self._is_fitted = True
                version_id = f"bootstrap-{datetime.now().strftime('%Y%m%d%H%M%S')}"
                self._versions[version_id] = {
                    "version_id": version_id,
                    "slot": "A",
                    "trained_at": datetime.now(),
                    "training_samples": 0,
                    "anomaly_rate": 0.0,
                    "threshold": self._alert_threshold,
                    "feature_importance": {
                        feature: round(1.0 / len(self.FEATURES), 4)
                        for feature in self.FEATURES
                    },
                    "model": self.model,
                    "scaler": self.scaler,
                }
                self._active_version_id = version_id
                self._next_slot = "B"
                return
            except Exception:
                pass

        # Initialize new model
        self.model = IsolationForest(
            contamination=0.1,  # Expect ~10% of traffic to be anomalous
            random_state=42,
            n_estimators=100,
        )
        self.scaler = StandardScaler()
        self._is_fitted = False

    def _event_to_features(self, event: TrafficEvent) -> list[float]:
        """Convert TrafficEvent to feature vector."""
        return [
            float(event.bytes_in),
            float(event.bytes_out),
            float(event.failed_logins),
            float(event.destination_port),
            event.user_agent_risk,
        ]

    def _select_version(self, version_id: str | None = None) -> tuple[IsolationForest | None, StandardScaler | None]:
        """Return model and scaler for selected version (or active)."""
        selected_id = version_id or self._active_version_id
        if selected_id and selected_id in self._versions:
            version = self._versions[selected_id]
            return version["model"], version["scaler"]
        return self.model, self.scaler

    def predict(self, event: TrafficEvent, version_id: str | None = None) -> tuple[bool, float]:
        """
        Predict if event is anomalous.

        Args:
            event: Traffic event to analyze

        Returns:
            (is_anomaly, anomaly_score) where anomaly_score is 0-1 confidence
        """
        model, scaler = self._select_version(version_id=version_id)
        if model is None or scaler is None:
            return False, 0.0

        try:
            features = self._event_to_features(event)
            X = np.array([features])

            # Normalize features
            try:
                X_scaled = scaler.transform(X)
            except Exception:
                # If scaler not fitted, return default
                return False, 0.0

            # Isolation Forest returns -1 for anomalies, 1 for normal
            prediction = model.predict(X_scaled)[0]
            is_anomaly = prediction == -1

            # Get anomaly score (lower = more anomalous)
            # Isolation Forest scores: lower values are more anomalous
            score = model.score_samples(X_scaled)[0]

            # Convert to 0-1 where 1 = high anomaly confidence
            # score ranges from -1 (most anomalous) to 0 (normal)
            anomaly_confidence = max(0.0, min(1.0, (-score) / 2.0))

            return is_anomaly, anomaly_confidence
        except Exception:
            return False, 0.0

    def train(self, events: list[TrafficEvent]) -> dict[str, float | str]:
        """
        Train model on historical traffic data.

        Args:
            events: List of traffic events to train on

        Returns:
            Training statistics
        """
        if len(events) < 10:
            return {"error": "Insufficient training data (minimum 10 events)"}

        try:
            X = np.array([self._event_to_features(e) for e in events])

            # Fit scaler
            self.scaler = StandardScaler()
            X_scaled = self.scaler.fit_transform(X)

            # Train model
            self.model = IsolationForest(
                contamination=0.1,
                random_state=42,
                n_estimators=100,
            )
            self.model.fit(X_scaled)
            self._is_fitted = True

            # Calculate training stats
            predictions = self.model.predict(X_scaled)
            anomaly_count = np.sum(predictions == -1)
            anomaly_rate = float(anomaly_count / len(events))

            # Compute feature importance (SHAP if available, fallback otherwise)
            feature_importance = self._estimate_feature_importance(X_scaled)

            # Model versioning + A/B slot assignment
            version_id = f"v{len(self._versions) + 1}-{datetime.now().strftime('%Y%m%d%H%M%S')}"
            slot = self._next_slot
            self._next_slot = "B" if self._next_slot == "A" else "A"

            self._versions[version_id] = {
                "version_id": version_id,
                "slot": slot,
                "trained_at": datetime.now(),
                "training_samples": len(events),
                "anomaly_rate": anomaly_rate,
                "threshold": self._alert_threshold,
                "feature_importance": feature_importance,
                "model": self.model,
                "scaler": self.scaler,
            }
            self._active_version_id = version_id

            # Save model
            self._save_model()

            stats = {
                "events_trained": len(events),
                "anomalies_detected": int(anomaly_count),
                "anomaly_rate": anomaly_rate,
                "model_saved": True,
                "version_id": version_id,
                "slot": slot,
            }

            # Record training
            self.training_history.append(
                (datetime.now(), len(events), float(stats["anomaly_rate"]))
            )

            return stats
        except Exception as e:
            return {"error": str(e)}

    def _estimate_feature_importance(self, X_scaled: np.ndarray) -> dict[str, float]:
        """Estimate feature importance with SHAP (if available) or a robust fallback."""
        try:
            import shap  # type: ignore

            if self.model is None:
                raise RuntimeError("Model unavailable for SHAP computation")

            sample = X_scaled[: min(50, len(X_scaled))]
            explainer = shap.TreeExplainer(self.model)
            shap_values = explainer.shap_values(sample)
            values = np.array(shap_values)
            if values.ndim == 3:
                values = values[0]
            mean_abs = np.mean(np.abs(values), axis=0)
            denom = float(np.sum(mean_abs)) or 1.0
            return {
                feature: round(float(mean_abs[idx] / denom), 4)
                for idx, feature in enumerate(self.FEATURES)
            }
        except Exception:
            # Fallback: SHAP-style proxy from normalized feature dispersion
            mean_abs = np.mean(np.abs(X_scaled), axis=0)
            denom = float(np.sum(mean_abs)) or 1.0
            return {
                feature: round(float(mean_abs[idx] / denom), 4)
                for idx, feature in enumerate(self.FEATURES)
            }

    def get_feature_importance(self) -> dict[str, Any]:
        """Return feature importance for active model version."""
        if not self._active_version_id or self._active_version_id not in self._versions:
            return {
                "method": "none",
                "sample_size": 0,
                "importances": {feature: 0.0 for feature in self.FEATURES},
            }

        version = self._versions[self._active_version_id]
        return {
            "method": "SHAP (or SHAP-style fallback)",
            "sample_size": int(version.get("training_samples", 0)),
            "importances": version.get("feature_importance", {}),
        }

    def tune_threshold(self, target_false_positive_rate: float, alerts: list[Any]) -> dict[str, float | str]:
        """Tune alert threshold using observed false-positive rate from historical alerts."""
        old_threshold = self._alert_threshold

        positives = [a for a in alerts if float(getattr(a, "confidence", 0.0)) >= old_threshold]
        if not positives:
            return {
                "old_threshold": old_threshold,
                "new_threshold": old_threshold,
                "observed_false_positive_rate": 0.0,
                "target_false_positive_rate": target_false_positive_rate,
                "message": "No positive alerts found for tuning."
            }

        false_positives = [
            a
            for a in positives
            if getattr(a, "status", "") == "Resolved"
        ]
        observed_fpr = len(false_positives) / len(positives)

        delta = observed_fpr - target_false_positive_rate
        if delta > 0:
            self._alert_threshold = min(0.95, old_threshold + min(0.05, delta * 0.25))
            message = "Observed false positives are high; threshold increased."
        else:
            self._alert_threshold = max(0.50, old_threshold - min(0.03, abs(delta) * 0.15))
            message = "Observed false positives are acceptable; threshold relaxed slightly."

        return {
            "old_threshold": round(old_threshold, 4),
            "new_threshold": round(self._alert_threshold, 4),
            "observed_false_positive_rate": round(observed_fpr, 4),
            "target_false_positive_rate": round(target_false_positive_rate, 4),
            "message": message,
        }

    def get_alert_threshold(self) -> float:
        """Get active alert generation threshold."""
        return float(self._alert_threshold)

    def get_model_versions(self) -> dict[str, Any]:
        """Get model versions metadata for A/B testing."""
        versions: list[dict[str, Any]] = []
        for version_id, data in self._versions.items():
            versions.append(
                {
                    "version_id": version_id,
                    "slot": str(data.get("slot", "A")),
                    "trained_at": data.get("trained_at", datetime.now()).isoformat(),
                    "training_samples": int(data.get("training_samples", 0)),
                    "anomaly_rate": float(data.get("anomaly_rate", 0.0)),
                    "threshold": float(data.get("threshold", self._alert_threshold)),
                    "is_active": version_id == self._active_version_id,
                }
            )

        versions.sort(key=lambda item: item["trained_at"], reverse=True)
        return {
            "active_version": self._active_version_id,
            "versions": versions,
        }

    def switch_active_version(self, version_id: str) -> bool:
        """Switch active model version for inference."""
        if version_id not in self._versions:
            return False

        selected = self._versions[version_id]
        self.model = selected["model"]
        self.scaler = selected["scaler"]
        self._active_version_id = version_id
        self._is_fitted = True
        return True

    def predict_ab(self, event: TrafficEvent) -> dict[str, Any]:
        """Run A/B prediction against latest A and B slot versions."""
        slot_a = next(
            (v for v in sorted(self._versions.values(), key=lambda d: d["trained_at"], reverse=True) if v["slot"] == "A"),
            None,
        )
        slot_b = next(
            (v for v in sorted(self._versions.values(), key=lambda d: d["trained_at"], reverse=True) if v["slot"] == "B"),
            None,
        )

        result: dict[str, Any] = {"has_ab_pair": slot_a is not None and slot_b is not None}
        if slot_a is not None:
            a_anomaly, a_conf = self.predict(event, version_id=slot_a["version_id"])
            result["A"] = {
                "version_id": slot_a["version_id"],
                "is_anomaly": a_anomaly,
                "confidence": round(a_conf, 4),
            }
        if slot_b is not None:
            b_anomaly, b_conf = self.predict(event, version_id=slot_b["version_id"])
            result["B"] = {
                "version_id": slot_b["version_id"],
                "is_anomaly": b_anomaly,
                "confidence": round(b_conf, 4),
            }

        return result

    def _save_model(self) -> None:
        """Save trained model and scaler to disk."""
        if self.model and self.scaler:
            self._ensure_model_dir()
            joblib.dump(self.model, self.MODEL_PATH)
            joblib.dump(self.scaler, self.SCALER_PATH)

    def get_model_info(self) -> dict:
        """Get information about current model."""
        return {
            "model_name": "Isolation Forest",
            "version": "1.0",
            "features": self.FEATURES,
            "contamination": 0.1,
            "training_samples": len(self.training_history),
            "last_training": (
                self.training_history[-1][0].isoformat()
                if self.training_history
                else None
            ),
            "anomaly_detection_method": "Isolation Forest (scikit-learn)",
            "status": "trained" if self._is_fitted else "untrained",
            "active_version": self._active_version_id,
            "versions": len(self._versions),
            "alert_threshold": round(self._alert_threshold, 4),
        }


# Global model instance
_global_model: MLThreatDetectionModel | None = None


def get_threat_model() -> MLThreatDetectionModel:
    """Get or create global ML threat detection model."""
    global _global_model
    if _global_model is None:
        _global_model = MLThreatDetectionModel()
    return _global_model
