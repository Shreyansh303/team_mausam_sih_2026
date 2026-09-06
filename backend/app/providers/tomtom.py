"""Optional TomTom traffic flow — active only when TOMTOM_KEY is set (05 §Traffic)."""

from __future__ import annotations

from app.config import settings
from app.core import cache
from app.providers.base import fetch_json

SOURCE = "tomtom"
FLOW_URL = "https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/10/json"


def enabled() -> bool:
    return bool(settings.tomtom_key)


async def congestion_pct(lat: float, lon: float) -> int | None:
    """Congestion as 100·(1 − currentSpeed/freeFlowSpeed), or None when unavailable."""
    if not enabled():
        return None

    async def _go() -> int | None:
        res = await fetch_json(
            FLOW_URL,
            {"key": settings.tomtom_key, "point": f"{lat},{lon}", "unit": "KMPH"},
            source=SOURCE,
        )
        if not res.ok or not res.data:
            return None
        seg = (res.data or {}).get("flowSegmentData") or {}
        cur, free = seg.get("currentSpeed"), seg.get("freeFlowSpeed")
        if not cur or not free:
            return None
        return max(0, min(100, round(100 * (1 - float(cur) / float(free)))))

    return await cache.get_or_fetch(
        "tomtom", cache.key_for("tomtom", lat, lon), 300, _go
    )
