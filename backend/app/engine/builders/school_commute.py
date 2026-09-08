"""02 §22 school_commute — the morning drop and afternoon pickup windows."""

from __future__ import annotations

from app.core.i18n import resolve_all, t
from app.engine.builders.base import CardContent, hhmm
from app.engine.context import Bundle, Context, UserProfile

WINDOW_KEYS = (
    "label",
    "start",
    "end",
    "verdict",
    "temp_c",
    "precip_prob_pct",
    "visibility_km",
    "aqi",
    "reasons",
)


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("school_commute")
    windows = [{k: w.get(k) for k in WINDOW_KEYS} for w in (block.get("windows") or [])]
    for window in windows:
        # the service emits deferred translations; 02 asks for plain strings here
        window["reasons"] = resolve_all(lang, window.get("reasons"))
    overall = block.get("overall_verdict") or "good"

    data = {
        "windows": windows,
        "overall_verdict": overall,
        "advice": t(lang, "advice.school." + overall),
        "is_school_day": bool(block.get("is_school_day", True)),
    }
    localized = t(lang, "school.verdict." + overall)
    morning = windows[0] if windows else {}
    return CardContent(
        data=data,
        subtitle=f"{hhmm(morning.get('start'))}–{hhmm(morning.get('end'))} · {localized}",
        headline=t(lang, "insight.school_commute.headline", verdict=localized),
        detail=str(data["advice"]),
        icon="school",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
