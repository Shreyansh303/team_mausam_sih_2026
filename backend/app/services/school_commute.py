"""School drop / pickup windows and verdicts (02 §22)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from app.core.i18n import token
from app.core.timeutil import iso, next_occurrence
from app.services.util import THUNDER_CODES, has_code, hours_between, vmax, vmin

WINDOWS: list[tuple[str, tuple[int, int], tuple[int, int]]] = [
    ("morning_drop", (7, 0), (9, 0)),
    ("afternoon_pickup", (13, 0), (16, 0)),
]

VERDICTS = ("good", "caution", "poor", "avoid")
_RANK = {v: i for i, v in enumerate(VERDICTS)}

URGENCY = {"good": 0.0, "caution": 0.4, "poor": 0.6, "avoid": 0.85}


def verdict_for(
    *,
    precip_prob_pct: float | None,
    visibility_km: float | None,
    feels_like_c: float | None,
    aqi_category: str | None,
    thunderstorm: bool,
    severe_warning: bool,
) -> tuple[str, list[dict[str, Any]]]:
    """Verdict plus its reasons as deferred translations (05 §i18n) — the card builder
    resolves them with the request language."""
    reasons: list[dict[str, Any]] = []
    if severe_warning:
        reasons.append(token("reason.severe_warning"))
    if thunderstorm:
        reasons.append(token("reason.thunderstorm"))
    if visibility_km is not None and visibility_km < 0.5:
        reasons.append(token("reason.visibility", km=f"{visibility_km:.1f}"))
    if reasons:
        return "avoid", reasons

    if precip_prob_pct is not None and precip_prob_pct >= 70:
        reasons.append(token("reason.rain_chance", pct=int(precip_prob_pct)))
    if visibility_km is not None and visibility_km < 1:
        reasons.append(token("reason.visibility", km=f"{visibility_km:.1f}"))
    if feels_like_c is not None and feels_like_c >= 42:
        reasons.append(token("reason.feels_like", temp=f"{feels_like_c:.0f}"))
    if aqi_category == "Severe":
        reasons.append(token("reason.aqi_severe"))
    if reasons:
        return "poor", reasons

    if precip_prob_pct is not None and precip_prob_pct >= 40:
        reasons.append(token("reason.rain_chance", pct=int(precip_prob_pct)))
    if aqi_category == "Very Poor":
        reasons.append(token("reason.aqi_very_poor"))
    if feels_like_c is not None and feels_like_c >= 38:
        reasons.append(token("reason.feels_like", temp=f"{feels_like_c:.0f}"))
    if visibility_km is not None and visibility_km < 2:
        reasons.append(token("reason.visibility", km=f"{visibility_km:.1f}"))
    if reasons:
        return "caution", reasons

    return "good", [token("reason.school.calm")]


def build(
    *,
    hourly: list[dict[str, Any]],
    now: datetime,
    aqi_category: str | None,
    aqi: int | None,
    severe_warning: bool = False,
) -> dict[str, Any]:
    out_windows: list[dict[str, Any]] = []
    for label, start_hm, end_hm in WINDOWS:
        start, end = next_occurrence(now, start_hm, end_hm)
        rows = hours_between(hourly, start, end)
        prob = vmax(rows, "precip_prob_pct")
        vis = vmin(rows, "visibility_km")
        feels = vmax(rows, "feels_like_c")
        temp = vmax(rows, "temp_c")
        thunder = has_code(rows, THUNDER_CODES)
        verdict, reasons = verdict_for(
            precip_prob_pct=prob,
            visibility_km=vis,
            feels_like_c=feels,
            aqi_category=aqi_category,
            thunderstorm=thunder,
            severe_warning=severe_warning,
        )
        out_windows.append(
            {
                "label": label,
                "start": iso(start),
                "end": iso(end),
                "verdict": verdict,
                "temp_c": temp,
                "precip_prob_pct": prob,
                "visibility_km": None if vis is None else round(vis, 2),
                "aqi": aqi,
                "reasons": reasons,
            }
        )

    overall = max((w["verdict"] for w in out_windows), key=lambda v: _RANK[v], default="good")
    morning_day = out_windows[0]["start"][:10] if out_windows else now.date().isoformat()
    is_school_day = datetime.fromisoformat(out_windows[0]["start"]).weekday() < 5 if out_windows else True

    return {
        "windows": out_windows,
        "overall_verdict": overall,
        "advice": _ADVICE[overall],
        "is_school_day": is_school_day,
        "date": morning_day,
        "urgency": URGENCY[overall],
    }


_ADVICE = {
    "good": "Normal school run — nothing special needed.",
    "caution": "Send a raincoat/water bottle and leave a few minutes early.",
    "poor": "Poor conditions — consider a covered ride and keep a mask handy.",
    "avoid": "Avoid the trip if you can; check for school closure messages.",
}
