"""02 §27 planting_guidance — crop calendar for the zone, enriched with soil and rainfall."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent
from app.engine.context import Bundle, Context, UserProfile

MAX_CROPS = 4


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("planting")
    season = block.get("season") or "kharif"
    zone = block.get("zone") or "north"
    crops = [
        {
            "name": c.get("name"),
            "stage": c.get("stage"),
            "action": c.get("action"),
        }
        for c in (block.get("crops") or [])
    ][:MAX_CROPS]

    data = {
        "season": season,
        "zone": zone,
        "month": block.get("month") or ctx.now.month,
        "crops": crops,
        "tips": list(block.get("tips") or []),
    }
    localized_season = t(lang, "season.crop." + season)
    localized_zone = t(lang, "zone." + zone)
    first = crops[0] if crops else {}
    return CardContent(
        data=data,
        subtitle=f"{localized_season} · {localized_zone}",
        headline=t(
            lang,
            "insight.planting_guidance.headline",
            season=localized_season,
            zone=localized_zone,
        ),
        detail=(
            t(
                lang,
                "insight.planting_guidance.detail",
                crop=first.get("name", ""),
                stage=t(lang, "planting.stage." + (first.get("stage") or "grow")),
            )
            if first
            else (data["tips"][0] if data["tips"] else "")
        ),
        icon="sprout",
        source="estimated",
        estimated=True,
    )
