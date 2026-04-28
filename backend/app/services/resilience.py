"""
Resilience patterns for FastAPI backend: circuit breaker and retry logic.
"""

import asyncio
from enum import Enum
from functools import wraps
from time import time
from typing import Any, Callable, Optional


class CircuitState(Enum):
    """Circuit breaker states."""
    CLOSED = "closed"  # Normal operation
    OPEN = "open"  # Failing, reject requests
    HALF_OPEN = "half_open"  # Testing if service recovered


class CircuitBreaker:
    """
    Circuit breaker pattern implementation.
    Prevents cascade failures by temporarily stopping requests to failing services.
    """

    def __init__(
        self,
        failure_threshold: int = 5,
        recovery_timeout: float = 30.0,
        expected_exception: type = Exception,
    ):
        """
        Initialize circuit breaker.

        Args:
            failure_threshold: Number of failures before opening circuit
            recovery_timeout: Seconds to wait before attempting recovery
            expected_exception: Exception type that triggers failures
        """
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.expected_exception = expected_exception

        self.failure_count = 0
        self.success_count = 0
        self.last_failure_time: Optional[float] = None
        self.state = CircuitState.CLOSED

    def call(self, func: Callable, *args: Any, **kwargs: Any) -> Any:
        """Execute function with circuit breaker protection."""
        if self.state == CircuitState.OPEN:
            if self._should_attempt_reset():
                self.state = CircuitState.HALF_OPEN
                self.success_count = 0
            else:
                raise CircuitBreakerOpenException(
                    f"Circuit breaker is OPEN. Retry after {self.retry_after:.1f}s"
                )

        try:
            result = func(*args, **kwargs)

            if self.state == CircuitState.HALF_OPEN:
                self._on_success()

            return result

        except self.expected_exception as e:
            self._on_failure()
            raise

    async def async_call(
        self, func: Callable, *args: Any, **kwargs: Any
    ) -> Any:
        """Execute async function with circuit breaker protection."""
        if self.state == CircuitState.OPEN:
            if self._should_attempt_reset():
                self.state = CircuitState.HALF_OPEN
                self.success_count = 0
            else:
                raise CircuitBreakerOpenException(
                    f"Circuit breaker is OPEN. Retry after {self.retry_after:.1f}s"
                )

        try:
            result = await func(*args, **kwargs)

            if self.state == CircuitState.HALF_OPEN:
                self._on_success()

            return result

        except self.expected_exception as e:
            self._on_failure()
            raise

    def _on_failure(self) -> None:
        """Handle failure."""
        self.failure_count += 1
        self.last_failure_time = time()

        if self.failure_count >= self.failure_threshold:
            self.state = CircuitState.OPEN

    def _on_success(self) -> None:
        """Handle success."""
        self.failure_count = 0
        self.success_count += 1

        if self.state == CircuitState.HALF_OPEN:
            self.state = CircuitState.CLOSED

    def _should_attempt_reset(self) -> bool:
        """Check if recovery timeout has elapsed."""
        if self.last_failure_time is None:
            return False

        return (time() - self.last_failure_time) >= self.recovery_timeout

    @property
    def retry_after(self) -> float:
        """Seconds until circuit can be retried."""
        if self.last_failure_time is None:
            return 0.0

        elapsed = time() - self.last_failure_time
        remaining = self.recovery_timeout - elapsed
        return max(0.0, remaining)

    @property
    def is_open(self) -> bool:
        """Check if circuit is open."""
        return self.state == CircuitState.OPEN

    @property
    def is_half_open(self) -> bool:
        """Check if circuit is half-open."""
        return self.state == CircuitState.HALF_OPEN


class CircuitBreakerOpenException(Exception):
    """Raised when circuit breaker is open."""
    pass


class RetryPolicy:
    """
    Retry policy with exponential backoff.
    """

    def __init__(
        self,
        max_attempts: int = 3,
        base_delay_ms: float = 100,
        max_delay_ms: float = 5000,
        exponential_base: float = 2.0,
        jitter: bool = True,
    ):
        """
        Initialize retry policy.

        Args:
            max_attempts: Maximum number of retry attempts
            base_delay_ms: Base delay in milliseconds
            max_delay_ms: Maximum delay cap in milliseconds
            exponential_base: Base for exponential backoff
            jitter: Whether to add random jitter to delays
        """
        self.max_attempts = max_attempts
        self.base_delay_ms = base_delay_ms
        self.max_delay_ms = max_delay_ms
        self.exponential_base = exponential_base
        self.jitter = jitter

    def get_delay_ms(self, attempt: int) -> float:
        """Calculate delay for given attempt number."""
        # Exponential backoff: base_delay * exponential_base^(attempt-1)
        delay = self.base_delay_ms * (self.exponential_base ** (attempt - 1))
        delay = min(delay, self.max_delay_ms)

        if self.jitter:
            # Add random jitter (±10% of delay)
            import random
            jitter_amount = delay * 0.1 * (random.random() - 0.5)
            delay += jitter_amount

        return max(delay, 0)

    async def execute_async(
        self,
        func: Callable,
        *args: Any,
        retryable_exception: type = Exception,
        **kwargs: Any,
    ) -> Any:
        """Execute async function with retry logic."""
        last_exception = None

        for attempt in range(1, self.max_attempts + 1):
            try:
                return await func(*args, **kwargs)
            except retryable_exception as e:
                last_exception = e

                if attempt < self.max_attempts:
                    delay_ms = self.get_delay_ms(attempt)
                    await asyncio.sleep(delay_ms / 1000.0)

        raise last_exception or Exception("Retry exhausted")


def with_circuit_breaker(
    failure_threshold: int = 5,
    recovery_timeout: float = 30.0,
):
    """
    Decorator to add circuit breaker to a function.

    Usage:
        @with_circuit_breaker(failure_threshold=3)
        async def risky_operation():
            ...
    """
    breaker = CircuitBreaker(
        failure_threshold=failure_threshold,
        recovery_timeout=recovery_timeout,
    )

    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def async_wrapper(*args: Any, **kwargs: Any) -> Any:
            return await breaker.async_call(func, *args, **kwargs)

        return async_wrapper

    return decorator
