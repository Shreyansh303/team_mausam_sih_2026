"""02 §19 saved_places — one row per saved place, fetched concurrently by `api/home.py`."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, num
from app.engine.context import Bundle, Context, UserProfile

KEYS = (
    "id",
    "name",
    "lat",
    "lon",
    "country",
    "local_time",
    "temp_c",
    "condition_code",
    "icon",
    "tmax_c",
    "tmin_c",
    "precip_prob_pct",
    "highest_severity",
)


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    places = [{k: p.get(k) for k in KEYS} for p in bundle.places]
    warned = [p for p in places if p.get("highest_severity") in ("orange", "red")]
    hottest = max(places, key=lambda p: (p.get("temp_c") if p.get("temp_c") is not None else -99), default=None)

    if warned:
        detail = t(
            lang,
            # C1: "1 place(s) have an active warning" read like an unfinished string.
            "insight.saved_places.detail_warning." + ("one" if len(warned) == 1 else "other"),
            count=len(warned),
            place=warned[0].get("name", ""),
        )
    elif hottest:
        detail = t(
            lang,
            "insight.saved_places.detail",
            place=hottest.get("name", ""),
            temp=num(hottest.get("temp_c")),
        )
    else:
        detail = ""

    return CardContent(
        data={"places": places},
        subtitle=t(lang, "saved_places.count", count=len(places)),
        headline=t(
            lang,
            "insight.saved_places.headline." + ("one" if len(places) == 1 else "other"),
            count=len(places),
        ),
        detail=detail,
        icon="pin",
        source="open-meteo",
    )
