"""02 §1 current_conditions — the hero card, always first after the pinned block."""

from __future__ import annotations

from app.core.geo import compass
from app.core.i18n import t
from app.engine import icons
from app.engine.builders.base import CardContent, condition_text, key_of, num
from app.engine.context import Bundle, Context, UserProfile


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    cur = bundle.current
    today = bundle.daily[0] if bundle.daily else {}
    air = bundle.air
    lang = ctx.lang
    is_day = bool(cur.get("is_day", True))
    code = cur.get("condition_code")
    condition = condition_text(lang, code)
    aqi_category = air.get("category")

    data = {
        "temp_c": cur.get("temp_c"),
        "feels_like_c": cur.get("feels_like_c"),
        "condition_code": code,
        "condition_text": condition,
        "icon": icons.for_code(code, is_day),
        "humidity_pct": cur.get("humidity_pct"),
        "wind_kph": cur.get("wind_kph"),
        "wind_dir": compass(cur.get("wind_dir_deg")),
        "uv_index": cur.get("uv_index"),
        "visibility_km": cur.get("visibility_km"),
        "pressure_hpa": cur.get("pressure_hpa"),
        "tmax_c": today.get("tmax_c"),
        "tmin_c": today.get("tmin_c"),
        "is_day": is_day,
        "aqi": air.get("aqi"),
        "aqi_category": aqi_category,
        "sunrise": today.get("sunrise"),
        "sunset": today.get("sunset"),
        "all_clear": not ctx.active_warnings,
        "updated_at": bundle.snap.get("fetched_at"),
    }

    headline = t(
        lang,
        "insight.current_conditions.summary",
        temp=num(cur.get("temp_c")),
        feels=num(cur.get("feels_like_c")),
        condition=condition,
    )
    if aqi_category:
        detail = t(
            lang,
            "insight.current_conditions.detail",
            humidity=num(cur.get("humidity_pct")),
            wind=num(cur.get("wind_kph")),
            aqi_category=t(lang, f"aqi.category.{key_of(aqi_category)}"),
            aqi=num(air.get("aqi")),
        )
    else:
        detail = t(
            lang,
            "insight.current_conditions.detail_no_air",
            humidity=num(cur.get("humidity_pct")),
            wind=num(cur.get("wind_kph")),
        )

    return CardContent(
        data=data,
        subtitle=f"{num(today.get('tmax_c'))}° / {num(today.get('tmin_c'))}° · {condition}",
        headline=headline,
        detail=detail,
        icon=data["icon"],
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
