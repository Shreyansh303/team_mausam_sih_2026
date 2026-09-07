"""02 §15 heat_alert — NWS heat-index level with IMD-style advice."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, hhmm, num
from app.engine.context import Bundle, Context, UserProfile

ADVICE_KEYS = {
    "caution": ["advice.heat.hydrate"],
    "extreme_caution": ["advice.heat.hydrate", "advice.heat.avoid_sun", "advice.heat.cotton"],
    "danger": [
        "advice.heat.hydrate",
        "advice.heat.avoid_sun",
        "advice.heat.cotton",
        "advice.heat.stop_work",
    ],
    "extreme_danger": [
        "advice.heat.hydrate",
        "advice.heat.avoid_sun",
        "advice.heat.cotton",
        "advice.heat.stop_work",
    ],
}


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("heat")
    level = block.get("level") or "caution"
    localized = t(lang, f"heat.level.{level}")

    data = {
        "feels_like_c": block.get("feels_like_c"),
        "temp_c": block.get("temp_c"),
        "heat_index_c": block.get("heat_index_c"),
        "level": level,
        "peak_time": block.get("peak_time"),
        "warning": bool(block.get("warning")),
        "advice": [t(lang, k) for k in ADVICE_KEYS.get(level, ["advice.heat.hydrate"])],
    }
    return CardContent(
        data=data,
        subtitle=f"{num(block.get('feels_like_c'))}° · {localized}",
        headline=t(
            lang,
            "insight.heat_alert.headline",
            value=num(block.get("heat_index_c")),
            level=localized,
        ),
        detail=t(lang, "insight.heat_alert.detail", time=hhmm(block.get("peak_time"))),
        icon="heat",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
