"""02 §13 sun_times — sunrise, sunset, daylight and the golden hours."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, hhmm
from app.engine.context import Bundle, Context, UserProfile


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    sun = bundle.block("sun")
    minutes = int(sun.get("daylight_minutes") or 0)
    hours, mins = divmod(minutes, 60)

    data = {
        "sunrise": sun.get("sunrise"),
        "sunset": sun.get("sunset"),
        "daylight_minutes": sun.get("daylight_minutes"),
        "golden_hour_morning": sun.get("golden_hour_morning"),
        "golden_hour_evening": sun.get("golden_hour_evening"),
        "civil_twilight_end": sun.get("civil_twilight_end"),
    }
    return CardContent(
        data=data,
        subtitle=f"{hhmm(sun.get('sunrise'))} · {hhmm(sun.get('sunset'))}",
        headline=t(
            lang,
            "insight.sun_times.headline",
            sunrise=hhmm(sun.get("sunrise")),
            sunset=hhmm(sun.get("sunset")),
        ),
        detail=t(lang, "insight.sun_times.detail", hours=hours, minutes=mins),
        icon="sunrise",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
