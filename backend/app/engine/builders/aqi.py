"""02 §7 aqi — CPCB scale, hourly trend and the category advisory."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, key_of, num
from app.engine.context import Bundle, Context, UserProfile
from app.services.aqi_cpcb import POLLUTANT_KEY

HOURS = 24
LITE_HOURS = 12
#: 02 §7 — the fitness persona gets the extra "avoid outdoor exercise" line from Poor upwards.
BAD = ("Poor", "Very Poor", "Severe")


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    air = bundle.air
    category = air.get("category") or "Good"
    ckey = key_of(category)
    advice = t(lang, "advice.aqi." + ckey)
    if "fitness" in profile.persona_ids and category in BAD:
        advice = advice + " " + t(lang, "advice.aqi.fitness")

    hourly = list(air.get("hourly") or [])[: LITE_HOURS if ctx.lite else HOURS]
    # `dominant_pollutant` is the CPCB *display label* ("PM2.5"); the i18n key and the
    # concentration are both filed under the raw field name ("pm2_5").
    dominant = air.get("dominant_pollutant")
    dominant_key = POLLUTANT_KEY.get(str(dominant or ""), "pm2_5")
    dominant_value = air.get(dominant_key)
    if dominant_key == "co" and dominant_value is not None:
        # CPCB takes CO in mg/m³; the insight quotes µg/m³ like every other pollutant.
        dominant_value = float(dominant_value) * 1000.0

    data = {
        "aqi": air.get("aqi"),
        "category": category,
        "dominant_pollutant": dominant,
        "pm2_5": air.get("pm2_5"),
        "pm10": air.get("pm10"),
        "o3": air.get("o3"),
        "no2": air.get("no2"),
        "so2": air.get("so2"),
        "co": air.get("co"),
        "hourly": hourly,
        "advice": advice,
        "scale": "CPCB",
    }
    localized = t(lang, "aqi.category." + ckey)
    return CardContent(
        data=data,
        subtitle=f"{localized} · {num(air.get('aqi'))}",
        headline=t(lang, "insight.aqi.headline", category=localized, aqi=num(air.get("aqi"))),
        detail=t(
            lang,
            "insight.aqi.detail",
            pollutant=t(lang, "pollutant." + dominant_key),
            value=num(dominant_value),
        ),
        icon="aqi",
        source=bundle.snap.get("sources", {}).get("air", "open-meteo"),
    )
