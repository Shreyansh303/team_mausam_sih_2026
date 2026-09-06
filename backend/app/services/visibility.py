"""Visibility categories and fog outlook (02 §29)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from app.services.util import next_hours

CATEGORIES = ("Excellent", "Good", "Moderate", "Poor", "Very Poor", "Dense fog")


def category(visibility_km: float | None) -> str:
    """Excellent ≥10 · Good ≥4 · Moderate ≥2 · Poor ≥1 · Very Poor ≥0.5 · else Dense fog."""
    if visibility_km is None:
        return "Good"
    v = float(visibility_km)
    if v >= 10:
        return "Excellent"
    if v >= 4:
        return "Good"
    if v >= 2:
        return "Moderate"
    if v >= 1:
        return "Poor"
    if v >= 0.5:
        return "Very Poor"
    return "Dense fog"


ADVICE_KEY = {
    "Excellent": "advice.visibility.excellent",
    "Good": "advice.visibility.good",
    "Moderate": "advice.visibility.moderate",
    "Poor": "advice.visibility.poor",
    "Very Poor": "advice.visibility.very_poor",
    "Dense fog": "advice.visibility.dense_fog",
}


def urgency(visibility_km: float | None) -> float:
    if visibility_km is None:
        return 0.0
    if visibility_km < 0.5:
        return 0.8
    if visibility_km < 2:
        return 0.5
    return 0.0


def build(
    *,
    visibility_km: float | None,
    hourly: list[dict[str, Any]],
    now: datetime,
    horizon_hours: int = 12,
) -> dict[str, Any]:
    """02 §29 `data`: visibility_km, category, fog_expected_hours[], advice."""
    fog_hours = [
        {"time": h["time"], "visibility_km": round(float(h["visibility_km"]), 2)}
        for h in next_hours(hourly, now, horizon_hours)
        if h.get("visibility_km") is not None and float(h["visibility_km"]) < 1.0
    ]
    cat = category(visibility_km)
    return {
        "visibility_km": None if visibility_km is None else round(float(visibility_km), 2),
        "category": cat,
        "fog_expected_hours": fog_hours,
        "advice_key": ADVICE_KEY[cat],
        "advice": _ADVICE_EN[cat],
        "urgency": urgency(visibility_km),
    }


_ADVICE_EN = {
    "Excellent": "Clear all round — no visibility concerns.",
    "Good": "Visibility is fine for driving.",
    "Moderate": "Slight haze — keep headlights on outside town.",
    "Poor": "Reduced visibility — slow down and use low beams.",
    "Very Poor": "Very poor visibility — avoid overtaking, use fog lamps.",
    "Dense fog": "Dense fog — travel only if necessary, use hazard lights at a crawl.",
}
