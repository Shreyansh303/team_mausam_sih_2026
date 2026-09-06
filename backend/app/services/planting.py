"""Planting guidance from data/planting_calendar.json, enriched with soil + rain (02 §27)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from app.core.geo import planting_calendar

ZONES = ("north", "south", "east", "west", "central", "northeast", "hills")

#: state / UT → agro zone used by the calendar.
STATE_ZONE: dict[str, str] = {
    "jammu and kashmir": "hills",
    "ladakh": "hills",
    "himachal pradesh": "hills",
    "uttarakhand": "hills",
    "sikkim": "hills",
    "punjab": "north",
    "haryana": "north",
    "delhi": "north",
    "nct of delhi": "north",
    "chandigarh": "north",
    "uttar pradesh": "north",
    "rajasthan": "west",
    "gujarat": "west",
    "maharashtra": "west",
    "goa": "west",
    "dadra and nagar haveli and daman and diu": "west",
    "madhya pradesh": "central",
    "chhattisgarh": "central",
    "bihar": "east",
    "jharkhand": "east",
    "west bengal": "east",
    "odisha": "east",
    "assam": "northeast",
    "arunachal pradesh": "northeast",
    "manipur": "northeast",
    "meghalaya": "northeast",
    "mizoram": "northeast",
    "nagaland": "northeast",
    "tripura": "northeast",
    "karnataka": "south",
    "kerala": "south",
    "tamil nadu": "south",
    "andhra pradesh": "south",
    "telangana": "south",
    "puducherry": "south",
    "andaman and nicobar islands": "south",
    "lakshadweep": "south",
}


def zone_for(state: str | None, elevation_m: float | None = None) -> str:
    if elevation_m is not None and elevation_m >= 1200:
        return "hills"
    if not state:
        return "north"
    key = state.strip().lower()
    if key in STATE_ZONE:
        return STATE_ZONE[key]
    for name, zone in STATE_ZONE.items():
        if name in key or key in name:
            return zone
    return "north"


def season_for(month: int) -> str:
    """kharif Jun–Oct · rabi Nov–Mar · zaid Apr–May."""
    if 6 <= month <= 10:
        return "kharif"
    if month in (4, 5):
        return "zaid"
    return "rabi"


def soil_status(surface: float | None) -> str | None:
    """02 §24 bands on volumetric soil moisture (m³/m³)."""
    if surface is None:
        return None
    v = float(surface)
    if v < 0.10:
        return "very_dry"
    if v < 0.18:
        return "dry"
    if v < 0.30:
        return "adequate"
    if v < 0.40:
        return "wet"
    return "saturated"


def build(
    *,
    now: datetime,
    state: str | None,
    elevation_m: float | None = None,
    soil_surface: float | None = None,
    rain_next_72h_mm: float | None = None,
) -> dict[str, Any]:
    zone = zone_for(state, elevation_m)
    month = now.month
    calendar = planting_calendar()
    crops = list((calendar.get(zone) or {}).get(str(month)) or [])[:4]
    tips: list[str] = []

    status = soil_status(soil_surface)
    if status == "very_dry":
        tips.append("Topsoil is very dry — irrigate before sowing or transplanting.")
    elif status == "dry":
        tips.append("Topsoil is dry — a light irrigation will help germination.")
    elif status in ("wet", "saturated"):
        tips.append("Soil is wet — hold back irrigation and check field drainage.")

    if rain_next_72h_mm is not None:
        if rain_next_72h_mm >= 35:
            tips.append(
                f"Delay irrigation: {rain_next_72h_mm:.0f} mm of rain expected in the next 3 days."
            )
        elif rain_next_72h_mm < 5 and status in ("very_dry", "dry"):
            tips.append("Little rain in the next 3 days — plan irrigation.")

    if not tips:
        tips.append("Conditions are normal for this stage — follow the usual schedule.")

    return {
        "season": season_for(month),
        "zone": zone,
        "month": month,
        "crops": crops,
        "tips": tips,
        "soil_status": status,
        "urgency": 0.0,
    }
