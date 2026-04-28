"""
Attack Simulation Module
Provides realistic threat scenarios for demonstrations and testing.
Features: DDoS, Port Scan, Brute Force, Suspicious Traffic
"""

import asyncio
import random
from datetime import datetime, timezone
from typing import Dict, List
from dataclasses import dataclass, asdict

from app.models import TrafficEvent


@dataclass
class AttackScenario:
    """Represents an attack simulation scenario."""
    name: str
    attack_type: str
    duration: int  # seconds
    intensity: str  # low, medium, high
    packet_count: int
    description: str


class AttackSimulator:
    """Simulates various cyber attacks for demonstration purposes."""

    # Preset attack scenarios
    SCENARIOS = {
        "ddos": AttackScenario(
            name="DDoS Attack",
            attack_type="DDoS",
            duration=30,
            intensity="high",
            packet_count=50,
            description="Distributed Denial of Service - flood of traffic from multiple sources"
        ),
        "port_scan": AttackScenario(
            name="Port Scan",
            attack_type="Port Scan",
            duration=15,
            intensity="medium",
            packet_count=30,
            description="Reconnaissance attack scanning multiple ports for vulnerabilities"
        ),
        "brute_force": AttackScenario(
            name="Brute Force Login",
            attack_type="Brute Force",
            duration=20,
            intensity="medium",
            packet_count=25,
            description="Repeated login attempts with different credentials"
        ),
        "suspicious": AttackScenario(
            name="Suspicious Traffic",
            attack_type="Data Exfiltration",
            duration=25,
            intensity="high",
            packet_count=35,
            description="Anomalous outbound traffic suggesting data theft"
        ),
        "ransomware": AttackScenario(
            name="Ransomware Activity",
            attack_type="Ransomware",
            duration=30,
            intensity="critical",
            packet_count=40,
            description="Mass file encryption attempt via SMB/RDP exploitation"
        ),
        "malware_beaconing": AttackScenario(
            name="Malware Beaconing",
            attack_type="Malware Beaconing",
            duration=35,
            intensity="high",
            packet_count=45,
            description="C2 communication from infected internal host"
        ),
    }

    def __init__(self, threat_engine):
        self.threat_engine = threat_engine
        self.active_simulations: Dict[str, Dict] = {}
        self.simulation_id_counter = 0

    def _generate_simulation_id(self) -> str:
        """Generate unique simulation ID."""
        self.simulation_id_counter += 1
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
        return f"SIM-{timestamp}-{self.simulation_id_counter:04d}"

    def _generate_source_ip(self, scenario_name: str) -> str:
        """Generate source IP based on attack type."""
        if scenario_name == "ddos":
            # Multiple sources for DDoS
            return f"{random.randint(1, 223)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(1, 254)}"
        elif scenario_name == "port_scan":
            # Single source for recon
            return "45.33.32.156"  # Common scanner IP pattern
        elif scenario_name == "brute_force":
            return "185.220.101.34"  # Known botnet IP
        elif scenario_name == "suspicious":
            # Internal exfiltration
            return f"192.168.{random.randint(1, 10)}.{random.randint(1, 254)}"
        elif scenario_name == "ransomware":
            return f"10.{random.randint(0, 50)}.{random.randint(0, 255)}.{random.randint(1, 254)}"
        else:
            return f"{random.randint(1, 223)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(1, 254)}"

    def _generate_event(self, scenario_name: str, seq: int) -> TrafficEvent:
        """Generate traffic event based on attack scenario."""
        scenario = self.SCENARIOS[scenario_name]
        source_ip = self._generate_source_ip(scenario_name)

        # Customize event based on attack type
        if scenario_name == "ddos":
            event = TrafficEvent(
                source_ip=source_ip,
                destination_ip=f"10.0.{random.randint(0, 10)}.{random.randint(1, 254)}",
                protocol=random.choice(["HTTP", "HTTPS", "UDP"]),
                destination_port=random.choice([80, 443, 8080, 8443]),
                bytes_in=random.randint(50000, 500000),
                bytes_out=random.randint(1000, 10000),
                failed_logins=0,
                geo_anomaly=random.random() > 0.7,
                user_agent_risk=round(random.random(), 3),
            )
        elif scenario_name == "port_scan":
            event = TrafficEvent(
                source_ip=source_ip,
                destination_ip="192.168.1.100",
                protocol="TCP",
                destination_port=random.choice([21, 22, 23, 25, 53, 80, 110, 139, 443, 445, 3389, 8080]),
                bytes_in=random.randint(64, 128),
                bytes_out=random.randint(64, 128),
                failed_logins=0,
                geo_anomaly=False,
                user_agent_risk=round(random.random() * 0.3, 3),
            )
        elif scenario_name == "brute_force":
            event = TrafficEvent(
                source_ip=source_ip,
                destination_ip="192.168.1.50",
                protocol="TCP",
                destination_port=random.choice([22, 3389, 21]),
                bytes_in=random.randint(256, 1024),
                bytes_out=random.randint(256, 1024),
                failed_logins=random.randint(3, 15),
                geo_anomaly=True,
                user_agent_risk=round(random.random() * 0.5 + 0.5, 3),
            )
        elif scenario_name == "suspicious":
            event = TrafficEvent(
                source_ip=source_ip,
                destination_ip=f"{random.randint(1, 223)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(1, 254)}",
                protocol=random.choice(["TCP", "UDP", "HTTP"]),
                destination_port=random.choice([443, 8443, 9001, 8080]),
                bytes_in=random.randint(100000, 5000000),
                bytes_out=random.randint(100, 1000),
                failed_logins=random.randint(0, 5),
                geo_anomaly=True,
                user_agent_risk=round(random.random() * 0.7 + 0.3, 3),
            )
        elif scenario_name == "ransomware":
            event = TrafficEvent(
                source_ip=source_ip,
                destination_ip=f"192.168.1.{random.randint(1, 254)}",
                protocol="TCP",
                destination_port=445,
                bytes_in=random.randint(10000, 100000),
                bytes_out=random.randint(5000, 50000),
                failed_logins=0,
                geo_anomaly=False,
                user_agent_risk=round(random.random() * 0.4 + 0.6, 3),
            )
        elif scenario_name == "malware_beaconing":
            event = TrafficEvent(
                source_ip=source_ip,
                destination_ip="91.189.88.142",  # External C2 IP
                protocol="TCP",
                destination_port=random.choice([443, 80, 53]),
                bytes_in=random.randint(1000, 5000),
                bytes_out=random.randint(500, 2000),
                failed_logins=0,
                geo_anomaly=True,
                user_agent_risk=round(random.random() * 0.3 + 0.7, 3),
            )
        else:
            # Default suspicious traffic
            event = TrafficEvent(
                source_ip=source_ip,
                destination_ip=f"10.0.{random.randint(0, 10)}.{random.randint(1, 254)}",
                protocol=random.choice(["TCP", "UDP", "HTTP", "HTTPS"]),
                destination_port=random.choice([80, 443, 22, 21, 25, 53, 110, 139, 445, 3389, 8080]),
                bytes_in=random.randint(1000, 100000),
                bytes_out=random.randint(100, 10000),
                failed_logins=random.randint(0, 10),
                geo_anomaly=random.random() > 0.7,
                user_agent_risk=round(random.random(), 3),
            )

        return event

    def start_simulation(self, scenario_name: str, custom_duration: int = None) -> Dict:
        """Start an attack simulation."""
        if scenario_name not in self.SCENARIOS:
            raise ValueError(f"Unknown scenario: {scenario_name}")

        scenario = self.SCENARIOS[scenario_name]
        simulation_id = self._generate_simulation_id()

        duration = custom_duration or scenario.duration

        sim_data = {
            "simulation_id": simulation_id,
            "scenario_name": scenario_name,
            "attack_type": scenario.attack_type,
            "start_time": datetime.now(timezone.utc).isoformat(),
            "duration": duration,
            "intensity": scenario.intensity,
            "packet_count": scenario.packet_count,
            "description": scenario.description,
            "status": "running",
            "packets_sent": 0,
            "alerts_generated": 0,
        }

        self.active_simulations[simulation_id] = sim_data

        # Start simulation in background
        asyncio.create_task(self._run_simulation(simulation_id, scenario_name, duration))

        return sim_data

    async def _run_simulation(self, simulation_id: str, scenario_name: str, duration: int):
        """Run the attack simulation."""
        scenario = self.SCENARIOS[scenario_name]
        sim_data = self.active_simulations[simulation_id]

        start_time = datetime.now(timezone.utc)
        interval = duration / scenario.packet_count if scenario.packet_count > 0 else 1

        for i in range(scenario.packet_count):
            if sim_data["status"] != "running":
                break

            # Generate and send event
            event = self._generate_event(scenario_name, i)

            try:
                # Inject into threat engine
                response = await self.threat_engine.ingest(event)

                if response.alert_generated:
                    sim_data["alerts_generated"] += 1

                sim_data["packets_sent"] += 1

            except Exception as e:
                print(f"[SIMULATION] Error injecting event: {e}")

            # Progress indicator
            if (i + 1) % 5 == 0:
                elapsed = (datetime.now(timezone.utc) - start_time).total_seconds()
                print(f"[SIMULATION] {scenario_name}: {i+1}/{scenario.packet_count} packets sent ({elapsed:.1f}s)")

            # Wait before next packet
            await asyncio.sleep(max(0.1, interval))

        # Mark as complete
        sim_data["status"] = "completed"
        sim_data["end_time"] = datetime.now(timezone.utc).isoformat()
        sim_data["duration_actual"] = (datetime.now(timezone.utc) - start_time).total_seconds()

        print(f"[SIMULATION] {scenario_name} completed. Generated {sim_data['alerts_generated']} alerts.")

    def stop_simulation(self, simulation_id: str) -> Dict:
        """Stop a running simulation."""
        if simulation_id not in self.active_simulations:
            raise ValueError(f"Unknown simulation: {simulation_id}")

        sim_data = self.active_simulations[simulation_id]
        sim_data["status"] = "stopped"
        sim_data["stopped_at"] = datetime.now(timezone.utc).isoformat()

        return sim_data

    def get_simulation(self, simulation_id: str) -> Dict:
        """Get simulation details."""
        return self.active_simulations.get(simulation_id)

    def get_all_simulations(self) -> List[Dict]:
        """Get all simulations."""
        return list(self.active_simulations.values())

    def get_active_simulations(self) -> List[Dict]:
        """Get currently running simulations."""
        return [s for s in self.active_simulations.values() if s["status"] == "running"]

    def get_scenarios(self) -> Dict:
        """Get all available scenarios."""
        return {
            name: {
                "name": scenario.name,
                "attack_type": scenario.attack_type,
                "duration": scenario.duration,
                "intensity": scenario.intensity,
                "packet_count": scenario.packet_count,
                "description": scenario.description,
            }
            for name, scenario in self.SCENARIOS.items()
        }
