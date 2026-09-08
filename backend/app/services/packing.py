"""Packing suggestions over the next N days (02 §21)."""

from __future__ import annotations

from typing import Any

from app.core.i18n import token
from app.services.util import SNOW_CODES, vmax, vmin

DEFAULT_DAYS = 3


def build(
    *,
    daily: list[dict[str, Any]],
    hourly: list[dict[str, Any]] | None = None,
    aqi_category: str | None = None,
    days: int = DEFAULT_DAYS,
) -> dict[str, Any]:
    """02 §21 rules.

    Returns `{days, items[{item_key, icon, reason}]}` for one location. `item_key` is an i18n
    key and `reason` a deferred translation (05 §i18n); the card builder resolves both into the
    `{item, icon, reason}` shape docs/02 publishes.
    """
    window = daily[:days]
    hours = (hourly or [])[: days * 24]
    items: list[dict[str, Any]] = []

    def add(item_key: str, icon: str, reason: dict[str, Any]) -> None:
        if all(i["item_key"] != item_key for i in items):
            items.append({"item_key": item_key, "icon": icon, "reason": reason})

    prob = vmax(window, "precip_prob_max_pct")
    if prob is not None and prob >= 40:
        add(
            "packing.item.raincoat",
            "umbrella",
            token("packing.reason.rain", pct=int(prob), days=days),
        )

    tmin = vmin(window, "tmin_c")
    if tmin is not None and tmin < 12:
        add("packing.item.warm_layers", "cloud",
            token("packing.reason.cold_nights", temp=f"{tmin:.0f}"))
    if tmin is not None and tmin < 5:
        add("packing.item.heavy_jacket", "snow",
            token("packing.reason.cold_nights", temp=f"{tmin:.0f}"))

    uvmax = vmax(window, "uv_index_max")
    if uvmax is not None and uvmax >= 8:
        add("packing.item.sunscreen_hat", "uv", token("packing.reason.uv", uv=f"{uvmax:.0f}"))

    hum = vmax(hours, "humidity_pct")
    if hum is not None and hum >= 80:
        add("packing.item.light_cotton", "humidity",
            token("packing.reason.humidity", pct=int(hum)))

    wind = vmax(window, "wind_max_kph")
    if wind is not None and wind >= 40:
        add("packing.item.windbreaker", "wind", token("packing.reason.wind", kph=int(wind)))

    if aqi_category in ("Poor", "Very Poor", "Severe"):
        add(
            "packing.item.n95_mask",
            "mask",
            token("packing.reason.aqi_" + aqi_category.lower().replace(" ", "_")),
        )

    codes = {int(d["condition_code"]) for d in window if d.get("condition_code") is not None}
    if codes & SNOW_CODES:
        add("packing.item.waterproof_boots", "snow", token("packing.reason.snow"))

    feels = vmax(window, "feels_like_max_c")
    if feels is not None and feels >= 38:
        add("packing.item.water_ors", "heat",
            token("packing.reason.feels_like", temp=f"{feels:.0f}"))

    return {"days": days, "items": items, "urgency": 0.1}
