"""02 §5 daily_forecast — seven days."""

from __future__ import annotations

from app.core.i18n import t
from app.engine import icons
from app.engine.builders.base import CardContent, num
from app.engine.context import Bundle, Context, UserProfile
from app.services.util import vmax, vmin

DAYS = 7


def rows_for(bundle: Bundle, count: int) -> list[dict]:
    return [
        {
            "date": d.get("date"),
            "tmax_c": d.get("tmax_c"),
            "tmin_c": d.get("tmin_c"),
            "precip_prob_max_pct": d.get("precip_prob_max_pct"),
            "precip_sum_mm": d.get("precip_sum_mm"),
            "condition_code": d.get("condition_code"),
            "icon": icons.for_code(d.get("condition_code"), True),
        }
        for d in bundle.daily[:count]
    ]


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    days = rows_for(bundle, DAYS)
    tmax = vmax(days, "tmax_c")
    tmin = vmin(days, "tmin_c")
    rain_days = sum(1 for d in days if (d.get("precip_sum_mm") or 0) >= 2.5)
    return CardContent(
        data={"days": days},
        subtitle=f"{num(tmin)}° – {num(tmax)}°",
        headline=t(lang, "insight.daily_forecast.headline", tmin=num(tmin), tmax=num(tmax)),
        detail=t(
            lang,
            "insight.daily_forecast.detail." + ("one" if rain_days == 1 else "other"),
            days=rain_days,
        ),
        icon="calendar",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
