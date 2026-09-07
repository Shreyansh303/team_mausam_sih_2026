"""02 §31 extended_forecast — 14 days plus a confidence note."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, num
from app.engine.builders.daily_forecast import rows_for
from app.engine.context import Bundle, Context, UserProfile
from app.services.util import vmax, vmin

DAYS = 14


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    days = rows_for(bundle, DAYS)
    tmax = vmax(days, "tmax_c")
    tmin = vmin(days, "tmin_c")
    note = t(lang, "insight.extended_forecast.confidence")
    return CardContent(
        data={"days": days, "confidence_note": note},
        subtitle=f"{len(days)} {t(lang, 'unit.days')} · {num(tmin)}° – {num(tmax)}°",
        headline=t(lang, "insight.extended_forecast.headline", tmin=num(tmin), tmax=num(tmax)),
        detail=note,
        icon="calendar",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
