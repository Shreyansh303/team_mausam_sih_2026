"""Sea state (Douglas), surf rating, swim safety and water temperature (02 §16/18)."""

from __future__ import annotations

from typing import Any

SEA_STATES = ("Calm", "Smooth", "Slight", "Moderate", "Rough", "Very Rough", "High")


def sea_state(wave_height_m: float | None) -> str | None:
    """Douglas scale by wave height (02 §16)."""
    if wave_height_m is None:
        return None
    h = float(wave_height_m)
    if h < 0.1:
        return "Calm"
    if h < 0.5:
        return "Smooth"
    if h < 1.25:
        return "Slight"
    if h < 2.5:
        return "Moderate"
    if h < 4:
        return "Rough"
    if h < 6:
        return "Very Rough"
    return "High"


def safe_for_swimming(
    wave_height_m: float | None, current_kph: float | None, hazards: set[str] | None = None
) -> bool:
    """wave < 1.5 m and current < 3 kph and no cyclone / strong-wind warning."""
    hazards = hazards or set()
    if wave_height_m is None:
        return False
    if float(wave_height_m) >= 1.5:
        return False
    if current_kph is not None and float(current_kph) >= 3.0:
        return False
    return not ({"cyclone", "strong_wind"} & hazards)


def surf_rating(wave_height_m: float | None, period_s: float | None) -> int:
    """0–5 stars. 1.0–2.5 m with period ≥ 8 s is the 4–5 star window (02 §16)."""
    if wave_height_m is None:
        return 0
    h = float(wave_height_m)
    p = float(period_s) if period_s is not None else 0.0
    if h < 0.3:
        return 0
    if h < 0.6:
        return 1
    if h < 1.0:
        return 2 if p >= 8 else 1
    if h <= 2.5:
        if p >= 10 and h >= 1.5:
            return 5
        return 4 if p >= 8 else 3
    return 3 if p >= 8 else 2


def urgency(state: str | None, hazards: set[str] | None = None) -> float:
    hazards = hazards or set()
    if "cyclone" in hazards:
        return 1.0
    if state in ("Very Rough", "High"):
        return 0.9
    if state == "Rough":
        return 0.6
    return 0.0


def water_category(sst_c: float | None) -> str | None:
    """02 §18: Cold <20 · Cool 20–24 · Pleasant 24–29 · Warm >29."""
    if sst_c is None:
        return None
    t = float(sst_c)
    if t < 20:
        return "Cold"
    if t < 24:
        return "Cool"
    if t <= 29:
        return "Pleasant"
    return "Warm"


WETSUIT_ADVICE = {
    "Cold": "Full wetsuit recommended.",
    "Cool": "Shorty wetsuit is comfortable.",
    "Pleasant": "No wetsuit needed.",
    "Warm": "Bath-warm water — rash guard for sun protection only.",
}


def advisory(
    state: str | None, safe: bool, hazards: set[str] | None = None
) -> str:
    hazards = hazards or set()
    if "cyclone" in hazards:
        return "Cyclone warning in force — stay away from the shoreline."
    if state in ("Very Rough", "High"):
        return "Very rough sea — no boating or swimming."
    if state == "Rough":
        return "Rough sea — strong currents likely, swim only at patrolled beaches."
    if not safe:
        return "Choppy water — not safe for casual swimming."
    return "Sea conditions are suitable for a swim near the shore."


def build(marine: dict[str, Any] | None, hazards: set[str] | None = None) -> dict[str, Any] | None:
    """02 §16 `data` for the sea_conditions card, computed from the marine block."""
    if not marine:
        return None
    wave = marine.get("wave_height_m")
    period = marine.get("wave_period_s")
    current = marine.get("current_kph")
    state = sea_state(wave)
    safe = safe_for_swimming(wave, current, hazards)
    sst = marine.get("sst_c")
    cat = water_category(sst)
    return {
        "sea_state": state,
        "wave_height_m": wave,
        "wave_period_s": period,
        "wave_direction_deg": marine.get("wave_direction_deg"),
        "swell_height_m": marine.get("swell_height_m"),
        "current_kph": current,
        "sst_c": sst,
        "safe_for_swimming": safe,
        "surf_rating": surf_rating(wave, period),
        "advisory": advisory(state, safe, hazards),
        "water_category": cat,
        "wetsuit_advice": WETSUIT_ADVICE.get(cat or "", ""),
        "urgency": urgency(state, hazards),
        "hourly": marine.get("hourly", []),
        "source": marine.get("source", "open-meteo"),
    }
