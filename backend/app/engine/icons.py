"""WMO code → the stable icon strings listed in 02 §Icons."""

from __future__ import annotations

#: 02 §Icons — the app maps these to Material/custom glyphs.
ICONS = frozenset(
    {
        "sun", "moon", "cloud", "partly_cloudy", "rain", "heavy_rain", "thunderstorm", "fog",
        "haze", "wind", "snow", "hail", "dust", "cyclone", "aqi", "mask", "uv", "humidity",
        "pollen", "run", "sunrise", "sunset", "heat", "wave", "tide", "water", "plane",
        "suitcase", "school", "umbrella", "soil", "sprout", "frost", "traffic", "eye", "storm",
        "calendar", "comfort", "warning", "radar", "pin",
    }
)

_BY_CODE: dict[int, str] = {
    0: "sun", 1: "sun", 2: "partly_cloudy", 3: "cloud",
    45: "fog", 48: "fog",
    51: "rain", 53: "rain", 55: "rain", 56: "rain", 57: "rain",
    61: "rain", 63: "rain", 65: "heavy_rain", 66: "rain", 67: "heavy_rain",
    71: "snow", 73: "snow", 75: "snow", 77: "snow",
    80: "rain", 81: "rain", 82: "heavy_rain",
    85: "snow", 86: "snow",
    95: "thunderstorm", 96: "hail", 99: "hail",
}

#: Hazard → icon, used by the warning and alert cards.
HAZARD_ICON: dict[str, str] = {
    "heavy_rain": "heavy_rain",
    "very_heavy_rain": "heavy_rain",
    "thunderstorm": "thunderstorm",
    "lightning": "storm",
    "squall": "wind",
    "hail": "hail",
    "heatwave": "heat",
    "cold_wave": "frost",
    "fog": "fog",
    "dust_storm": "dust",
    "cyclone": "cyclone",
    "strong_wind": "wind",
    "snow": "snow",
    "flood": "heavy_rain",
    "other": "warning",
}


def for_code(code: int | None, is_day: bool = True) -> str:
    """Weather icon for a WMO code; clear-sky codes flip to `moon` at night."""
    if code is None:
        return "cloud"
    icon = _BY_CODE.get(int(code), "cloud")
    if not is_day and icon == "sun":
        return "moon"
    return icon


def for_hazard(hazard: str | None) -> str:
    return HAZARD_ICON.get(hazard or "other", "warning")
