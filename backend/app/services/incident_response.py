"""
Incident Response Workflow Service
Manages full incident lifecycle: Open → Investigating → Resolved → Closed
"""

from __future__ import annotations

import asyncio
import json
from datetime import datetime, timezone
from enum import Enum
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict, field
from collections import defaultdict

from app.models import ThreatAlert


class IncidentStatus(str, Enum):
    """Incident workflow statuses."""
    OPEN = "Open"
    INVESTIGATING = "Investigating"
    RESOLVED = "Resolved"
    CLOSED = "Closed"


class SeverityLevel(str, Enum):
    """Incident severity levels."""
    CRITICAL = "Critical"
    HIGH = "High"
    MEDIUM = "Medium"
    LOW = "Low"


@dataclass
class Incident:
    """Represents a security incident."""
    incident_id: str
    title: str
    description: str
    severity: str
    status: str
    created_at: str
    updated_at: str
    assigned_to: Optional[str]
    source_alert_id: Optional[str]
    source_attack_type: Optional[str]
    source_ip: Optional[str]
    affected_systems: List[str]
    tags: List[str]
    notes: List[Dict[str, str]]
    response_actions: List[Dict[str, str]]
    detection_timestamp: str
    resolution_timestamp: Optional[str]
    closed_timestamp: Optional[str]
    time_to_detect: Optional[int]  # seconds
    time_to_resolve: Optional[int]  # seconds
    root_cause: Optional[str]
    related_alerts: List[str]
    
    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return asdict(self)


