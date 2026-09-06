"""Travel / flight disruption risk for a location (02 §20 flight-risk rule)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from app.services.util import (
    FOG_CODES,
    SNOW_CODES,
    THUNDER_CODES,
    has_code,
    next_hours,
    vmax,
    vmin,
)

LEVELS = ("low", "medium", "high")
URGENCY = {"low": 0.0, "medium": 0.4, "high": 0.8}


def build(
    *,
    hourly: list[dict[str, Any]],
    now: datetime,
    warnings: list[dict[str, Any]] | None = None,
    horizon_hours: int = 12,
) -> dict[str, Any]:
    rows = next_hours(hourly, now, horizon_hours)
    warnings = warnings or []
    severities = {w.get("severity") for w in warnings}
    hazard_set = {w.get("hazard") for w in warnings}

    vis = vmin(rows, "visibility_km")
    gust = vmax(rows, "gust_kph")
    prob = vmax(rows, "precip_prob_pct")
    precip = vmax(rows, "precip_mm")
    thunder = has_code(rows, THUNDER_CODES)
    fog = has_code(rows, FOG_CODES) or (vis is not None and vis < 1)
    snow = has_code(rows, SNOW_CODES)

    hazards: list[str] = []
    if fog:
        hazards.append("fog")
    if thunder:
        hazards.append("thunderstorm")
    if gust is not None and gust >= 45:
        hazards.append("strong_wind")
    if "cyclone" in hazard_set:
        hazards.append("cyclone")
    if (precip or 0) >= 15 or "heavy_rain" in hazard_set or "very_heavy_rain" in hazard_set:
        hazards.append("heavy_rain")
    if snow:
        hazards.append("snow")
    if "dust_storm" in hazard_set:
        hazards.append("dust_storm")

    risk = "low"
    if (
        (vis is not None and vis < 1)
        or thunder
        or (gust is not None and gust >= 60)
        or "cyclone" in hazard_set
        or "red" in severities
    ):
        risk = "high"
    elif (
        (vis is not None and vis < 3)
        or (gust is not None and gust >= 45)
        or "orange" in severities
        or (prob is not None and prob >= 70)
    ):
        risk = "medium"

    detail = _detail(risk, hazards, vis, gust, prob)
    return {
        "risk": risk,
        "hazards": sorted(set(hazards)),
        "detail": detail,
        "visibility_km": None if vis is None else round(vis, 2),
        "gust_kph": gust,
        "precip_prob_pct": prob,
        "urgency": URGENCY[risk],
    }


def _detail(
    risk: str,
    hazards: list[str],
    vis: float | None,
    gust: float | None,
    prob: float | None,
) -> str:
    if risk == "low":
        return "No weather disruption expected in the next 12 hours."
    bits: list[str] = []
    if vis is not None and vis < 3:
        bits.append(f"visibility down to {vis:.1f} km")
    if gust is not None and gust >= 45:
        bits.append(f"gusts to {int(gust)} km/h")
    if prob is not None and prob >= 70:
        bits.append(f"{int(prob)}% rain chance")
    if not bits and hazards:
        bits.append(", ".join(h.replace("_", " ") for h in hazards))
    lead = "Delays likely" if risk == "high" else "Minor delays possible"
    return f"{lead}: {'; '.join(bits)}." if bits else f"{lead}."
