"""02 §4 hourly_forecast — the next 24 hours (12 in `lite` mode)."""

from __future__ import annotations

from app.core.i18n import t
from app.engine import icons
from app.engine.builders.base import CardContent, hhmm, num
from app.engine.context import Bundle, Context, UserProfile
from app.services.util import next_hours, vmax, vmin


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    rows = next_hours(bundle.hourly, ctx.now, 12 if ctx.lite else 24)
    hours = [
        {
            "time": h["time"],
            "temp_c": h.get("temp_c"),
            "precip_prob_pct": h.get("precip_prob_pct"),
            "precip_mm": h.get("precip_mm"),
            "condition_code": h.get("condition_code"),
            "icon": icons.for_code(h.get("condition_code"), bool(h.get("is_day", True))),
            "wind_kph": h.get("wind_kph"),
            "is_day": bool(h.get("is_day", True)),
        }
        for h in rows
    ]

    tmin, tmax = vmin(rows, "temp_c"), vmax(rows, "temp_c")
    peak = max(rows, key=lambda h: (h.get("precip_prob_pct") or 0), default=None)
    peak_prob = (peak or {}).get("precip_prob_pct") or 0
    if peak_prob >= 30:
        detail = t(
            lang,
            "insight.hourly_forecast.detail_rain",
            prob=num(peak_prob),
            time=hhmm((peak or {}).get("time")),
        )
    else:
        detail = t(lang, "insight.hourly_forecast.detail_dry")

    return CardContent(
        data={"hours": hours},
        subtitle=f"{num(tmin)}° – {num(tmax)}°",
        headline=t(lang, "insight.hourly_forecast.headline", tmin=num(tmin), tmax=num(tmax)),
        detail=detail,
        icon="cloud",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
