"""Packing suggestions over the next N days (02 §21)."""

from __future__ import annotations

from typing import Any

from app.services.util import SNOW_CODES, vmax, vmin

DEFAULT_DAYS = 3


def build(
    *,
    daily: list[dict[str, Any]],
    hourly: list[dict[str, Any]] | None = None,
    aqi_category: str | None = None,
    days: int = DEFAULT_DAYS,
) -> dict[str, Any]:
    """02 §21 rules. Returns `{days, items[{item, icon, reason}]}` for one location."""
    window = daily[:days]
    hours = (hourly or [])[: days * 24]
    items: list[dict[str, str]] = []

    def add(item: str, icon: str, reason: str) -> None:
        if all(i["item"] != item for i in items):
            items.append({"item": item, "icon": icon, "reason": reason})

    prob = vmax(window, "precip_prob_max_pct")
    if prob is not None and prob >= 40:
        add("Raincoat / umbrella", "umbrella", f"Rain chance up to {int(prob)}% in {days} days")

    tmin = vmin(window, "tmin_c")
    if tmin is not None and tmin < 12:
        add("Warm layers", "cloud", f"Nights down to {tmin:.0f}°C")
    if tmin is not None and tmin < 5:
        add("Heavy jacket", "snow", f"Nights down to {tmin:.0f}°C")

    uvmax = vmax(window, "uv_index_max")
    if uvmax is not None and uvmax >= 8:
        add("Sunscreen & hat", "uv", f"UV index peaks at {uvmax:.0f}")

    hum = vmax(hours, "humidity_pct")
    if hum is not None and hum >= 80:
        add("Light cotton clothes", "humidity", f"Humidity up to {int(hum)}%")

    wind = vmax(window, "wind_max_kph")
    if wind is not None and wind >= 40:
        add("Windbreaker", "wind", f"Winds up to {int(wind)} km/h")

    if aqi_category in ("Poor", "Very Poor", "Severe"):
        add("N95 mask", "mask", f"Air quality {aqi_category}")

    codes = {int(d["condition_code"]) for d in window if d.get("condition_code") is not None}
    if codes & SNOW_CODES:
        add("Waterproof boots", "snow", "Snow expected")

    feels = vmax(window, "feels_like_max_c")
    if feels is not None and feels >= 38:
        add("Extra water / ORS", "heat", f"Feels like {feels:.0f}°C")

    return {"days": days, "items": items, "urgency": 0.1}
