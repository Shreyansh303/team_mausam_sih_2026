"""Warning merge + location filter (05 §Warnings merge).

Sources: IMD (when whitelisted), admin-injected rows from the DB and the active scenario.
Filter: same district · same state for cyclone/heatwave/cold_wave · or within `radius_km`.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta
from typing import Any

from app.core.geo import haversine_km
from app.core.timeutil import UTC, iso, parse_any
from app.schemas.warning import SEVERITY_RANK, color_for

#: Hazards whose warnings apply to a whole state, not just one district.
STATEWIDE_HAZARDS = {"cyclone", "heatwave", "cold_wave"}


def make_warning(
    *,
    severity: str,
    hazard: str,
    title: str,
    description: str = "",
    now: datetime,
    district: str | None = None,
    state: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
    radius_km: float | None = 75.0,
    source: str = "scenario",
    valid_hours: float = 12.0,
    valid_from: str | None = None,
    valid_to: str | None = None,
    wid: str | None = None,
) -> dict[str, Any]:
    return {
        "id": wid or f"wrn_{uuid.uuid4().hex[:10]}",
        "severity": severity,
        "hazard": hazard,
        "title": title,
        "description": description,
        "issued_at": iso(now),
        "valid_from": valid_from or iso(now),
        "valid_to": valid_to or iso(now + timedelta(hours=valid_hours)),
        "district": district,
        "state": state,
        "lat": lat,
        "lon": lon,
        "radius_km": radius_km,
        "source": source,
        "color_hex": color_for(severity),
    }


def from_scenario(
    scenario: dict[str, Any] | None,
    *,
    now: datetime,
    district: str | None,
    state: str | None,
    lat: float,
    lon: float,
) -> list[dict[str, Any]]:
    """Scenario warnings adopt the request location's district/state (05 §Scenarios)."""
    out: list[dict[str, Any]] = []
    for raw in (scenario or {}).get("warnings") or []:
        out.append(
            make_warning(
                severity=raw.get("severity", "yellow"),
                hazard=raw.get("hazard", "other"),
                title=raw.get("title", "Weather warning"),
                description=raw.get("description", ""),
                now=now,
                district=raw.get("district") or district,
                state=raw.get("state") or state,
                lat=raw.get("lat", lat),
                lon=raw.get("lon", lon),
                radius_km=raw.get("radius_km", 100.0),
                source="scenario",
                valid_hours=float(raw.get("valid_hours", 12)),
                wid=raw.get("id"),
            )
        )
    return out


def is_active(w: dict[str, Any], now: datetime) -> bool:
    try:
        return parse_any(w["valid_to"]) > now
    except (KeyError, ValueError, TypeError):
        return True


def _norm(v: str | None) -> str:
    return (v or "").strip().lower()


def applies_to(
    w: dict[str, Any], *, lat: float, lon: float, district: str | None, state: str | None
) -> bool:
    if district and _norm(w.get("district")) and _norm(w["district"]) == _norm(district):
        return True
    if (
        w.get("hazard") in STATEWIDE_HAZARDS
        and state
        and _norm(w.get("state"))
        and _norm(w["state"]) == _norm(state)
    ):
        return True
    if w.get("lat") is not None and w.get("lon") is not None and w.get("radius_km"):
        if haversine_km(lat, lon, float(w["lat"]), float(w["lon"])) <= float(w["radius_km"]):
            return True
    return False


def merge(
    *,
    now: datetime | None = None,
    lat: float,
    lon: float,
    district: str | None = None,
    state: str | None = None,
    imd: list[dict[str, Any]] | None = None,
    admin: list[dict[str, Any]] | None = None,
    scenario: list[dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    now = now or datetime.now(UTC)
    merged: list[dict[str, Any]] = []
    seen: set[str] = set()
    for group in (imd or [], admin or [], scenario or []):
        for w in group:
            if w.get("id") in seen:
                continue
            if not is_active(w, now):
                continue
            if not applies_to(w, lat=lat, lon=lon, district=district, state=state):
                continue
            seen.add(w.get("id", ""))
            merged.append(w)
    merged.sort(key=lambda w: SEVERITY_RANK.get(w.get("severity", "yellow"), 0), reverse=True)
    return merged


def highest(warnings: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not warnings:
        return None
    return max(warnings, key=lambda w: SEVERITY_RANK.get(w.get("severity", "yellow"), 0))


def hazard_set(warnings: list[dict[str, Any]]) -> set[str]:
    return {w.get("hazard", "other") for w in warnings}


def has_severe(warnings: list[dict[str, Any]], min_severity: str = "orange") -> bool:
    floor = SEVERITY_RANK.get(min_severity, 2)
    return any(SEVERITY_RANK.get(w.get("severity", "yellow"), 0) >= floor for w in warnings)