class IncidentResponseWorkflow:
    """Manages complete incident response lifecycle."""
    
    def __init__(self):
        self._incidents: Dict[str, Incident] = {}
        self._incident_counter = 0
        self._status_history: Dict[str, List[Dict]] = defaultdict(list)
        self._analysts: Dict[str, Dict] = self._default_analysts()
        self._sla_targets: Dict[str, int] = {
            IncidentStatus.OPEN.value: 0,
            IncidentStatus.INVESTIGATING.value: 300,    # 5 minutes
            IncidentStatus.RESOLVED.value: 3600,          # 1 hour
            IncidentStatus.CLOSED.value: 7200,            # 2 hours
        }
    
    def _default_analysts(self) -> Dict[str, Dict]:
        """Default analyst assignments."""
        return {
            "analyst_1": {
                "name": "Lead Analyst",
                "email": "lead.analyst@cybersentinel.local",
                "role": "Lead",
                "incidents_assigned": 0,
            },
            "analyst_2": {
                "name": "Senior Analyst",
                "email": "senior.analyst@cybersentinel.local",
                "role": "Senior",
                "incidents_assigned": 0,
            },
            "analyst_3": {
                "name": "Junior Analyst",
                "email": "junior.analyst@cybersentinel.local",
                "role": "Junior",
                "incidents_assigned": 0,
            },
        }
    
    def create_incident_from_alert(self, alert: ThreatAlert) -> Incident:
        """Create incident from detected threat alert."""
        self._incident_counter += 1
        timestamp = datetime.now(timezone.utc)
        incident_id = f"INC-{timestamp.strftime('%Y%m%d')}-{self._incident_counter:04d}"
        
        severity = alert.severity
        title = f"{severity} Threat: {alert.attack_type}"
        
        incident = Incident(
            incident_id=incident_id,
            title=title,
            description=f"Potential {alert.attack_type} detected from {alert.source_ip}. "
                        f"Confidence: {alert.confidence * 100:.1f}%",
            severity=severity,
            status=IncidentStatus.OPEN.value,
            created_at=timestamp.isoformat(),
            updated_at=timestamp.isoformat(),
            assigned_to=None,
            source_alert_id=alert.id,
            source_attack_type=alert.attack_type,
            source_ip=alert.source_ip,
            affected_systems=[alert.source_ip],
            tags=[alert.attack_type, severity, "auto-generated"],
            notes=[],
            response_actions=[],
            detection_timestamp=alert.time.isoformat(),
            resolution_timestamp=None,
            closed_timestamp=None,
            time_to_detect=None,
            time_to_resolve=None,
            root_cause=None,
            related_alerts=[alert.id],
        )
        
        self._incidents[incident_id] = incident
        self._add_status_history(
            incident_id,
            IncidentStatus.OPEN.value,
            "Incident auto-created from alert detection"
        )
        
        return incident
    
    def create_manual_incident(
        self,
        title: str,
        description: str,
        severity: str,
        source_ip: Optional[str] = None,
        affected_systems: Optional[List[str]] = None,
        tags: Optional[List[str]] = None,
    ) -> Incident:
        """Create incident manually (not from alert)."""
        self._incident_counter += 1
        timestamp = datetime.now(timezone.utc)
        incident_id = f"INC-{timestamp.strftime('%Y%m%d')}-{self._incident_counter:04d}"
        
        if severity not in [s.value for s in SeverityLevel]:
            raise ValueError(f"Invalid severity: {severity}")
        
        incident = Incident(
            incident_id=incident_id,
            title=title,
            description=description,
            severity=severity,
            status=IncidentStatus.OPEN.value,
            created_at=timestamp.isoformat(),
            updated_at=timestamp.isoformat(),
            assigned_to=None,
            source_alert_id=None,
            source_attack_type=None,
            source_ip=source_ip,
            affected_systems=affected_systems or [],
            tags=tags or [severity.lower(), "manual"],
            notes=[],
            response_actions=[],
            detection_timestamp=timestamp.isoformat(),
            resolution_timestamp=None,
            closed_timestamp=None,
            time_to_detect=None,
            time_to_resolve=None,
            root_cause=None,
            related_alerts=[],
        )
        
        self._incidents[incident_id] = incident
        self._add_status_history(
            incident_id,
            IncidentStatus.OPEN.value,
            "Incident manually created"
        )
        
        return incident
    
    def assign_analyst(
        self,
        incident_id: str,
        analyst_id: str
    ) -> Incident:
        """Assign incident to an analyst."""
        incident = self._get_incident(incident_id)
        
        if analyst_id not in self._analysts:
            raise ValueError(f"Unknown analyst: {analyst_id}")
        
        previous_analyst = incident.assigned_to
        analyst = self._analysts[analyst_id]
        
        # Update previous analyst's count
        if previous_analyst and previous_analyst in self._analysts:
            self._analysts[previous_analyst]["incidents_assigned"] -= 1
        
        incident.assigned_to = analyst_id
        incident.updated_at = datetime.now(timezone.utc).isoformat()
        analyst["incidents_assigned"] += 1
        
        # Auto-transition to Investigating if in Open state
        if incident.status == IncidentStatus.OPEN.value:
            self.update_status(
                incident_id,
                IncidentStatus.INVESTIGATING.value,
                f"Assigned to {analyst['name']}"
            )
        else:
            self._add_status_history(
                incident_id,
                incident.status,
                f"Reassigned to {analyst['name']}"
            )
        
        return incident
    
    def update_status(
        self,
        incident_id: str,
        new_status: str,
        notes: Optional[str] = None
    ) -> Incident:
        """Update incident status through workflow lifecycle."""
        incident = self._get_incident(incident_id)
        
        valid_statuses = [s.value for s in IncidentStatus]
        if new_status not in valid_statuses:
            raise ValueError(f"Invalid status: {new_status}. Must be one of {valid_statuses}")
        
        old_status = incident.status
        
        # Validate state transitions
        self._validate_transition(old_status, new_status)
        
        incident.status = new_status
        incident.updated_at = datetime.now(timezone.utc).isoformat()
        
        now = datetime.now(timezone.utc)
        
        # Track timestamps based on status
        if new_status == IncidentStatus.INVESTIGATING.value:
            if not incident.detection_timestamp:
                incident.detection_timestamp = now.isoformat()
        elif new_status == IncidentStatus.RESOLVED.value:
            incident.resolution_timestamp = now.isoformat()
            # Calculate time to resolve
            if incident.detection_timestamp:
                detect_time = datetime.fromisoformat(incident.detection_timestamp)
                incident.time_to_resolve = int((now - detect_time).total_seconds())
        elif new_status == IncidentStatus.CLOSED.value:
            incident.closed_timestamp = now.isoformat()
            # Calculate total time
            if incident.detection_timestamp:
                detect_time = datetime.fromisoformat(incident.detection_timestamp)
                incident.time_to_detect = int((now - detect_time).total_seconds())
        
        history_note = f"Status changed: {old_status} → {new_status}"
        if notes:
            history_note += f" | {notes}"
        
        self._add_status_history(incident_id, new_status, history_note)
        
        # Add note if provided
        if notes:
            self.add_note(incident_id, notes)
        
        return incident
    
    def _validate_transition(self, old_status: str, new_status: str) -> None:
        """Validate allowed status transitions."""
        allowed_transitions = {
            IncidentStatus.OPEN.value: [IncidentStatus.INVESTIGATING.value],
            IncidentStatus.INVESTIGATING.value: [
                IncidentStatus.RESOLVED.value,
                IncidentStatus.OPEN.value,
            ],
            IncidentStatus.RESOLVED.value: [
                IncidentStatus.CLOSED.value,
                IncidentStatus.INVESTIGATING.value,
            ],
            IncidentStatus.CLOSED.value: [
                IncidentStatus.INVESTIGATING.value,
            ],
        }
        
        if new_status not in allowed_transitions.get(old_status, []):
            raise ValueError(
                f"Invalid transition: {old_status} → {new_status}. "
                f"Allowed: {allowed_transitions.get(old_status, [])}"
            )
    
    def add_note(self, incident_id: str, note: str, author: str = "System") -> Incident:
        """Add note to incident."""
        incident = self._get_incident(incident_id)
        
        incident.notes.append({
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "author": author,
            "note": note,
        })
        
        return incident
    
    def add_response_action(
        self,
        incident_id: str,
        action: str,
        actor: str,
        status: str = "completed",
    ) -> Incident:
        """Add response action taken for incident."""
        incident = self._get_incident(incident_id)
        
        incident.response_actions.append({
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "action": action,
            "actor": actor,
            "status": status,
        })
        
        return incident
    
    def add_related_alert(self, incident_id: str, alert_id: str) -> Incident:
        """Link additional alert to incident."""
        incident = self._get_incident(incident_id)
        
        if alert_id not in incident.related_alerts:
            incident.related_alerts.append(alert_id)
        
        return incident
    
    def add_affected_system(self, incident_id: str, system: str) -> Incident:
        """Add affected system to incident."""
        incident = self._get_incident(incident_id)
        
        if system not in incident.affected_systems:
            incident.affected_systems.append(system)
        
        return incident
    
    def _get_incident(self, incident_id: str) -> Incident:
        """Get incident by ID."""
        if incident_id not in self._incidents:
            raise ValueError(f"Incident not found: {incident_id}")
        return self._incidents[incident_id]
    
    def get_incident(self, incident_id: str) -> Optional[Dict]:
        """Get incident details as dict."""
        try:
            incident = self._get_incident(incident_id)
            data = incident.to_dict()
            data["status_history"] = self._status_history.get(incident_id, [])
            return data
        except ValueError:
            return None
    
    def get_all_incidents(self, status: Optional[str] = None) -> List[Dict]:
        """Get all incidents, optionally filtered by status."""
        incidents = list(self._incidents.values())
        if status:
            incidents = [i for i in incidents if i.status == status]
        
        # Sort by created_at descending
        incidents.sort(key=lambda i: i.created_at, reverse=True)
        
        results = []
        for incident in incidents:
            data = incident.to_dict()
            data["status_history"] = self._status_history.get(incident.incident_id, [])
            results.append(data)
        return results
    
    def get_active_incidents(self) -> List[Dict]:
        """Get all non-closed incidents."""
        return [
            i for i in self.get_all_incidents()
            if i["status"] != IncidentStatus.CLOSED.value
        ]
    
    def get_incidents_by_severity(self, severity: str) -> List[Dict]:
        """Get incidents filtered by severity."""
        return [
            i for i in self.get_all_incidents()
            if i["severity"] == severity
        ]
    
    def get_analyst_workload(self) -> Dict:
        """Get current analyst workload."""
        return {
            analyst_id: {
                "name": analyst["name"],
                "role": analyst["role"],
                "incidents_assigned": analyst["incidents_assigned"],
            }
            for analyst_id, analyst in self._analysts.items()
        }
    
    def get_sla_summary(self) -> Dict:
        """Get SLA compliance summary."""
        total = len(self._incidents)
        if total == 0:
            return {
                "total_incidents": 0,
                "open": 0,
                "investigating": 0,
                "resolved": 0,
                "closed": 0,
                "avg_resolution_time": None,
                "avg_time_to_close": None,
            }
        
        resolved_times = [
            i.time_to_resolve for i in self._incidents.values()
            if i.time_to_resolve is not None
        ]
        closed_times = [
            i.time_to_detect for i in self._incidents.values()
            if i.time_to_detect is not None
        ]
        
        status_counts = defaultdict(int)
        for incident in self._incidents.values():
            status_counts[incident.status] += 1
        
        return {
            "total_incidents": total,
            "open": status_counts.get(IncidentStatus.OPEN.value, 0),
            "investigating": status_counts.get(IncidentStatus.INVESTIGATING.value, 0),
            "resolved": status_counts.get(IncidentStatus.RESOLVED.value, 0),
            "closed": status_counts.get(IncidentStatus.CLOSED.value, 0),
            "avg_resolution_time": (
                int(sum(resolved_times) / len(resolved_times))
                if resolved_times else None
            ),
            "avg_time_to_close": (
                int(sum(closed_times) / len(closed_times))
                if closed_times else None
            ),
        }
    
    def _add_status_history(
        self,
        incident_id: str,
        status: str,
        note: str
    ) -> None:
        """Add entry to status history."""
        self._status_history[incident_id].append({
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "status": status,
            "note": note,
        })
    
    def get_all(self) -> List[Dict]:
        """Get all incidents."""
        return self.get_all_incidents()
