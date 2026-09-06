"""BigDataCloud reverse geocoding (free, keyless) — 05 §Reverse."""

from __future__ import annotations

from typing import Any

from app.config import settings
from app.core import cache
from app.providers.base import Result, fetch_json

SOURCE = "bigdatacloud"


async def reverse(lat: float, lon: float) -> Result:
    key = cache.key_for("bdc_reverse", lat, lon)
    return await cache.get_or_fetch(
        "bdc_reverse",
        key,
        settings.cache_ttl_geocode,
        lambda: fetch_json(
            settings.bigdatacloud_url,
            {"latitude": lat, "longitude": lon, "localityLanguage": "en"},
            source=SOURCE,
        ),
    )


def parse(payload: dict[str, Any] | None) -> dict[str, Any] | None:
    """`city|locality` + `principalSubdivision` + administrative level 5/6 as the district."""
    if not payload:
        return None
    name = payload.get("city") or payload.get("locality") or payload.get("principalSubdivision")
    if not name:
        return None
    admins = ((payload.get("localityInfo") or {}).get("administrative")) or []
    district: str | None = None
    for level in (6, 5):
        for a in admins:
            if a.get("adminLevel") == level and a.get("name"):
                district = a["name"]
                break
        if district:
            break
    return {
        "name": name,
        "admin1": payload.get("principalSubdivision"),
        "admin2": district or payload.get("locality"),
        "country": payload.get("countryName"),
        "country_code": payload.get("countryCode"),
        "lat": payload.get("latitude"),
        "lon": payload.get("longitude"),
    }
