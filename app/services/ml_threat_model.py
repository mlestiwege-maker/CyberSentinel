"""Machine Learning threat detection using Isolation Forest."""

from __future__ import annotations

import asyncio
from datetime import datetime
from pathlib import Path

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

    def __init__(self):
        """Initialize ML model."""
        self.model: IsolationForest | None = None
        self.scaler: StandardScaler | None = None
        self.training_history: list[tuple[datetime, int, float]] = []
        self._is_fitted = False  # Track if model has been fitted
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
                self._is_fitted = True  # Model was loaded from disk, so it's fitted
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
        self._is_fitted = False  # New model not yet fitted

    def _event_to_features(self, event: TrafficEvent) -> list[float]:
        """Convert TrafficEvent to feature vector."""
        geo_anomaly_val = 1.0 if event.geo_anomaly else 0.0
        return [
            float(event.bytes_in),
            float(event.bytes_out),
            float(event.failed_logins),
            float(event.destination_port),
            event.user_agent_risk,
        ]

    def predict(self, event: TrafficEvent) -> tuple[bool, float]:
        """
        Predict if event is anomalous.

        Args:
            event: Traffic event to analyze

        Returns:
            (is_anomaly, anomaly_score) where anomaly_score is 0-1 confidence
        """
        if self.model is None or self.scaler is None:
            return False, 0.0

        try:
            features = self._event_to_features(event)
            X = np.array([features])

            # Normalize features
            try:
                X_scaled = self.scaler.transform(X)
            except Exception:
                # If scaler not fitted, return default
                return False, 0.0

            # Isolation Forest returns -1 for anomalies, 1 for normal
            prediction = self.model.predict(X_scaled)[0]
            is_anomaly = prediction == -1

            # Get anomaly score (lower = more anomalous)
            # Isolation Forest scores: lower values are more anomalous
            score = self.model.score_samples(X_scaled)[0]

            # Convert to 0-1 where 1 = high anomaly confidence
            # score ranges from -1 (most anomalous) to 0 (normal)
            anomaly_confidence = max(0.0, min(1.0, (-score) / 2.0))

            return is_anomaly, anomaly_confidence
        except Exception as e:
            return False, 0.0

    def train(self, events: list[TrafficEvent]) -> dict[str, float]:
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
            self._is_fitted = True  # Mark model as fitted

            # Save model
            self._save_model()

            # Calculate training stats
            predictions = self.model.predict(X_scaled)
            anomaly_count = np.sum(predictions == -1)

            stats = {
                "events_trained": len(events),
                "anomalies_detected": int(anomaly_count),
                "anomaly_rate": float(anomaly_count / len(events)),
                "model_saved": True,
            }

            # Record training
            self.training_history.append(
                (datetime.now(), len(events), float(stats["anomaly_rate"]))
            )

            return stats
        except Exception as e:
            return {"error": str(e)}

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
        }


# Global model instance
_global_model: MLThreatDetectionModel | None = None


def get_threat_model() -> MLThreatDetectionModel:
    """Get or create global ML threat detection model."""
    global _global_model
    if _global_model is None:
        _global_model = MLThreatDetectionModel()
    return _global_model
