"""02 §9 uv_index — WHO bands, today's peak and safe exposure time."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, hhmm, key_of, num
from app.engine.context import Bundle, Context, UserProfile

LITE_HOURS = 12


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    uv = bundle.block("uv")
    category = uv.get("category") or "Low"
    ckey = key_of(category)
    hourly = list(uv.get("hourly") or [])
    if ctx.lite:
        hourly = hourly[:LITE_HOURS]

    data = {
        "uv_now": uv.get("uv_now"),
        "uv_max_today": uv.get("uv_max_today"),
        "uv_max_time": uv.get("uv_max_time"),
        "category": category,
        "safe_exposure_min": uv.get("safe_exposure_min"),
        "hourly": hourly,
    }
    localized = t(lang, "uv.category." + ckey)
    return CardContent(
        data=data,
        subtitle=f"{num(uv.get('uv_now'), 1)} · {localized}",
        headline=t(
            lang, "insight.uv_index.headline", value=num(uv.get("uv_now"), 1), category=localized
        ),
        detail=t(
            lang,
            "insight.uv_index.detail",
            max=num(uv.get("uv_max_today"), 1),
            time=hhmm(uv.get("uv_max_time")),
            minutes=num(uv.get("safe_exposure_min")),
        ),
        icon="uv",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
