from __future__ import annotations

from app.services.feature_extractor import FeatureExtractor
from app.services.packet_sniffer import PacketFeatures, PacketSniffer, get_sniffer
import app.services.packet_sniffer as packet_sniffer_module


def test_convert_to_traffic_event_maps_to_valid_schema() -> None:
    extractor = FeatureExtractor()

    features = PacketFeatures(
        source_ip="10.1.2.3",
        dest_ip="8.8.8.8",
        protocol="tcp",
        source_port=53422,
        dest_port=0,  # invalid raw port should be normalized
        packet_size=1600,
        tcp_flags="SYN",
        is_suspicious=True,
    )

    event = extractor.convert_to_traffic_event(features)

    assert event.source_ip == "10.1.2.3"
    assert event.destination_ip == "8.8.8.8"
    assert event.protocol == "TCP"
    assert event.destination_port == 53422
    assert event.bytes_in == 1600
    assert event.bytes_out >= 0
    assert 0.0 <= event.user_agent_risk <= 1.0


def test_convert_to_traffic_event_normalizes_unknown_protocol_to_tcp() -> None:
    extractor = FeatureExtractor()

    features = PacketFeatures(
        source_ip="10.2.3.4",
        dest_ip="1.1.1.1",
        protocol="gopher",
        source_port=0,
        dest_port=70000,
        packet_size=80,
    )

    event = extractor.convert_to_traffic_event(features)
    assert event.protocol == "TCP"
    assert event.destination_port == 443


def test_public_ip_detection_rejects_invalid_and_private_ranges() -> None:
    assert FeatureExtractor._is_public_ip("8.8.8.8") is True
    assert FeatureExtractor._is_public_ip("192.168.1.10") is False
    assert FeatureExtractor._is_public_ip("127.0.0.1") is False
    assert FeatureExtractor._is_public_ip("not-an-ip") is False


def test_default_interface_uses_scapy_iface() -> None:
    detected = PacketSniffer._get_default_interface()
    assert isinstance(detected, str)
    assert detected.strip() != ""


def test_stop_flushes_buffered_features() -> None:
    captured: list[PacketFeatures] = []
    sniffer = PacketSniffer(interface="lo")

    sniffer._callback = captured.append
    sniffer._feature_buffer = [
        PacketFeatures(
            source_ip="10.0.0.2",
            dest_ip="10.0.0.8",
            protocol="tcp",
            source_port=50001,
            dest_port=443,
            packet_size=128,
        ),
        PacketFeatures(
            source_ip="10.0.0.3",
            dest_ip="10.0.0.9",
            protocol="udp",
            source_port=50002,
            dest_port=53,
            packet_size=96,
        ),
    ]

    sniffer.stop()

    assert len(captured) == 2
    assert len(sniffer._feature_buffer) == 0


def test_get_sniffer_can_switch_interface_when_stopped() -> None:
    packet_sniffer_module._global_sniffer = None

    first = get_sniffer("eth0")
    assert first.interface == "eth0"

    switched = get_sniffer("wlan0")
    assert switched.interface == "wlan0"
    assert switched is not first
