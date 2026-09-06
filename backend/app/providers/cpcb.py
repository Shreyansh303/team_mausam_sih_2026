"""Optional CPCB station AQI via data.gov.in — active only when DATA_GOV_IN_KEY is set."""

from __future__ import annotations

from typing import Any

from app.config import settings
from app.core import cache
from app.core.geo import haversine_km
from app.providers.base import fetch_json

SOURCE = "cpcb"
RESOURCE_ID = "3b01bcb8-0b14-4abf-b6f2-c1bfd384ba69"  # CPCB "Real time Air Quality Index"
BASE_URL = "https://api.data.gov.in/resource"
MAX_STATION_KM = 40.0


def enabled() -> bool:
    return bool(settings.data_gov_in_key)


async def nearest_station(lat: float, lon: float) -> dict[str, Any] | None:
    """Nearest CPCB station reading, or None when the key is absent/upstream fails."""
    if not enabled():
        return None

    async def _go() -> Any:
        res = await fetch_json(
            f"{BASE_URL}/{RESOURCE_ID}",
            {"api-key": settings.data_gov_in_key, "format": "json", "limit": 2000},
            source=SOURCE,
        )
        return res.data if res.ok else None

    payload = await cache.get_or_fetch(
        "cpcb", cache.key_for("cpcb"), settings.cache_ttl_air, _go
    )
    if not payload:
        return None
    best: dict[str, Any] | None = None
    best_d = MAX_STATION_KM
    for rec in payload.get("records") or []:
        try:
            d = haversine_km(lat, lon, float(rec["latitude"]), float(rec["longitude"]))
        except (KeyError, TypeError, ValueError):
            continue
        if d < best_d:
            best, best_d = rec, d
    if not best:
        return None
    return {"station": best.get("station"), "distance_km": round(best_d, 1), "record": best}
