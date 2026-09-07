"""02 §23 rain_alert — when the rain starts, how hard, and the 12-hour trace."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, hhmm, num
from app.engine.context import Bundle, Context, UserProfile

HOURS = 12
LITE_HOURS = 6


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("rain")
    intensity = block.get("intensity") or "light"
    hourly = list(block.get("hourly") or [])[: LITE_HOURS if ctx.lite else HOURS]

    data = {
        "next_rain_start": block.get("next_rain_start"),
        "next_rain_end": block.get("next_rain_end"),
        "peak_prob_pct": block.get("peak_prob_pct"),
        "peak_time": block.get("peak_time"),
        "expected_mm": block.get("expected_mm"),
        "intensity": intensity,
        "hourly": hourly,
        "warning": bool(block.get("warning")),
    }
    localized = t(lang, "rain.intensity." + intensity)
    start = block.get("next_rain_start")
    if start:
        headline = t(lang, "insight.rain_alert.headline", time=hhmm(start))
    else:
        headline = t(lang, "insight.rain_alert.none")
    return CardContent(
        data=data,
        subtitle=f"{num(block.get('peak_prob_pct'))}% · {localized}",
        headline=headline,
        detail=t(
            lang,
            "insight.rain_alert.detail",
            prob=num(block.get("peak_prob_pct")),
            peak=hhmm(block.get("peak_time")),
            mm=num(block.get("expected_mm"), 1),
        ),
        icon="umbrella",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
