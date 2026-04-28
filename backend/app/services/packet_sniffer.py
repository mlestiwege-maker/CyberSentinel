"""Real network packet sniffer and feature extractor."""

from __future__ import annotations

import asyncio
import threading
from dataclasses import dataclass
from datetime import datetime
from typing import Callable

from scapy.all import conf, sniff, IP, TCP, UDP, ICMP

# Suppress Scapy warnings in server environments
conf.verb = 0


@dataclass
class PacketFeatures:
    """Extracted features from captured packets."""

    source_ip: str
    dest_ip: str
    protocol: str
    source_port: int = 0
    dest_port: int = 0
    packet_size: int = 0
    tcp_flags: str = ""
    is_suspicious: bool = False


class PacketSniffer:
    """Real network packet sniffer with background threading."""

    def __init__(self, interface: str | None = None):
        """
        Initialize packet sniffer.
        
        Args:
            interface: Network interface to sniff on (e.g., 'eth0', 'wlan0').
                      If None, auto-select first available.
        """
        self.interface = interface or self._get_default_interface()
        self.is_running = False
        self._sniffer_thread: threading.Thread | None = None
        self._callback: Callable[[PacketFeatures], None] | None = None
        self._packet_count = 0
        self._feature_buffer: list[PacketFeatures] = []

    @staticmethod
    def _get_default_interface() -> str:
        """Auto-detect default network interface."""
        try:
            iface = str(conf.iface).strip()
            if iface:
                return iface
        except Exception:
            pass

        # Fallback to common interface name
        return "eth0"

    def _flush_buffer(self) -> None:
        """Flush buffered features to callback."""
        if not self._callback or not self._feature_buffer:
            return

        for feat in self._feature_buffer:
            self._callback(feat)
        self._feature_buffer.clear()

    def _extract_features(self, packet) -> PacketFeatures | None:
        """Extract ML-ready features from a packet."""
        try:
            if not packet.haslayer(IP):
                return None

            ip_layer = packet[IP]
            source_ip = ip_layer.src
            dest_ip = ip_layer.dst
            protocol = ip_layer.proto

            protocol_name = "unknown"
            source_port = 0
            dest_port = 0
            tcp_flags = ""
            packet_size = len(packet)

            # Handle TCP
            if packet.haslayer(TCP):
                protocol_name = "tcp"
                tcp_layer = packet[TCP]
                source_port = tcp_layer.sport
                dest_port = tcp_layer.dport
                flags = tcp_layer.flags

                # Detect suspicious flags (SYN scan, port scan, etc.)
                tcp_flags = str(flags)
                if flags & 0x02 and not (flags & 0x10):  # SYN without ACK
                    tcp_flags = "SYN"
                elif flags & 0x01:  # FIN
                    tcp_flags = "FIN"
                elif flags & 0x04:  # RST
                    tcp_flags = "RST"

            # Handle UDP
            elif packet.haslayer(UDP):
                protocol_name = "udp"
                udp_layer = packet[UDP]
                source_port = udp_layer.sport
                dest_port = udp_layer.dport

            # Handle ICMP
            elif packet.haslayer(ICMP):
                protocol_name = "icmp"
                icmp = packet[ICMP]
                tcp_flags = f"type={icmp.type}"

            # Heuristic: detect suspicious patterns
            is_suspicious = (
                (protocol_name == "tcp" and tcp_flags == "SYN")  # Port scan
                or source_port < 1024  # Privileged source port
                or dest_port in {22, 23, 3389, 445}  # Common attack targets
                or packet_size > 65535  # Fragmentation
            )

            return PacketFeatures(
                source_ip=source_ip,
                dest_ip=dest_ip,
                protocol=protocol_name,
                source_port=source_port,
                dest_port=dest_port,
                packet_size=packet_size,
                tcp_flags=tcp_flags,
                is_suspicious=is_suspicious,
            )
        except Exception:
            return None

    def _packet_callback(self, packet) -> None:
        """Callback for each captured packet."""
        self._packet_count += 1

        features = self._extract_features(packet)
        if features and self._callback:
            self._feature_buffer.append(features)
            if len(self._feature_buffer) >= 10:  # Batch every 10 packets
                self._flush_buffer()

    def _sniff_thread(self) -> None:
        """Background thread for packet sniffing."""
        try:
            sniff(
                iface=self.interface,
                prn=self._packet_callback,
                store=False,
                stop_filter=lambda x: not self.is_running,
            )
        except PermissionError:
            print(f"Error: Need root/admin privileges to sniff on {self.interface}")
        except Exception as e:
            print(f"Packet sniffer error: {e}")

    def start(self, callback: Callable[[PacketFeatures], None]) -> None:
        """Start packet sniffing in background thread."""
        if self.is_running:
            return

        self.is_running = True
        self._callback = callback
        self._packet_count = 0

        self._sniffer_thread = threading.Thread(
            target=self._sniff_thread,
            daemon=True,
        )
        self._sniffer_thread.start()

    def stop(self) -> None:
        """Stop packet sniffing."""
        self.is_running = False
        if self._sniffer_thread:
            self._sniffer_thread.join(timeout=5)
        self._flush_buffer()

    def get_stats(self) -> dict:
        """Get sniffer statistics."""
        return {
            "is_running": self.is_running,
            "interface": self.interface,
            "packets_captured": self._packet_count,
            "buffered_features": len(self._feature_buffer),
        }


# Global sniffer instance
_global_sniffer: PacketSniffer | None = None


def get_sniffer(interface: str | None = None) -> PacketSniffer:
    """Get or create global packet sniffer instance."""
    global _global_sniffer
    if _global_sniffer is None:
        _global_sniffer = PacketSniffer(interface)
    elif (
        interface is not None
        and interface != _global_sniffer.interface
        and not _global_sniffer.is_running
    ):
        _global_sniffer = PacketSniffer(interface)
    return _global_sniffer
