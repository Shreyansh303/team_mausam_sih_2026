"""02 §32 rain_probability — "will it rain on my event day?" for the event planner.

`focus_date` is `?event_date=` when the client sends it, otherwise the next Saturday.
"""

from __future__ import annotations

from datetime import date, timedelta

from app.core.i18n import t
from app.engine.builders.base import CardContent, daylabel, num
from app.engine.context import Bundle, Context, UserProfile

DAYS = 7
HOURS = 24
LITE_HOURS = 12
SATURDAY = 5


def next_saturday(today: date) -> date:
    delta = (SATURDAY - today.weekday()) % 7
    return today + timedelta(days=delta or 7)


def focus_date_for(ctx: Context) -> str:
    if ctx.event_date:
        return ctx.event_date
    return next_saturday(ctx.now.date()).isoformat()


def verdict_for(prob: float | None) -> str:
    p = prob or 0
    if p < 20:
        return "dry"
    if p < 50:
        return "possible"
    if p < 75:
        return "likely"
    return "wet"


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    focus = focus_date_for(ctx)
    by_day = [
        {
            "date": d.get("date"),
            "prob_pct": d.get("precip_prob_max_pct"),
            "mm": d.get("precip_sum_mm"),
        }
        for d in bundle.daily[:DAYS]
    ]
    row = next((d for d in by_day if d["date"] == focus), None)
    if row is None and by_day:
        row = by_day[-1]
        focus = str(row["date"])

    hourly_focus = [
        {"time": h.get("time"), "prob_pct": h.get("precip_prob_pct")}
        for h in bundle.hourly
        if str(h.get("time", ""))[:10] == focus
    ][: LITE_HOURS if ctx.lite else HOURS]

    prob = (row or {}).get("prob_pct")
    verdict = verdict_for(prob)
    label = daylabel(lang, focus, with_dow=True)

    data = {
        "focus_date": focus,
        "focus_label": label,
        "by_day": by_day,
        "hourly_focus": hourly_focus,
        "verdict": verdict,
        "advice": t(lang, "advice.rain_probability." + verdict),
    }
    localized = t(lang, "rain_probability.verdict." + verdict)
    return CardContent(
        data=data,
        subtitle=f"{label} · {num(prob)}%",
        headline=t(
            lang, "insight.rain_probability.headline", label=label, prob=num(prob),
            verdict=localized,
        ),
        detail=t(
            lang, "insight.rain_probability.detail", mm=num((row or {}).get("mm"), 1),
            advice=str(data["advice"]),
        ),
        icon="calendar",
        source=bundle.snap.get("sources", {}).get("weather", "open-meteo"),
    )
