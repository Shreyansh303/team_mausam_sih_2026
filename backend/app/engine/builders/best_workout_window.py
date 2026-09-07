"""02 §12 best_workout_window — scored hours, up to three windows."""

from __future__ import annotations

from app.core.i18n import t
from app.engine.builders.base import CardContent, hhmm, key_of, num
from app.engine.context import Bundle, Context, UserProfile

LITE_HOURS = 12


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    block = bundle.block("workout")
    windows = [dict(w) for w in (block.get("windows") or [])][:3]
    best = dict(block.get("best")) if block.get("best") else None
    scores = list(block.get("hourly_scores") or [])
    if ctx.lite:
        scores = scores[:LITE_HOURS]

    data = {
        "windows": windows,
        "best": best,
        "hourly_scores": scores,
        "no_good_window_reason": (
            None if best else t(lang, "insight.best_workout_window.none")
        ),
    }

    if best:
        start, end = hhmm(best.get("start")), hhmm(best.get("end"))
        headline = t(lang, "insight.best_workout_window.headline", start=start, end=end)
        detail = t(
            lang,
            "insight.best_workout_window.detail",
            score=num(best.get("score")),
            temp=num(best.get("temp_c")),
            aqi=num(best.get("aqi")),
        )
        label = t(lang, "workout.label." + key_of(best.get("label") or "Fair"))
        subtitle = f"{start}–{end} · {label}"
    else:
        headline = t(lang, "insight.best_workout_window.none")
        detail = str(data["no_good_window_reason"] or "")
        subtitle = t(lang, "workout.none")

    return CardContent(
        data=data,
        subtitle=subtitle,
        headline=headline,
        detail=detail,
        icon="run",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
