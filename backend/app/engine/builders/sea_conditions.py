"""02 §16 sea_conditions — Douglas sea state, surf rating and swim safety."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, key_of, num
from app.engine.context import Bundle, Context, UserProfile

LITE_HOURS = 12
HOURS = 24


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    sea = bundle.block("sea")
    state = sea.get("sea_state") or "Calm"
    skey = key_of(state)
    safe = bool(sea.get("safe_for_swimming"))
    hourly = [
        {"time": h.get("time"), "wave_height_m": h.get("wave_height_m")}
        for h in (sea.get("hourly") or [])
    ][: LITE_HOURS if ctx.lite else HOURS]

    data = {
        "sea_state": state,
        "wave_height_m": sea.get("wave_height_m"),
        "wave_period_s": sea.get("wave_period_s"),
        "wave_direction_deg": sea.get("wave_direction_deg"),
        "swell_height_m": sea.get("swell_height_m"),
        "current_kph": sea.get("current_kph"),
        "sst_c": sea.get("sst_c"),
        "safe_for_swimming": safe,
        "surf_rating": int(sea.get("surf_rating") or 0),
        "advisory": t(lang, "advice.swim.safe" if safe else "advice.swim.unsafe"),
        "hourly": hourly,
    }
    localized = t(lang, "sea_state." + skey)
    return CardContent(
        data=data,
        subtitle=f"{localized} · {num(sea.get('wave_height_m'), 1)} m",
        headline=t(
            lang,
            "insight.sea_conditions.headline",
            state=localized,
            wave=num(sea.get("wave_height_m"), 1),
        ),
        detail=t(
            lang,
            "insight.sea_conditions.detail",
            surf=int(sea.get("surf_rating") or 0),
            swim=t(lang, "swim.safe" if safe else "swim.unsafe"),
        ),
        icon="wave",
        source=sea.get("source", "open-meteo"),
    )
