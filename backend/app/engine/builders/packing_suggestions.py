"""02 §21 packing_suggestions — one item list per saved place over the next 3 days."""

from __future__ import annotations

from app.core.i18n import resolve, t
from app.engine.builders.base import CardContent
from app.engine.context import Bundle, Context, UserProfile

DEFAULT_DAYS = 3


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    places = []
    total = 0
    for place in bundle.places:
        block = place.get("packing") or {}
        # the service defers both strings (05 §i18n); 02 §21 publishes `{item, icon, reason}`
        items = [
            {
                "item": t(lang, str(i.get("item_key", ""))),
                "icon": i.get("icon", "suitcase"),
                "reason": resolve(lang, i.get("reason")),
            }
            for i in (block.get("items") or [])
        ]
        total += len(items)
        places.append(
            {
                "place_id": place.get("id"),
                "place_name": place.get("name"),
                "days": int(block.get("days") or DEFAULT_DAYS),
                "items": items,
            }
        )

    first = next((p for p in places if p["items"]), None)
    detail = ""
    if first:
        detail = ", ".join(i.get("item", "") for i in first["items"][:3])

    return CardContent(
        data={"places": places},
        subtitle=t(lang, "packing.count", count=total),
        headline=t(lang, "insight.packing_suggestions.headline", count=total),
        detail=detail,
        icon="suitcase",
        source="open-meteo",
    )
