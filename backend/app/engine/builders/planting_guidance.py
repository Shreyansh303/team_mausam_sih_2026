"""02 §27 planting_guidance — crop calendar for the zone, enriched with soil and rainfall."""

from __future__ import annotations

import re

from app.core.i18n import resolve_all, t
from app.engine.builders.base import CardContent
from app.engine.context import Bundle, Context, UserProfile

MAX_CROPS = 4


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("planting")
    season = block.get("season") or "kharif"
    zone = block.get("zone") or "north"
    crops = [_localized_crop(lang, c) for c in (block.get("crops") or [])][:MAX_CROPS]

    data = {
        "season": season,
        "zone": zone,
        "month": block.get("month") or ctx.now.month,
        "crops": crops,
        "tips": resolve_all(lang, block.get("tips")),
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


def _localized_crop(lang: str, crop: dict) -> dict:
    """Crop names and their stage action come out of `planting_calendar.json` in English;
    both resolve through the catalog, falling back to the calendar's own wording."""
    raw_name = str(crop.get("name") or "")
    stage = str(crop.get("stage") or "grow")
    name_key = "crop." + re.sub(r"[^a-z0-9]+", "_", raw_name.lower()).strip("_")
    name = t(lang, name_key)
    if name == name_key:
        name = raw_name
    action = t(lang, "planting.action." + stage, crop=name)
    if action == "planting.action." + stage:
        action = crop.get("action") or ""
    return {"name": name, "stage": stage, "action": action}
