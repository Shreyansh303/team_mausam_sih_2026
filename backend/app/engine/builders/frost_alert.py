"""02 §26 frost_alert — overnight frost risk for the agriculture persona."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, num
from app.engine.context import Bundle, Context, UserProfile

ADVICE_KEYS = {
    "none": [],
    "low": ["advice.frost.watch", "advice.frost.cover"],
    "moderate": ["advice.frost.irrigate", "advice.frost.cover"],
    "high": ["advice.frost.irrigate", "advice.frost.cover", "advice.frost.shelter"],
}


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("frost")
    risk = block.get("risk") or "none"

    data = {
        "risk": risk,
        "tmin_c": block.get("tmin_c"),
        "expected_night": block.get("expected_night"),
        "wind_kph": block.get("wind_kph"),
        "cloud_pct": block.get("cloud_pct"),
        "warning": bool(block.get("warning")),
        "advice": [t(lang, k) for k in ADVICE_KEYS.get(risk, [])],
    }
    localized = t(lang, "frost.risk." + risk)
    return CardContent(
        data=data,
        subtitle=f"{localized} · {num(block.get('tmin_c'), 1)}°",
        headline=t(
            lang, "insight.frost_alert.headline", risk=localized, tmin=num(block.get("tmin_c"), 1)
        ),
        detail=(data["advice"][0] if data["advice"] else t(lang, "advice.frost.none")),
        icon="frost",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
