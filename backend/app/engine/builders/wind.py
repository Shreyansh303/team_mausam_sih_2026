"""02 §14 wind — speed, gusts, Beaufort force and the 24-hour trace."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, num
from app.engine.context import Bundle, Context, UserProfile

LITE_HOURS = 12


def advice_key(force: int) -> str:
    if force <= 3:
        return "advice.wind.calm"
    if force <= 5:
        return "advice.wind.breezy"
    if force <= 7:
        return "advice.wind.strong"
    return "advice.wind.gale"


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("wind")
    force = int(block.get("beaufort") or 0)
    hourly = list(block.get("hourly") or [])
    if ctx.lite:
        hourly = hourly[:LITE_HOURS]
    beaufort_text = t(lang, f"beaufort.{force}")
    direction = block.get("direction_text") or ""

    data = {
        "speed_kph": block.get("speed_kph"),
        "gust_kph": block.get("gust_kph"),
        "direction_deg": block.get("direction_deg"),
        "direction_text": direction,
        "beaufort": force,
        "beaufort_text": beaufort_text,
        "hourly": hourly,
        "advice": t(lang, advice_key(force)),
    }
    return CardContent(
        data=data,
        subtitle=f"{num(block.get('speed_kph'))} km/h {direction}".strip(),
        headline=t(
            lang,
            "insight.wind.headline",
            speed=num(block.get("speed_kph")),
            direction=direction,
            beaufort=beaufort_text,
        ),
        detail=t(lang, "insight.wind.detail", gust=num(block.get("gust_kph"))),
        icon="wind",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
