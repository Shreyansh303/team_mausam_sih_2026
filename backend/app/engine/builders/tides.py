"""02 §17 tides — always labelled Estimated (harmonic model, 05 §Formulas)."""

from __future__ import annotations

from app.core.i18n import t
from app.core.timeutil import parse_any
from app.engine.builders.base import CardContent, hhmm, num
from app.engine.context import Bundle, Context, UserProfile

MAX_EVENTS = 4


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    tides = bundle.snap.get("tides") or {}
    events = [
        {"time": e.get("time"), "type": e.get("type"), "height_m": e.get("height_m")}
        for e in (tides.get("events") or [])
    ][:MAX_EVENTS]

    nxt = None
    for ev in events:
        try:
            if parse_any(str(ev["time"])) > ctx.now:
                nxt = ev
                break
        except (TypeError, ValueError):  # pragma: no cover - defensive
            continue
    if nxt is None and events:
        nxt = events[0]

    trend = tides.get("trend") or "rising"
    data = {
        "events": events,
        "next": nxt,
        "now_height_m": tides.get("now_height_m"),
        "trend": trend,
        "source": "estimated",
        "disclaimer": t(lang, "tides.disclaimer"),
    }
    kind = t(lang, "tide.type." + ((nxt or {}).get("type") or "high"))
    return CardContent(
        data=data,
        subtitle=f"{kind} {hhmm((nxt or {}).get('time'))}",
        headline=t(lang, "insight.tides.headline", type=kind, time=hhmm((nxt or {}).get("time"))),
        detail=t(
            lang,
            "insight.tides.detail",
            height=num((nxt or {}).get("height_m"), 1),
            trend=t(lang, "trend." + trend),
        ),
        icon="tide",
        source="estimated",
        estimated=True,
    )
