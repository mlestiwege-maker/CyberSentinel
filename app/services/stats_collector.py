"""
Resilience statistics tracker for backend health monitoring.
Tracks performance and failure metrics per endpoint.
"""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, Optional


@dataclass
class EndpointStats:
    """Statistics for a single endpoint."""
    endpoint: str
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    error_rate: float = 0.0
    avg_response_time_ms: float = 0.0
    p99_response_time_ms: float = 0.0
    last_failure_time: Optional[datetime] = None
    last_failure_reason: str = ""
    consecutive_failures: int = 0
    
    def __post_init__(self):
        """Recalculate derived metrics after init."""
        self._update_metrics()
    
    def _update_metrics(self):
        """Recalculate error rate and stats."""
        if self.total_requests > 0:
            self.error_rate = (self.failed_requests / self.total_requests) * 100.0
        else:
            self.error_rate = 0.0


class ResilienceStatsCollector:
    """Collects and tracks resilience statistics per endpoint."""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._stats: Dict[str, EndpointStats] = {}
        return cls._instance
    
    def record_request(
        self,
        endpoint: str,
        success: bool,
        response_time_ms: float,
        error: Optional[str] = None,
    ) -> None:
        """Record a request to an endpoint."""
        if endpoint not in self._stats:
            self._stats[endpoint] = EndpointStats(endpoint=endpoint)
        
        stats = self._stats[endpoint]
        stats.total_requests += 1
        
        if success:
            stats.successful_requests += 1
            stats.consecutive_failures = 0
        else:
            stats.failed_requests += 1
            stats.consecutive_failures += 1
            stats.last_failure_time = datetime.now()
            if error:
                stats.last_failure_reason = error
        
        # Update error rate
        stats._update_metrics()
    
    def get_stats(self, endpoint: str) -> Optional[EndpointStats]:
        """Get statistics for a specific endpoint."""
        return self._stats.get(endpoint)
    
    def get_all_stats(self) -> Dict[str, EndpointStats]:
        """Get statistics for all endpoints."""
        return self._stats.copy()
    
    def get_health_status(self) -> Dict[str, object]:
        """
        Get overall health status.
        Returns status and summary metrics.
        """
        if not self._stats:
            return {
                "status": "healthy",
                "message": "No traffic yet",
                "endpoints": {},
            }
        
        total_requests = sum(s.total_requests for s in self._stats.values())
        total_failures = sum(s.failed_requests for s in self._stats.values())
        overall_error_rate = (total_failures / total_requests * 100) if total_requests > 0 else 0.0
        
        # Status rules:
        # healthy: error rate < 5%
        # degraded: 5% <= error rate < 20%
        # critical: error rate >= 20%
        if overall_error_rate >= 20:
            status = "critical"
        elif overall_error_rate >= 5:
            status = "degraded"
        else:
            status = "healthy"
        
        return {
            "status": status,
            "overall_error_rate_percent": round(overall_error_rate, 2),
            "total_requests": total_requests,
            "total_failures": total_failures,
            "endpoints": {
                name: {
                    "total_requests": stats.total_requests,
                    "successful_requests": stats.successful_requests,
                    "failed_requests": stats.failed_requests,
                    "error_rate_percent": round(stats.error_rate, 2),
                    "consecutive_failures": stats.consecutive_failures,
                    "last_failure_reason": stats.last_failure_reason,
                }
                for name, stats in self._stats.items()
            },
        }
    
    def reset(self) -> None:
        """Clear all statistics."""
        self._stats.clear()
