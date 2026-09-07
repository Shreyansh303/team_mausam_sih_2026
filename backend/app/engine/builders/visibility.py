"""02 §29 visibility — current visibility band and the fog hours ahead."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, key_of, num
from app.engine.context import Bundle, Context, UserProfile

LITE_HOURS = 6


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("visibility")
    category = block.get("category") or "Excellent"
    ckey = key_of(category)
    fog_hours = list(block.get("fog_expected_hours") or [])
    if ctx.lite:
        fog_hours = fog_hours[:LITE_HOURS]

    data = {
        "visibility_km": block.get("visibility_km"),
        "category": category,
        "fog_expected_hours": fog_hours,
        "advice": t(lang, "advice.visibility." + ckey),
    }
    localized = t(lang, "visibility.category." + ckey)
    return CardContent(
        data=data,
        subtitle=f"{num(block.get('visibility_km'), 1)} km · {localized}",
        headline=t(
            lang,
            "insight.visibility.headline",
            value=num(block.get("visibility_km"), 1),
            category=localized,
        ),
        detail=str(data["advice"]),
        icon="eye" if not fog_hours else "fog",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
