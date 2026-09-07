"""02 §18 water_temp — sea-surface temperature band and wetsuit advice."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, key_of, num
from app.engine.context import Bundle, Context, UserProfile


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    sea = bundle.block("sea")
    category = sea.get("water_category") or "Pleasant"
    ckey = key_of(category)

    data = {
        "sst_c": sea.get("sst_c"),
        "category": category,
        "wetsuit_advice": t(lang, "advice.wetsuit." + ckey),
    }
    localized = t(lang, "water.category." + ckey)
    return CardContent(
        data=data,
        subtitle=f"{num(sea.get('sst_c'), 1)}° · {localized}",
        headline=t(
            lang,
            "insight.water_temp.headline",
            value=num(sea.get("sst_c"), 1),
            category=localized,
        ),
        detail=str(data["wetsuit_advice"]),
        icon="water",
        source=sea.get("source", "open-meteo"),
    )
