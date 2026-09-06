"""Geo helpers: haversine, curated-city lookup, coastal detection, compass text."""

from __future__ import annotations

import json
import math
from functools import lru_cache
from typing import Any

from app.config import settings

EARTH_R_KM = 6371.0088

#: A location within this distance of a coastline point is treated as coastal (05/02 gate).
COASTAL_RADIUS_KM = 40.0
#: A request within this distance of a curated city reuses the curated record (05 §Snapshot 1).
CURATED_HIT_KM = 3.0
#: Reverse geocode fallback radius (05 §Reverse).
REVERSE_FALLBACK_KM = 60.0

_COMPASS = [
    "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
    "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW",
]


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_R_KM * math.asin(min(1.0, math.sqrt(a)))


def compass(deg: float | None) -> str:
    if deg is None:
        return "—"
    return _COMPASS[int((float(deg) % 360) / 22.5 + 0.5) % 16]


def _read(name: str) -> Any:
    path = settings.data_dir / name
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


@lru_cache(maxsize=1)
def cities() -> list[dict[str, Any]]:
    return _read("cities.json")


@lru_cache(maxsize=1)
def coastal_points() -> list[dict[str, Any]]:
    return _read("coastal_points.json")


@lru_cache(maxsize=1)
def imd_ids() -> dict[str, Any]:
    return _read("imd_ids.json")


@lru_cache(maxsize=1)
def planting_calendar() -> dict[str, Any]:
    return _read("planting_calendar.json")


@lru_cache(maxsize=1)
def _cities_by_id() -> dict[str, dict[str, Any]]:
    return {c["id"]: c for c in cities()}


def city_by_id(cid: str) -> dict[str, Any] | None:
    return _cities_by_id().get(cid)


def nearest_city(lat: float, lon: float) -> tuple[dict[str, Any] | None, float]:
    """Nearest curated city and its distance in km."""
    best: dict[str, Any] | None = None
    best_d = float("inf")
    for c in cities():
        d = haversine_km(lat, lon, c["lat"], c["lon"])
        if d < best_d:
            best, best_d = c, d
    return best, best_d


def nearest_coastal_point(lat: float, lon: float) -> tuple[dict[str, Any] | None, float]:
    best: dict[str, Any] | None = None
    best_d = float("inf")
    for p in coastal_points():
        d = haversine_km(lat, lon, p["lat"], p["lon"])
        if d < best_d:
            best, best_d = p, d
    return best, best_d


def is_coastal(lat: float, lon: float, radius_km: float = COASTAL_RADIUS_KM) -> bool:
    """True when the point lies within `radius_km` of a curated coastline point."""
    _, d = nearest_coastal_point(lat, lon)
    return d <= radius_km


def search_cities(q: str, limit: int = 8) -> list[dict[str, Any]]:
    """Prefix-first curated search (instant, offline) — 05 §Geocode."""
    ql = q.strip().lower()
    if not ql:
        return []
    starts: list[tuple[int, dict[str, Any]]] = []
    contains: list[tuple[int, dict[str, Any]]] = []
    for c in cities():
        name = c["name"].lower()
        pop = c.get("population") or 0
        if name.startswith(ql):
            starts.append((-pop, c))
        elif ql in name or ql in (c.get("admin2") or "").lower():
            contains.append((-pop, c))
    starts.sort(key=lambda t: t[0])
    contains.sort(key=lambda t: t[0])
    return [c for _, c in (starts + contains)][:limit]


def bbox_contains(lat: float, lon: float) -> bool:
    """Rough India bounding box (used to prefer Indian defaults)."""
    return 6.0 <= lat <= 37.6 and 68.0 <= lon <= 97.5
