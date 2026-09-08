"""CPCB National AQI (05 §Formulas).

Sub-index per pollutant by linear interpolation inside its band; AQI = max sub-index;
dominant pollutant = argmax. Open-Meteo reports CO in µg/m³ — CPCB uses mg/m³.
"""

from __future__ import annotations

from typing import Any

CATEGORIES = ("Good", "Satisfactory", "Moderate", "Poor", "Very Poor", "Severe")

#: AQI band bounds, aligned with the concentration bands below.
AQI_BANDS: list[tuple[float, float]] = [
    (0, 50),
    (51, 100),
    (101, 200),
    (201, 300),
    (301, 400),
    (401, 500),
]

#: Concentration breakpoints (05 table). The Severe band's upper bound is the CPCB
#: continuation used to keep the interpolation finite (AQI is clamped at 500 anyway).
BREAKPOINTS: dict[str, list[tuple[float, float]]] = {
    "pm2_5": [(0, 30), (31, 60), (61, 90), (91, 120), (121, 250), (250, 380)],
    "pm10": [(0, 50), (51, 100), (101, 250), (251, 350), (351, 430), (430, 510)],
    "no2": [(0, 40), (41, 80), (81, 180), (181, 280), (281, 400), (400, 520)],
    "o3": [(0, 50), (51, 100), (101, 168), (169, 208), (209, 748), (748, 1000)],
    "so2": [(0, 40), (41, 80), (81, 380), (381, 800), (801, 1600), (1600, 2620)],
    "co": [(0, 1.0), (1.1, 2.0), (2.1, 10), (10.1, 17), (17.1, 34), (34, 51)],
}

POLLUTANT_LABEL = {
    "pm2_5": "PM2.5",
    "pm10": "PM10",
    "no2": "NO2",
    "o3": "O3",
    "so2": "SO2",
    "co": "CO",
}

#: Display label → the snapshot/i18n key it came from ("PM2.5" → "pm2_5").
POLLUTANT_KEY = {label: key for key, label in POLLUTANT_LABEL.items()}


def sub_index(pollutant: str, value: float | None) -> float | None:
    """CPCB sub-index for one pollutant. `co` must already be in mg/m³."""
    if value is None:
        return None
    bands = BREAKPOINTS.get(pollutant)
    if not bands:
        return None
    c = max(0.0, float(value))
    for (blo, bhi), (ilo, ihi) in zip(bands, AQI_BANDS, strict=True):
        if c <= bhi:
            if bhi == blo:
                return float(ilo)
            return round(ilo + (ihi - ilo) * (c - blo) / (bhi - blo), 2)
    # Above the last band: clamp at 500.
    return 500.0


def category_for(aqi: float | int | None) -> str | None:
    if aqi is None:
        return None
    a = float(aqi)
    if a <= 50:
        return "Good"
    if a <= 100:
        return "Satisfactory"
    if a <= 200:
        return "Moderate"
    if a <= 300:
        return "Poor"
    if a <= 400:
        return "Very Poor"
    return "Severe"


def co_ugm3_to_mgm3(value: float | None) -> float | None:
    return None if value is None else round(float(value) / 1000.0, 4)


def compute(
    *,
    pm2_5: float | None = None,
    pm10: float | None = None,
    no2: float | None = None,
    o3: float | None = None,
    so2: float | None = None,
    co_mg: float | None = None,
) -> dict[str, Any]:
    """Return `{aqi, category, dominant_pollutant, sub_indices}`."""
    values = {"pm2_5": pm2_5, "pm10": pm10, "no2": no2, "o3": o3, "so2": so2, "co": co_mg}
    subs = {k: sub_index(k, v) for k, v in values.items()}
    present = {k: v for k, v in subs.items() if v is not None}
    if not present:
        return {"aqi": None, "category": None, "dominant_pollutant": None, "sub_indices": {}}
    dominant = max(present, key=lambda k: present[k])
    aqi = min(500, int(round(present[dominant])))
    return {
        "aqi": aqi,
        "category": category_for(aqi),
        "dominant_pollutant": POLLUTANT_LABEL[dominant],
        "sub_indices": {k: round(v, 1) for k, v in present.items()},
    }


#: Urgency contribution per category (02 §7).
URGENCY = {
    "Good": 0.0,
    "Satisfactory": 0.0,
    "Moderate": 0.3,
    "Poor": 0.55,
    "Very Poor": 0.75,
    "Severe": 0.95,
}

#: i18n keys for the CPCB health advisory shown on the AQI card.
ADVICE_KEY = {
    "Good": "advice.aqi.good",
    "Satisfactory": "advice.aqi.satisfactory",
    "Moderate": "advice.aqi.moderate",
    "Poor": "advice.aqi.poor",
    "Very Poor": "advice.aqi.very_poor",
    "Severe": "advice.aqi.severe",
}
