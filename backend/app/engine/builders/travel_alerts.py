"""02 §20 travel_alerts — flight/travel risk per saved place; omitted when all low."""

from __future__ import annotations

from typing import Any

from app.core.i18n import t
from app.engine.builders.base import CardContent, flight_detail, localized_warning
from app.engine.context import Bundle, Context, UserProfile

RANK = {"low": 0, "medium": 1, "high": 2}


def alerts_for(bundle: Bundle, ctx: Context) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for place in bundle.places:
        risk_block = place.get("flight_risk") or {}
        risk = risk_block.get("risk", "low")
        if risk == "low":
            continue
        out.append(
            {
                "place_id": place.get("id"),
                "place_name": place.get("name"),
                "risk": risk,
                "hazards": list(risk_block.get("hazards") or []),
                "detail": flight_detail(ctx.lang, risk_block),
                "warnings": [
                    localized_warning(ctx.lang, w) for w in (place.get("warnings") or [])
                ],
            }
        )
    return sorted(out, key=lambda a: -RANK.get(a["risk"], 0))


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    alerts = alerts_for(bundle, ctx)
    top = alerts[0] if alerts else {}
    risk = top.get("risk", "low")

    return CardContent(
        data={"alerts": alerts},
        subtitle=t(lang, "travel.risk." + risk),
        headline=t(
            lang,
            # "2 travel alert(s)" read like a placeholder on the demo screen.
            "insight.travel_alerts.headline." + ("one" if len(alerts) == 1 else "other"),
            count=len(alerts),
            place=top.get("place_name", ""),
        ),
        detail=top.get("detail", ""),
        icon="plane",
        source="mixed",
    )
