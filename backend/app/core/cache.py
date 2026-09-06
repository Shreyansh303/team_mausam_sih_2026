"""TTL cache facade (in-process `cachetools`, Redis when REDIS_URL is set).

Only the in-process backend is implemented for the demo; the Redis facade is a documented
extension point (01: "In-process TTL cache, Redis when REDIS_URL is set").
"""

from __future__ import annotations

import asyncio
import time
from collections.abc import Awaitable, Callable
from typing import Any

from cachetools import TTLCache

_MAXSIZE = 2048

# One store per "kind" so TTLs differ per provider family.
_stores: dict[str, TTLCache] = {}
_locks: dict[str, asyncio.Lock] = {}


def _store(kind: str, ttl: int) -> TTLCache:
    st = _stores.get(kind)
    if st is None or st.ttl != ttl:
        st = TTLCache(maxsize=_MAXSIZE, ttl=max(1, ttl))
        _stores[kind] = st
    return st


def key_for(kind: str, lat: float | None = None, lon: float | None = None, **extra: Any) -> str:
    """Cache key: kind + rounded (lat, lon) to 2 dp + sorted extras (05)."""
    parts = [kind]
    if lat is not None and lon is not None:
        parts.append(f"{round(float(lat), 2):.2f},{round(float(lon), 2):.2f}")
    for k in sorted(extra):
        v = extra[k]
        if v is not None:
            parts.append(f"{k}={v}")
    return "|".join(parts)


def get(kind: str, key: str, ttl: int) -> Any | None:
    return _store(kind, ttl).get(key)


def set(kind: str, key: str, value: Any, ttl: int) -> None:  # noqa: A001 - facade name
    _store(kind, ttl)[key] = value


def invalidate(kind: str | None = None) -> None:
    if kind is None:
        _stores.clear()
        return
    _stores.pop(kind, None)


def clear_all() -> None:
    _stores.clear()


async def get_or_fetch(
    kind: str,
    key: str,
    ttl: int,
    fetch: Callable[[], Awaitable[Any]],
) -> Any:
    """Return the cached value or await `fetch()` once (per-key lock avoids stampedes)."""
    st = _store(kind, ttl)
    hit = st.get(key, _MISS)
    if hit is not _MISS:
        return hit
    lock = _locks.setdefault(key, asyncio.Lock())
    async with lock:
        hit = st.get(key, _MISS)
        if hit is not _MISS:
            return hit
        value = await fetch()
        st[key] = value
        return value


class _Miss:
    __slots__ = ()


_MISS = _Miss()


def stats() -> dict[str, int]:
    return {k: len(v) for k, v in _stores.items()}


def now_ts() -> float:
    return time.time()
