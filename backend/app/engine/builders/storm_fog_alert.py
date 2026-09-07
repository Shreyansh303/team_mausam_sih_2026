"""02 §30 storm_fog_alert — thunderstorm / fog / squall / dust-storm / hail heads-up."""

from __future__ import annotations

from app.core.i18n import t
from app.engine import icons
from app.engine.builders.base import CardContent, hhmm
from app.engine.context import Bundle, Context, UserProfile

ADVICE_KEYS = {
    "thunderstorm": ["advice.storm.shelter", "advice.storm.unplug", "advice.storm.avoid_trees"],
    "lightning": ["advice.storm.shelter", "advice.storm.avoid_trees"],
    "fog": ["advice.fog.slow", "advice.fog.lights"],
    "squall": ["advice.storm.shelter", "advice.wind.secure"],
    "dust_storm": ["advice.dust.mask", "advice.dust.windows"],
    "hail": ["advice.storm.shelter", "advice.hail.cover"],
}


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.derived.get("storm_fog") or {}
    hazard = block.get("hazard") or "thunderstorm"
    level = block.get("level") or "watch"
    window = block.get("window") or {}

    data = {
        "hazard": hazard,
        "level": level,
        "window": {"start": window.get("start"), "end": window.get("end")},
        "detail": block.get("detail", ""),
        "warning": bool(block.get("warning")),
        "advice": [t(lang, k) for k in ADVICE_KEYS.get(hazard, ["advice.storm.shelter"])],
    }
    localized_hazard = t(lang, "hazard." + hazard)
    localized_level = t(lang, "storm.level." + level)
    return CardContent(
        data=data,
        subtitle=f"{localized_hazard} · {localized_level}",
        headline=t(
            lang,
            "insight.storm_fog_alert.headline",
            hazard=localized_hazard,
            level=localized_level,
        ),
        detail=t(
            lang,
            "insight.storm_fog_alert.detail",
            start=hhmm(window.get("start")),
            end=hhmm(window.get("end")),
        ),
        icon=icons.for_hazard(hazard),
        source="imd" if block.get("warning") else "open-meteo",
    )
