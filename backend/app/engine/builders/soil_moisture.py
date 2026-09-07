"""02 §24 soil_moisture — surface and root-zone volumetric water content."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, num
from app.engine.context import Bundle, Context, UserProfile


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("soil")
    status = block.get("status") or "adequate"

    data = {
        "surface_m3m3": block.get("surface_m3m3"),
        "root_zone_m3m3": block.get("root_zone_m3m3"),
        "status": status,
        "soil_temp_c": block.get("soil_temp_c"),
        "days_since_rain": block.get("days_since_rain"),
        "advice": t(lang, "advice.soil." + status),
    }
    localized = t(lang, "soil.status." + status)
    return CardContent(
        data=data,
        subtitle=f"{num(block.get('surface_m3m3'), 2)} m³/m³ · {localized}",
        headline=t(
            lang,
            "insight.soil_moisture.headline",
            status=localized,
            value=num(block.get("surface_m3m3"), 2),
        ),
        detail=str(data["advice"]),
        icon="soil",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
