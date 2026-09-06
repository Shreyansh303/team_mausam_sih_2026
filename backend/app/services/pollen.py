"""Pollen: Open-Meteo when it reports values, otherwise the monthly estimator (05 §Formulas).

Open-Meteo's pollen fields are Europe-only (CAMS) and come back null for Indian coordinates —
verified against the recorded fixtures in tests/fixtures/. The estimator is therefore the normal
path for India and always carries `"source": "estimated"`.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

# Monthly base index 0–4 (Jan..Dec) — 05.
TREE_BASE = [1, 3, 3, 3, 2, 1, 0, 0, 1, 2, 1, 1]
GRASS_BASE = [1, 2, 3, 3, 2, 1, 1, 1, 2, 2, 2, 1]
WEED_BASE = [1, 1, 1, 1, 1, 1, 1, 2, 3, 3, 2, 1]

LEVELS = ("Low", "Low", "Moderate", "High", "Very High")

#: Open-Meteo pollen fields (grains/m³) → our tree/grass/weed buckets.
OM_TREE = ("alder_pollen", "birch_pollen", "olive_pollen")
OM_GRASS = ("grass_pollen",)
OM_WEED = ("mugwort_pollen", "ragweed_pollen")

#: grains/m³ → 0–4 index thresholds (CAMS-style low/moderate/high/very-high bands).
_INDEX_BREAKS = (1.0, 10.0, 30.0, 80.0)


def level_for(index: int) -> str:
    return LEVELS[max(0, min(4, index))]


def _grains_to_index(value: float | None) -> int | None:
    if value is None:
        return None
    v = float(value)
    idx = 0
    for br in _INDEX_BREAKS:
        if v >= br:
            idx += 1
    return min(4, idx)


def from_open_meteo(current: dict[str, Any] | None) -> dict[str, Any] | None:
    """Return the measured pollen block, or None when every field is null (India)."""
    if not current:
        return None
    buckets: dict[str, int] = {}
    for bucket, fields in (("tree", OM_TREE), ("grass", OM_GRASS), ("weed", OM_WEED)):
        vals = [current.get(f) for f in fields]
        vals = [v for v in vals if v is not None]
        if not vals:
            continue
        buckets[bucket] = max(_grains_to_index(v) or 0 for v in vals)
    if not buckets:
        return None
    index = max(buckets.values())
    dominant = max(buckets, key=lambda k: buckets[k])
    return {
        "index": index,
        "level": level_for(index),
        "dominant": dominant,
        "by_type": {k: buckets.get(k, 0) for k in ("tree", "grass", "weed")},
        "source": "open-meteo",
    }


def estimate(
    *,
    now: datetime,
    rain_last_6h_mm: float | None = None,
    humidity_pct: float | None = None,
    wind_kph: float | None = None,
) -> dict[str, Any]:
    """05 §Pollen (estimated): monthly base ±1 for rain / humidity / wind, clamped 0–4."""
    m = now.month - 1
    adj = 0
    if (rain_last_6h_mm or 0) > 0 or (humidity_pct is not None and humidity_pct > 85):
        adj -= 1
    if (wind_kph is not None and wind_kph > 20) and (
        humidity_pct is not None and humidity_pct < 50
    ):
        adj += 1
    by_type = {
        "tree": max(0, min(4, TREE_BASE[m] + adj)),
        "grass": max(0, min(4, GRASS_BASE[m] + adj)),
        "weed": max(0, min(4, WEED_BASE[m] + adj)),
    }
    index = max(by_type.values())
    dominant = max(by_type, key=lambda k: by_type[k])
    return {
        "index": index,
        "level": level_for(index),
        "dominant": dominant,
        "by_type": by_type,
        "source": "estimated",
    }


ADVICE_KEY = {
    "Low": "advice.pollen.low",
    "Moderate": "advice.pollen.moderate",
    "High": "advice.pollen.high",
    "Very High": "advice.pollen.very_high",
}


def urgency(level: str) -> float:
    if level == "High":
        return 0.4
    if level in ("Very High", "Extreme"):
        return 0.6
    return 0.0
