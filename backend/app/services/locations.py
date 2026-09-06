"""Location resolution: curated cities first, then Open-Meteo geocoding / BigDataCloud reverse."""

from __future__ import annotations

from typing import Any

from app.core.geo import (
    CURATED_HIT_KM,
    REVERSE_FALLBACK_KM,
    cities,
    city_by_id,
    is_coastal,
    nearest_city,
    search_cities,
)
from app.providers import bigdatacloud, open_meteo
from app.schemas.location import LocationResult


def geo_id(lat: float, lon: float) -> str:
    return f"geo:{round(float(lat), 4)},{round(float(lon), 4)}"


def from_curated(lat: float, lon: float) -> LocationResult | None:
    city, dist = nearest_city(lat, lon)
    if city and dist <= CURATED_HIT_KM:
        return LocationResult.from_city(city)
    return None


async def reverse(lat: float, lon: float) -> LocationResult:
    """05 §Reverse: BigDataCloud → nearest curated city (≤ 60 km) → "Lat, Lon"."""
    curated = from_curated(lat, lon)
    if curated:
        return curated

    res = await bigdatacloud.reverse(lat, lon)
    parsed = bigdatacloud.parse(res.data) if res.ok else None
    near, dist = nearest_city(lat, lon)

    if parsed:
        tz = near["tz"] if near and dist <= 150 else "Asia/Kolkata"
        return LocationResult(
            id=geo_id(lat, lon),
            name=parsed["name"],
            admin1=parsed.get("admin1"),
            admin2=parsed.get("admin2"),
            country=parsed.get("country") or "India",
            country_code=parsed.get("country_code") or "IN",
            lat=lat,
            lon=lon,
            timezone=tz,
            is_coastal=is_coastal(lat, lon),
            elevation_m=None,
            population=None,
        )

    if near and dist <= REVERSE_FALLBACK_KM:
        fallback = LocationResult.from_city(near)
        return fallback.model_copy(
            update={"id": geo_id(lat, lon), "lat": lat, "lon": lon,
                    "is_coastal": is_coastal(lat, lon)}
        )

    return LocationResult(
        id=geo_id(lat, lon),
        name=f"{round(lat, 2)}, {round(lon, 2)}",
        admin1=None,
        admin2=None,
        country=None,
        country_code=None,
        lat=lat,
        lon=lon,
        timezone=(near or {}).get("tz", "Asia/Kolkata") if near else "Asia/Kolkata",
        is_coastal=is_coastal(lat, lon),
    )


def _from_geocode_row(row: dict[str, Any]) -> LocationResult:
    lat, lon = float(row["latitude"]), float(row["longitude"])
    return LocationResult(
        id=f"om:{row.get('id') or geo_id(lat, lon)}",
        name=row.get("name") or "",
        admin1=row.get("admin1"),
        admin2=row.get("admin2"),
        country=row.get("country"),
        country_code=row.get("country_code"),
        lat=lat,
        lon=lon,
        timezone=row.get("timezone") or "Asia/Kolkata",
        is_coastal=is_coastal(lat, lon),
        elevation_m=row.get("elevation"),
        population=row.get("population"),
    )


async def search(q: str, limit: int = 8) -> list[LocationResult]:
    """Curated prefix hits first (instant, offline), then Open-Meteo, India-ranked."""
    out: list[LocationResult] = [LocationResult.from_city(c) for c in search_cities(q, limit)]
    if len(out) >= limit:
        return out[:limit]

    res = await open_meteo.geocode(q, count=max(10, limit))
    if res.ok:
        seen = {(round(r.lat, 2), round(r.lon, 2)) for r in out}
        for row in open_meteo.rank_geocode_results(res.data):
            try:
                loc = _from_geocode_row(row)
            except (KeyError, TypeError, ValueError):
                continue
            key = (round(loc.lat, 2), round(loc.lon, 2))
            if key in seen:
                continue
            seen.add(key)
            out.append(loc)
            if len(out) >= limit:
                break
    return out[:limit]


def popular(limit: int = 120) -> list[LocationResult]:
    """Curated Indian cities flagged `popular` (04: ≥ 40, includes coastal + hill)."""
    rows = [c for c in cities() if c.get("popular")]
    rows.sort(key=lambda c: -(c.get("population") or 0))
    return [LocationResult.from_city(c) for c in rows[:limit]]


def by_id(place_id: str) -> LocationResult | None:
    city = city_by_id(place_id)
    return LocationResult.from_city(city) if city else None
