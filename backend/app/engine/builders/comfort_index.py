"""02 §33 comfort_index — the event planner's headline number."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, key_of, num
from app.engine.context import Bundle, Context, UserProfile


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("comfort")
    index = block.get("index") or 0
    category = block.get("category") or "Fair"
    ckey = key_of(category)

    data = {
        "index": index,
        "category": category,
        "feels_like_c": block.get("feels_like_c"),
        "humidity_pct": block.get("humidity_pct"),
        "wind_kph": block.get("wind_kph"),
        "uv": block.get("uv"),
        "best_hours_today": list(block.get("best_hours_today") or [])[:2],
        "daily": list(block.get("daily") or [])[:7],
        "advice": t(lang, "advice.comfort." + ckey),
    }
    localized = t(lang, "comfort.category." + ckey)
    return CardContent(
        data=data,
        subtitle=f"{index}/100 · {localized}",
        headline=t(lang, "insight.comfort_index.headline", index=index, category=localized),
        detail=t(
            lang,
            "insight.comfort_index.detail",
            feels=num(block.get("feels_like_c")),
            humidity=num(block.get("humidity_pct")),
        ),
        icon="comfort",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
