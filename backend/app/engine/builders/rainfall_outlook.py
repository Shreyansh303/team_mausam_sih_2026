"""02 §25 rainfall_outlook — 24 h / 72 h / 7 d totals with the IMD daily bands."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, num
from app.engine.context import Bundle, Context, UserProfile


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("rainfall_outlook")
    mm72 = block.get("next_72h_mm") or 0
    rain_days = int(block.get("rain_days") or 0)
    advice_key = "advice.rainfall.hold" if mm72 >= 35 else "advice.rainfall.plan"

    data = {
        "next_24h_mm": block.get("next_24h_mm"),
        "next_72h_mm": block.get("next_72h_mm"),
        "next_7d_mm": block.get("next_7d_mm"),
        "daily": list(block.get("daily") or [])[:7],
        "rain_days": rain_days,
        "advice": t(lang, advice_key, mm=num(mm72)),
    }
    return CardContent(
        data=data,
        subtitle=f"{num(block.get('next_72h_mm'), 1)} mm / 72h",
        headline=t(
            lang,
            "insight.rainfall_outlook.headline",
            mm=num(block.get("next_72h_mm"), 1),
        ),
        detail=t(
            lang,
            "insight.rainfall_outlook.detail." + ("one" if rain_days == 1 else "other"),
            days=rain_days,
            mm=num(block.get("next_7d_mm"), 1),
        ),
        icon="heavy_rain",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
