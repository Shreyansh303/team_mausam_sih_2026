"""Nowcast: IMD when available, otherwise derived from the next 3 hours (05 §Formulas)."""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from app.core import i18n
from app.core.timeutil import hhmm, iso, parse_any
from app.services.util import FOG_CODES, THUNDER_CODES, next_hours

RAIN_CODES = set(range(61, 83))  # 61–82 (rain / showers)
URGENCY = {"none": 0.0, "moderate": 0.5, "severe": 0.75}


def derive(*, hourly: list[dict[str, Any]], now: datetime, hours: int = 3) -> dict[str, Any]:
    rows = next_hours(hourly, now, hours)
    valid_till = now + timedelta(hours=hours)
    codes = {int(h["condition_code"]) for h in rows if h.get("condition_code") is not None}
    probs = [float(h["precip_prob_pct"]) for h in rows if h.get("precip_prob_pct") is not None]
    max_prob = max(probs) if probs else 0.0

    hazards: list[str] = []
    severity = "none"
    text = "No significant weather in next 3 hours"
    text_token = i18n.token("nowcast.text.none")

    if codes & THUNDER_CODES:
        severity = "severe"
        hazards.append("thunderstorm")
        text = "Thunderstorm likely"
        text_token = i18n.token("nowcast.text.thunderstorm")
    elif max_prob >= 60 or (codes & RAIN_CODES):
        severity = "moderate"
        hazards.append("rain")
        when = _first_rain_time(rows)
        text = f"Rain likely by {when}" if when else "Rain likely"
        text_token = (
            i18n.token("nowcast.text.rain_by", time=when)
            if when
            else i18n.token("nowcast.text.rain")
        )
    elif codes & FOG_CODES:
        severity = "moderate"
        hazards.append("fog")
        text = "Fog likely to persist"
        text_token = i18n.token("nowcast.text.fog")

    return {
        "issued_at": iso(now),
        "valid_till": iso(valid_till),
        # `text` is the English rendering; `text_token` is what the card builder localizes.
        "text": text,
        "text_token": text_token,
        "severity": severity,
        "hazards": hazards,
        "source": "derived",
        "urgency": URGENCY[severity],
    }


def _first_rain_time(rows: list[dict[str, Any]]) -> str | None:
    for h in rows:
        code = h.get("condition_code")
        prob = h.get("precip_prob_pct")
        if (code is not None and int(code) in RAIN_CODES) or (prob is not None and prob >= 60):
            try:
                return hhmm(parse_any(h["time"]))
            except (KeyError, ValueError):
                return None
    return None


def from_imd(parsed: dict[str, Any] | None, *, now: datetime, hours: int = 3) -> dict[str, Any] | None:
    """Wrap a parsed IMD nowcast into the Snapshot shape."""
    if not parsed or not parsed.get("text"):
        return None
    severity = parsed.get("severity") or "moderate"
    return {
        "issued_at": parsed.get("issued_at") or iso(now),
        "valid_till": parsed.get("valid_till") or iso(now + timedelta(hours=hours)),
        "text": parsed["text"],
        "severity": severity,
        "hazards": parsed.get("hazards") or [],
        "source": "imd",
        "urgency": URGENCY.get(severity, 0.5),
    }
