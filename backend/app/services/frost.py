"""Frost risk for the coming night (02 §26)."""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from app.services.util import hours_between, vmean, vmin

RISKS = ("none", "low", "moderate", "high")
_RANK = {r: i for i, r in enumerate(RISKS)}
URGENCY = {"none": 0.0, "low": 0.3, "moderate": 0.55, "high": 0.85}


def risk_for(
    tmin_c: float | None,
    wind_kph: float | None,
    cloud_pct: float | None,
    cold_wave_warning: bool = False,
) -> str:
    """02 §26 table; a cold-wave warning lifts the risk to at least moderate."""
    risk = "none"
    if tmin_c is not None:
        calm_clear = (wind_kph is not None and wind_kph < 10) and (
            cloud_pct is not None and cloud_pct < 30
        )
        t = float(tmin_c)
        if t <= 0:
            risk = "high"
        elif t <= 2:
            risk = "high" if calm_clear else "moderate"
        elif t <= 4:
            risk = "moderate" if calm_clear else "low"
        elif t <= 6:
            risk = "low"
    if cold_wave_warning and _RANK[risk] < _RANK["moderate"]:
        risk = "moderate"
    return risk


def night_window(now: datetime) -> tuple[datetime, datetime]:
    """Tonight 20:00 → tomorrow 08:00 local (or the current night if it is already dark)."""
    start = now.replace(hour=20, minute=0, second=0, microsecond=0)
    if now.hour < 8:
        start = start - timedelta(days=1)
    end = start + timedelta(hours=12)
    return start, end


def build(
    *,
    hourly: list[dict[str, Any]],
    now: datetime,
    cold_wave_warning: bool = False,
) -> dict[str, Any]:
    start, end = night_window(now)
    rows = hours_between(hourly, max(start, now - timedelta(hours=1)), end) or hours_between(
        hourly, start, end
    )
    tmin = vmin(rows, "temp_c")
    wind = vmean(rows, "wind_kph")
    cloud = vmean(rows, "cloud_pct")
    risk = risk_for(tmin, wind, cloud, cold_wave_warning)
    advice = _ADVICE.get(risk, [])
    return {
        "risk": risk,
        "tmin_c": tmin,
        "expected_night": end.date().isoformat(),
        "wind_kph": wind,
        "cloud_pct": cloud,
        "warning": cold_wave_warning,
        "advice": advice,
        "urgency": URGENCY[risk],
    }


_ADVICE = {
    "none": [],
    "low": [
        "Light frost possible in low-lying fields before dawn.",
        "Keep young seedlings covered overnight.",
    ],
    "moderate": [
        "Irrigate lightly in the evening — wet soil releases heat overnight.",
        "Cover nursery beds and vegetable seedlings with straw or plastic.",
    ],
    "high": [
        "Frost very likely — irrigate fields tonight and light smoke fires upwind if practised locally.",
        "Cover all nursery beds; harvest mature vegetables before dawn.",
        "Move livestock and potted plants under shelter.",
    ],
}
