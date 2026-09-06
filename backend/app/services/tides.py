"""Estimated tide model (05 §Formulas → Tides).

Deterministic harmonic approximation — **never** an observation. Everything it produces carries
`"source": "estimated"` and the `tides.disclaimer` i18n key. Real tide tables come from INCOIS /
the Survey of India; wire them in behind this same interface when available.
"""

from __future__ import annotations

import math
from datetime import datetime, timedelta
from typing import Any

from app.core.timeutil import UTC, iso

PERIOD_H = 12.4206012
SYNODIC_MONTH_DAYS = 29.530588853
NEW_MOON_REF = datetime(2000, 1, 6, 18, 14, tzinfo=UTC)
T0 = datetime(2000, 1, 1, 0, 0, tzinfo=UTC)

#: Mean tidal amplitude (m) by coastal state — 05.
STATE_AMPLITUDE: dict[str, float] = {
    "gujarat": 3.0,
    "maharashtra": 1.8,
    "goa": 1.1,
    "karnataka": 0.9,
    "kerala": 0.6,
    "tamil nadu": 0.6,
    "puducherry": 0.6,
    "andhra pradesh": 0.9,
    "odisha": 1.4,
    "west bengal": 2.2,
    "andaman": 1.2,
    "andaman and nicobar": 1.2,
    "andaman and nicobar islands": 1.2,
    "lakshadweep": 0.8,
}
DEFAULT_AMPLITUDE = 1.0


def amplitude_for_state(state: str | None) -> float:
    if not state:
        return DEFAULT_AMPLITUDE
    key = state.strip().lower()
    if key in STATE_AMPLITUDE:
        return STATE_AMPLITUDE[key]
    for name, amp in STATE_AMPLITUDE.items():
        if name in key or key in name:
            return amp
    return DEFAULT_AMPLITUDE


def days_since_new_moon(t: datetime) -> float:
    delta_days = (t.astimezone(UTC) - NEW_MOON_REF).total_seconds() / 86400.0
    return delta_days % SYNODIC_MONTH_DAYS


def spring_factor(t: datetime) -> float:
    return 0.7 + 0.3 * abs(math.cos(2 * math.pi * days_since_new_moon(t) / 14.765294))


def height_m(t: datetime, lon: float, amplitude: float) -> float:
    phi = 2 * math.pi * (lon / 360.0)
    hours = (t.astimezone(UTC) - T0).total_seconds() / 3600.0
    return amplitude * math.cos(2 * math.pi * hours / PERIOD_H + phi)


def build(
    *,
    lat: float,
    lon: float,
    state: str | None,
    now: datetime,
    hours: int = 30,
    step_minutes: int = 5,
) -> dict[str, Any]:
    """Sample 5-min steps for 30 h; local extrema are the high/low water events."""
    base_amp = amplitude_for_state(state)
    amp_now = base_amp * spring_factor(now)

    samples: list[tuple[datetime, float]] = []
    steps = int(hours * 60 / step_minutes) + 1
    for i in range(steps):
        t = now + timedelta(minutes=i * step_minutes)
        a = base_amp * spring_factor(t)
        samples.append((t, height_m(t, lon, a)))

    events: list[dict[str, Any]] = []
    for i in range(1, len(samples) - 1):
        prev_h, cur_h, next_h = samples[i - 1][1], samples[i][1], samples[i + 1][1]
        if cur_h >= prev_h and cur_h >= next_h and not (cur_h == prev_h == next_h):
            events.append(
                {"time": iso(samples[i][0]), "type": "high", "height_m": round(cur_h, 2)}
            )
        elif cur_h <= prev_h and cur_h <= next_h and not (cur_h == prev_h == next_h):
            events.append(
                {"time": iso(samples[i][0]), "type": "low", "height_m": round(cur_h, 2)}
            )

    # De-duplicate extrema found on adjacent samples (flat tops).
    deduped: list[dict[str, Any]] = []
    for ev in events:
        if deduped and deduped[-1]["type"] == ev["type"]:
            continue
        deduped.append(ev)

    now_h = height_m(now, lon, amp_now)
    later = height_m(now + timedelta(minutes=step_minutes), lon, amp_now)
    trend = "rising" if later > now_h else "falling"

    return {
        "events": deduped,
        "now_height_m": round(now_h, 2),
        "trend": trend,
        "next": deduped[0] if deduped else None,
        "amplitude_m": round(amp_now, 2),
        "source": "estimated",
        "disclaimer_key": "tides.disclaimer",
        "disclaimer": (
            "Estimated from a simplified harmonic model — not an official tide table. "
            "Check INCOIS / Survey of India before relying on it."
        ),
    }
