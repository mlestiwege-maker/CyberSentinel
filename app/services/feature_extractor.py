"""Feature extraction and threat event generation from network packets."""

from __future__ import annotations

from datetime import datetime, timezone
import ipaddress

from app.models import TrafficEvent
from app.services.packet_sniffer import PacketFeatures


class FeatureExtractor:
    """Convert low-level packet features to high-level threat events."""

    # Suspicious port thresholds
    PRIVILEGED_PORTS = {1, 22, 23, 25, 53, 80, 110, 143, 443, 445, 3306, 3389, 5432, 5900}
    RANSOMWARE_PORTS = {135, 139, 445, 4444, 6667}
    BOTNET_PORTS = {6667, 6668, 6669, 8080, 8443}

    # Protocol anomaly scoring
    PROTOCOL_BASELINE = {
        "tcp": 0.1,
        "udp": 0.05,
        "icmp": 0.03,
        "unknown": 0.2,
    }

    def __init__(self):
        self._flow_stats: dict = {}
        self._source_patterns: dict = {}

    @staticmethod
    def _normalize_protocol(protocol: str) -> str:
        normalized = protocol.strip().lower()
        if normalized == "tcp":
            return "TCP"
        if normalized == "udp":
            return "UDP"
        if normalized == "icmp":
            return "ICMP"
        return "TCP"

    @staticmethod
    def calculate_anomaly_score(features: PacketFeatures) -> float:
        """Calculate anomaly score (0.0-1.0) for packet features."""
        score = 0.0
        protocol = features.protocol.strip().lower()

        # Suspicious TCP flags (SYN scans, port scans)
        if features.tcp_flags in {"SYN", "FIN", "RST"}:
            score += 0.15

        # Suspicious port combinations
        if features.dest_port in FeatureExtractor.RANSOMWARE_PORTS:
            score += 0.25
        elif features.dest_port in FeatureExtractor.BOTNET_PORTS:
            score += 0.20
        elif features.source_port < 1024 and protocol == "tcp":
            score += 0.10

        # Large packet size (potential DDoS or data exfiltration)
        if features.packet_size > 1500:
            score += 0.05
        elif features.packet_size < 40:
            score += 0.08  # Unusual small packet

        # ICMP anomalies
        if protocol == "icmp":
            if "type=8" in features.tcp_flags:  # Echo request flood
                score += 0.15

        # Private to public communication (potential data exfil)
        if FeatureExtractor._is_private_ip(features.source_ip) and FeatureExtractor._is_public_ip(
            features.dest_ip
        ):
            if features.packet_size > 10000:
                score += 0.20

        return min(score, 1.0)

    @staticmethod
    def _is_private_ip(ip: str) -> bool:
        """Check if IP is private range."""
        try:
            return ipaddress.ip_address(ip).is_private
        except ValueError:
            return False

    @staticmethod
    def _is_public_ip(ip: str) -> bool:
        """Check if IP is public (not private/loopback)."""
        try:
            return ipaddress.ip_address(ip).is_global
        except ValueError:
            return False

    @staticmethod
    def classify_attack_type(features: PacketFeatures, score: float) -> str:
        """Classify suspected attack type based on features."""
        protocol = features.protocol.strip().lower()
        if features.tcp_flags == "SYN" and score > 0.15:
            return "Port Scan"
        elif features.dest_port in FeatureExtractor.RANSOMWARE_PORTS:
            return "Ransomware Activity"
        elif features.dest_port in FeatureExtractor.BOTNET_PORTS:
            return "Botnet Communication"
        elif protocol == "icmp" and score > 0.15:
            return "ICMP Flood"
        elif features.packet_size > 10000:
            return "Data Exfiltration"
        elif protocol == "udp" and features.packet_size < 100 and score > 0.1:
            return "DNS Spoofing"
        else:
            return "Anomalous Traffic"

    def convert_to_traffic_event(self, features: PacketFeatures) -> TrafficEvent:
        """Convert packet features to a valid TrafficEvent for threat engine ingestion."""
        score = self.calculate_anomaly_score(features)
        protocol = self._normalize_protocol(features.protocol)

        # Estimate failed logins / connection attempts (heuristic)
        failed_logins = 1 if features.tcp_flags == "RST" else 0

        # Estimate data in/out based on packet size
        bytes_in = features.packet_size if protocol == "TCP" else 0
        bytes_out = features.packet_size if score > 0.2 else 0

        destination_port = features.dest_port
        if destination_port <= 0 or destination_port > 65535:
            if 1 <= features.source_port <= 65535:
                destination_port = features.source_port
            else:
                destination_port = 443

        geo_anomaly = (
            FeatureExtractor._is_private_ip(features.source_ip)
            and FeatureExtractor._is_public_ip(features.dest_ip)
            and score >= 0.2
        )
        user_agent_risk = min(1.0, max(0.0, round(score + (0.1 if features.is_suspicious else 0.0), 3)))

        return TrafficEvent(
            timestamp=datetime.now(timezone.utc),
            source_ip=features.source_ip,
            destination_ip=features.dest_ip,
            protocol=protocol,
            destination_port=destination_port,
            bytes_in=bytes_in,
            bytes_out=bytes_out,
            failed_logins=failed_logins,
            geo_anomaly=geo_anomaly,
            user_agent_risk=user_agent_risk,
        )
