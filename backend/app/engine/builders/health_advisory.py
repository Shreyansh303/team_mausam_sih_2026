"""02 §11 health_advisory — one composed list from AQI, UV, humidity, heat and pollen.

`items_for` is shared with `catalog.gate_health_advisory`: the card only exists when at least
one contributing item rises above `info`.
"""

from __future__ import annotations

from typing import Any

from app.core.i18n import t
from app.engine.builders.base import CardContent, key_of, num
from app.engine.context import Bundle, Context, UserProfile

AQI_LEVEL = {
    "Good": "info",
    "Satisfactory": "info",
    "Moderate": "advisory",
    "Poor": "advisory",
    "Very Poor": "warning",
    "Severe": "warning",
}
UV_LEVEL = {
    "Low": "info",
    "Moderate": "info",
    "High": "advisory",
    "Very High": "warning",
    "Extreme": "warning",
}
HUMIDITY_LEVEL = {
    "Comfortable": "info",
    "Humid": "info",
    "Dry": "advisory",
    "Oppressive": "advisory",
}
HEAT_LEVEL = {
    "caution": "advisory",
    "extreme_caution": "advisory",
    "danger": "warning",
    "extreme_danger": "warning",
}
POLLEN_LEVEL = {
    "Low": "info",
    "Moderate": "info",
    "High": "advisory",
    "Very High": "warning",
    "Extreme": "warning",
}


def items_for(bundle: Bundle, ctx: Context) -> list[dict[str, Any]]:
    """Every contributing item, `info` ones included — the gate filters on the level."""
    lang = ctx.lang
    out: list[dict[str, Any]] = []

    air = bundle.air
    if air:
        cat = air.get("category") or "Good"
        out.append(
            {
                "icon": "mask",
                "title": t(
                    lang, "health.aqi.title", category=t(lang, "aqi.category." + key_of(cat))
                ),
                "detail": t(lang, "advice.aqi." + key_of(cat)),
                "level": AQI_LEVEL.get(cat, "info"),
            }
        )

    uv = bundle.block("uv")
    if uv:
        cat = uv.get("category") or "Low"
        out.append(
            {
                "icon": "uv",
                "title": t(lang, "health.uv.title", value=num(uv.get("uv_now"), 1)),
                "detail": t(lang, "advice.uv." + key_of(cat)),
                "level": UV_LEVEL.get(cat, "info"),
            }
        )

    hum = bundle.block("humidity")
    if hum:
        cat = hum.get("category") or "Comfortable"
        out.append(
            {
                "icon": "humidity",
                "title": t(
                    lang,
                    "health.humidity.title",
                    category=t(lang, "humidity.category." + key_of(cat)),
                ),
                "detail": t(lang, "advice.humidity." + key_of(cat)),
                "level": HUMIDITY_LEVEL.get(cat, "info"),
            }
        )

    heat = bundle.block("heat")
    level = heat.get("level")
    if level:
        out.append(
            {
                "icon": "heat",
                "title": t(lang, "health.heat.title", level=t(lang, "heat.level." + level)),
                "detail": t(lang, "advice.heat.hydrate"),
                "level": HEAT_LEVEL.get(level, "info"),
            }
        )

    pollen = bundle.snap.get("pollen") or {}
    if pollen:
        plevel = pollen.get("level") or "Low"
        out.append(
            {
                "icon": "pollen",
                "title": t(
                    lang, "health.pollen.title", level=t(lang, "pollen.level." + key_of(plevel))
                ),
                "detail": t(lang, "advice.pollen." + key_of(plevel)),
                "level": POLLEN_LEVEL.get(plevel, "info"),
            }
        )
    return out


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    items = [i for i in items_for(bundle, ctx) if i["level"] != "info"]
    first = items[0] if items else {"title": "", "detail": "", "icon": "mask"}
    return CardContent(
        data={"items": items},
        subtitle=t(lang, "health_advisory.count", count=len(items)),
        headline=t(lang, "insight.health_advisory.headline", count=len(items)),
        detail=first.get("detail", ""),
        icon=first.get("icon", "mask"),
        source="mixed",
    )
