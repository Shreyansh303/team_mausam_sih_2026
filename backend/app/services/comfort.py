"""Dew point (Magnus), NWS heat index, humidity bands and the comfort index (02 §10/15/33)."""

from __future__ import annotations

import math
from typing import Any

# ---------------------------------------------------------------- dew point


def dew_point_c(temp_c: float | None, rh_pct: float | None) -> float | None:
    """Magnus: γ = ln(RH/100) + 17.625·T/(243.04+T); Td = 243.04·γ/(17.625−γ)."""
    if temp_c is None or rh_pct is None:
        return None
    rh = max(1.0, min(100.0, float(rh_pct)))
    t = float(temp_c)
    gamma = math.log(rh / 100.0) + (17.625 * t) / (243.04 + t)
    return round(243.04 * gamma / (17.625 - gamma), 1)


# ---------------------------------------------------------------- heat index


def c_to_f(c: float) -> float:
    return c * 9.0 / 5.0 + 32.0


def f_to_c(f: float) -> float:
    return (f - 32.0) * 5.0 / 9.0


def heat_index_c(temp_c: float | None, rh_pct: float | None) -> float | None:
    """NWS Rothfusz heat index with the two NWS adjustments, returned in °C."""
    if temp_c is None or rh_pct is None:
        return None
    t = c_to_f(float(temp_c))
    r = max(0.0, min(100.0, float(rh_pct)))
    if t < 80.0:
        hi = 0.5 * (t + 61.0 + (t - 68.0) * 1.2 + r * 0.094)
        return round(f_to_c(hi), 1)
    hi = (
        -42.379
        + 2.04901523 * t
        + 10.14333127 * r
        - 0.22475541 * t * r
        - 0.00683783 * t * t
        - 0.05481717 * r * r
        + 0.00122874 * t * t * r
        + 0.00085282 * t * r * r
        - 0.00000199 * t * t * r * r
    )
    if r < 13.0 and 80.0 <= t <= 112.0:
        hi -= ((13.0 - r) / 4.0) * math.sqrt((17.0 - abs(t - 95.0)) / 17.0)
    elif r > 85.0 and 80.0 <= t <= 87.0:
        hi += ((r - 85.0) / 10.0) * ((87.0 - t) / 5.0)
    return round(f_to_c(hi), 1)


HEAT_LEVELS = ("caution", "extreme_caution", "danger", "extreme_danger")


def heat_level(hi_c: float | None) -> str | None:
    """02 §15: 27–32 caution · 32–41 extreme_caution · 41–54 danger · >54 extreme_danger."""
    if hi_c is None:
        return None
    if hi_c < 27:
        return None
    if hi_c < 32:
        return "caution"
    if hi_c < 41:
        return "extreme_caution"
    if hi_c <= 54:
        return "danger"
    return "extreme_danger"


HEAT_URGENCY = {
    "caution": 0.4,
    "extreme_caution": 0.6,
    "danger": 0.8,
    "extreme_danger": 0.95,
}


# ---------------------------------------------------------------- humidity


def humidity_category(dew_point: float | None, humidity_pct: float | None) -> str:
    """02 §10 bands by dew point; humidity < 25 % forces Dry."""
    if humidity_pct is not None and float(humidity_pct) < 25:
        return "Dry"
    if dew_point is None:
        return "Comfortable"
    d = float(dew_point)
    if d < 10:
        return "Dry"
    if d < 16:
        return "Comfortable"
    if d <= 21:
        return "Humid"
    return "Oppressive"


def trend_of(series: list[float | None]) -> str:
    """rising | steady | falling from the first vs last valid value of a short series."""
    vals = [v for v in series if v is not None]
    if len(vals) < 2:
        return "steady"
    delta = float(vals[-1]) - float(vals[0])
    if delta > 2:
        return "rising"
    if delta < -2:
        return "falling"
    return "steady"


# ---------------------------------------------------------------- comfort index


def comfort_index(
    feels_like_c: float | None,
    humidity_pct: float | None,
    wind_kph: float | None,
    uv: float | None,
    precip_prob_pct: float | None,
) -> int:
    """02 §33 formula, clamped 0..100."""
    fl = 24.0 if feels_like_c is None else float(feels_like_c)
    h = 50.0 if humidity_pct is None else float(humidity_pct)
    w = 0.0 if wind_kph is None else float(wind_kph)
    u = 0.0 if uv is None else float(uv)
    p = 0.0 if precip_prob_pct is None else float(precip_prob_pct)
    idx = (
        100.0
        - abs(fl - 24.0) * 3.0
        - max(0.0, h - 60.0) * 0.8
        - max(0.0, 30.0 - h) * 0.5
        - max(0.0, w - 20.0) * 0.8
        - max(0.0, u - 6.0) * 3.0
        - p * 0.3
    )
    return int(round(max(0.0, min(100.0, idx))))


def comfort_category(index: int) -> str:
    if index < 40:
        return "Uncomfortable"
    if index < 60:
        return "Fair"
    if index < 80:
        return "Comfortable"
    return "Ideal"


# ---------------------------------------------------------------- wind / UV


BEAUFORT_UPPER_KPH = [1, 5, 11, 19, 28, 38, 49, 61, 74, 88, 102, 117]
BEAUFORT_TEXT = [
    "Calm",
    "Light air",
    "Light breeze",
    "Gentle breeze",
    "Moderate breeze",
    "Fresh breeze",
    "Strong breeze",
    "Near gale",
    "Gale",
    "Strong gale",
    "Storm",
    "Violent storm",
    "Hurricane",
]


def beaufort(speed_kph: float | None) -> int:
    """05 §Formulas: upper bounds 1,5,11,19,28,38,49,61,74,88,102,117, else 12."""
    if speed_kph is None:
        return 0
    s = float(speed_kph)
    for i, upper in enumerate(BEAUFORT_UPPER_KPH):
        if s <= upper:
            return i
    return 12


def beaufort_text(force: int) -> str:
    return BEAUFORT_TEXT[max(0, min(12, force))]


UV_BANDS = ((2.9, "Low"), (5.9, "Moderate"), (7.9, "High"), (10.9, "Very High"))


def uv_category(uv: float | None) -> str:
    """WHO bands 0–2 / 3–5 / 6–7 / 8–10 / 11+."""
    if uv is None:
        return "Low"
    u = float(uv)
    for upper, name in UV_BANDS:
        if u <= upper:
            return name
    return "Extreme"


def safe_exposure_min(uv: float | None, skin_type: int = 3) -> int:
    """Rough Fitzpatrick-III minutes to erythema: 200 / (UV · 3), clamped."""
    if uv is None or float(uv) <= 0:
        return 240
    return int(max(5, min(240, round(200.0 / (float(uv) * 3.0)))))


def summarize(**kw: Any) -> dict[str, Any]:  # pragma: no cover - convenience
    return dict(kw)
