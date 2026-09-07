"""02 §10 humidity — dew-point bands, trend and advice."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, key_of, num
from app.engine.context import Bundle, Context, UserProfile


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("humidity")
    category = block.get("category") or "Comfortable"
    ckey = key_of(category)
    trend = block.get("trend") or "steady"

    data = {
        "humidity_pct": block.get("humidity_pct"),
        "dew_point_c": block.get("dew_point_c"),
        "category": category,
        "trend": trend,
        "advice": t(lang, "advice.humidity." + ckey),
    }
    localized = t(lang, "humidity.category." + ckey)
    return CardContent(
        data=data,
        subtitle=f"{num(block.get('humidity_pct'))}% · {localized}",
        headline=t(
            lang,
            "insight.humidity.headline",
            humidity=num(block.get("humidity_pct")),
            category=localized,
        ),
        detail=t(
            lang,
            "insight.humidity.detail",
            dew=num(block.get("dew_point_c"), 1),
            trend=t(lang, "trend." + trend),
        ),
        icon="humidity",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
