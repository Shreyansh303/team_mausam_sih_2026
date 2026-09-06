"""Commute windows, impact/delay and the traffic estimator (02 §28, 05 §Traffic)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from app.core.timeutil import iso, next_occurrence
from app.services.util import FOG_CODES, THUNDER_CODES, has_code, hours_between, vmax, vmin

WINDOWS: list[tuple[str, tuple[int, int], tuple[int, int]]] = [
    ("morning", (8, 0), (10, 0)),
    ("evening", (17, 0), (20, 0)),
]

IMPACTS = ("low", "moderate", "high", "severe")
_RANK = {v: i for i, v in enumerate(IMPACTS)}
URGENCY = {"low": 0.0, "moderate": 0.4, "high": 0.7, "severe": 0.9}

#: 05 §Traffic — congestion base by local hour.
PEAK_HOURS = {8, 9, 17, 18, 19}
SHOULDER_HOURS = {7, 10, 16, 20}
MIDDAY_HOURS = {11, 12, 13, 14, 15}

WEATHER_MULTIPLIER = {"rain": 1.3, "heavy": 1.6, "fog": 1.5, "storm": 1.8}


def congestion_base(hour: int) -> int:
    if hour in PEAK_HOURS:
        return 70
    if hour in SHOULDER_HOURS:
        return 50
    if hour in MIDDAY_HOURS:
        return 40
    return 20


def weather_key(
    *,
    precip_mm: float | None,
    precip_prob_pct: float | None,
    visibility_km: float | None,
    thunderstorm: bool,
) -> str | None:
    """Pick the strongest applicable weather multiplier key."""
    if thunderstorm:
        return "storm"
    if visibility_km is not None and visibility_km < 1:
        return "fog"
    if precip_mm is not None and precip_mm >= 7.6:
        return "heavy"
    if (precip_mm or 0) > 0 or (precip_prob_pct or 0) >= 40:
        return "rain"
    return None


def estimate_congestion(
    *,
    hour: int,
    precip_mm: float | None = None,
    precip_prob_pct: float | None = None,
    visibility_km: float | None = None,
    thunderstorm: bool = False,
) -> dict[str, Any]:
    base = congestion_base(hour)
    key = weather_key(
        precip_mm=precip_mm,
        precip_prob_pct=precip_prob_pct,
        visibility_km=visibility_km,
        thunderstorm=thunderstorm,
    )
    mult = WEATHER_MULTIPLIER.get(key or "", 1.0)
    return {
        "congestion_pct": int(min(100, round(base * mult))),
        "source": "estimated",
        "weather_factor": key,
    }


def impact_for(
    *,
    precip_prob_pct: float | None,
    visibility_km: float | None,
    wind_kph: float | None,
    thunderstorm: bool,
    severe_warning: bool,
) -> tuple[str, list[str]]:
    reasons: list[str] = []
    if severe_warning:
        reasons.append("Storm/fog warning in force")
    if visibility_km is not None and visibility_km < 0.5:
        reasons.append(f"Visibility {visibility_km:.1f} km")
    if reasons:
        return "severe", reasons

    if precip_prob_pct is not None and precip_prob_pct >= 70:
        reasons.append(f"Rain chance {int(precip_prob_pct)}%")
    if visibility_km is not None and visibility_km < 1:
        reasons.append(f"Visibility {visibility_km:.1f} km")
    if thunderstorm:
        reasons.append("Thunderstorm expected")
    if reasons:
        return "high", reasons

    if precip_prob_pct is not None and precip_prob_pct >= 40:
        reasons.append(f"Rain chance {int(precip_prob_pct)}%")
    if visibility_km is not None and visibility_km < 2:
        reasons.append(f"Visibility {visibility_km:.1f} km")
    if wind_kph is not None and wind_kph >= 40:
        reasons.append(f"Wind {int(wind_kph)} km/h")
    if reasons:
        return "moderate", reasons

    return "low", ["Clear run expected"]


def delay_minutes(*, peak: bool, weather: str | None) -> int:
    base = 12 if peak else 5
    return int(round(base * WEATHER_MULTIPLIER.get(weather or "", 1.0)))


def build(
    *,
    hourly: list[dict[str, Any]],
    now: datetime,
    severe_warning: bool = False,
    tomtom_congestion: int | None = None,
) -> dict[str, Any]:
    out: list[dict[str, Any]] = []
    for label, start_hm, end_hm in WINDOWS:
        start, end = next_occurrence(now, start_hm, end_hm)
        rows = hours_between(hourly, start, end)
        prob = vmax(rows, "precip_prob_pct")
        mm = vmax(rows, "precip_mm")
        vis = vmin(rows, "visibility_km")
        wind = vmax(rows, "wind_kph")
        thunder = has_code(rows, THUNDER_CODES)
        fog = has_code(rows, FOG_CODES)
        impact, reasons = impact_for(
            precip_prob_pct=prob,
            visibility_km=vis,
            wind_kph=wind,
            thunderstorm=thunder,
            severe_warning=severe_warning,
        )
        wkey = weather_key(
            precip_mm=mm,
            precip_prob_pct=prob,
            visibility_km=vis if not fog else min(vis or 0.9, 0.9),
            thunderstorm=thunder,
        )
        out.append(
            {
                "label": label,
                "start": iso(start),
                "end": iso(end),
                "impact": impact,
                "delay_min": delay_minutes(peak=True, weather=wkey),
                "rain_prob_pct": prob,
                "visibility_km": None if vis is None else round(vis, 2),
                "temp_c": vmax(rows, "temp_c"),
                "reasons": reasons,
            }
        )

    # Traffic "now"
    current_rows = hours_between(hourly, now.replace(minute=0, second=0, microsecond=0), now.replace(minute=59, second=59))
    cur = current_rows[0] if current_rows else {}
    traffic = estimate_congestion(
        hour=now.hour,
        precip_mm=cur.get("precip_mm"),
        precip_prob_pct=cur.get("precip_prob_pct"),
        visibility_km=cur.get("visibility_km"),
        thunderstorm=has_code([cur] if cur else [], THUNDER_CODES),
    )
    if tomtom_congestion is not None:
        traffic = {"congestion_pct": tomtom_congestion, "source": "tomtom", "weather_factor": None}

    overall = max((w["impact"] for w in out), key=lambda v: _RANK[v], default="low")
    return {
        "windows": out,
        "traffic": {"congestion_pct": traffic["congestion_pct"], "source": traffic["source"]},
        "advice": _ADVICE[overall],
        "overall_impact": overall,
        "urgency": URGENCY[overall],
    }


_ADVICE = {
    "low": "Usual travel time — no weather delays expected.",
    "moderate": "Add ~10 minutes and carry a raincoat.",
    "high": "Leave early; expect slow traffic and standing water.",
    "severe": "Travel only if necessary — severe conditions on the route.",
}
