from __future__ import annotations

import threading
import time
from collections import defaultdict, deque


class InMemoryRateLimiter:
    def __init__(self, limit_per_minute: int = 30, window_seconds: int = 60) -> None:
        self._limit = max(1, limit_per_minute)
        self._window_seconds = max(1, window_seconds)
        self._buckets: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()
        self._last_cleanup = 0.0
        self._max_tracked_keys = max(512, self._limit * 16)

    def allow(self, key: str) -> tuple[bool, int]:
        now = time.time()
        window_start = now - self._window_seconds
        with self._lock:
            bucket = self._buckets[key]
            while bucket and bucket[0] < window_start:
                bucket.popleft()

            if len(bucket) >= self._limit:
                retry_after = int(max(1, self._window_seconds - (now - bucket[0])))
                return False, retry_after

            bucket.append(now)
            self._cleanup_stale_locked(window_start, now)
            return True, 0

    def _cleanup_stale_locked(self, window_start: float, now: float) -> None:
        if now - self._last_cleanup < self._window_seconds:
            return
        self._last_cleanup = now

        stale_keys = [
            bucket_key
            for bucket_key, values in self._buckets.items()
            if (not values) or values[-1] < window_start
        ]
        for bucket_key in stale_keys:
            self._buckets.pop(bucket_key, None)

        if len(self._buckets) <= self._max_tracked_keys:
            return

        # Prune least-recent buckets if key count grows unexpectedly.
        buckets_by_last_seen = sorted(
            self._buckets.items(),
            key=lambda item: item[1][-1] if item[1] else 0.0,
        )
        to_remove = len(self._buckets) - self._max_tracked_keys
        for bucket_key, _ in buckets_by_last_seen[:to_remove]:
            self._buckets.pop(bucket_key, None)
