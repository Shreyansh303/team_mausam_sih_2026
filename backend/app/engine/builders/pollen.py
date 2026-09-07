"""02 §8 pollen — Open-Meteo when it reports values, otherwise the monthly estimate."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, key_of
from app.engine.context import Bundle, Context, UserProfile


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    pollen = bundle.snap.get("pollen") or {}
    level = pollen.get("level") or "Low"
    lkey = key_of(level)
    dominant = pollen.get("dominant") or "tree"
    source = pollen.get("source", "estimated")

    data = {
        "index": pollen.get("index", 0),
        "level": level,
        "dominant": dominant,
        "by_type": pollen.get("by_type") or {},
        "advice": t(lang, "advice.pollen." + lkey),
        "source": source,
    }
    localized = t(lang, "pollen.level." + lkey)
    return CardContent(
        data=data,
        subtitle=localized,
        headline=t(lang, "insight.pollen.headline", level=localized),
        detail=t(lang, "insight.pollen.detail", dominant=t(lang, "pollen.type." + dominant)),
        icon="pollen",
        source=source,
        estimated=source == "estimated",
    )
