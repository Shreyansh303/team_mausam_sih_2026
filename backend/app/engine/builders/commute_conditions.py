"""02 §28 commute_conditions — morning and evening windows plus a traffic estimate."""

from __future__ import annotations

from app.core.i18n import resolve_all, t
from app.engine.builders.base import CardContent, hhmm
from app.engine.context import Bundle, Context, UserProfile

WINDOW_KEYS = (
    "label",
    "start",
    "end",
    "impact",
    "delay_min",
    "rain_prob_pct",
    "visibility_km",
    "temp_c",
    "reasons",
)


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("commute")
    windows = [{k: w.get(k) for k in WINDOW_KEYS} for w in (block.get("windows") or [])]
    for window in windows:
        # the service emits deferred translations; 02 asks for plain strings here
        window["reasons"] = resolve_all(lang, window.get("reasons"))
    overall = block.get("overall_impact") or "low"
    traffic = block.get("traffic") or {"congestion_pct": 0, "source": "estimated"}
    delay = max((int(w.get("delay_min") or 0) for w in windows), default=0)

    data = {
        "windows": windows,
        "traffic": {
            "congestion_pct": traffic.get("congestion_pct", 0),
            "source": traffic.get("source", "estimated"),
        },
        "advice": t(lang, "advice.commute." + overall),
    }
    localized = t(lang, "commute.impact." + overall)
    first = windows[0] if windows else {}
    return CardContent(
        data=data,
        subtitle=f"{hhmm(first.get('start'))}–{hhmm(first.get('end'))} · {localized}",
        headline=t(lang, "insight.commute_conditions.headline", impact=localized, delay=delay),
        detail=str(data["advice"]),
        icon="traffic",
        source=traffic.get("source", "estimated"),
        estimated=traffic.get("source") == "estimated",
    )
