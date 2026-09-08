"""02 §2 warnings — every active warning for this location, highest severity first."""

from __future__ import annotations

from app.core.i18n import t
from app.engine import icons
from app.engine.builders.base import CardContent, localized_warning
from app.engine.context import Bundle, Context, UserProfile

SEVERITY_RANK = {"yellow": 1, "orange": 2, "red": 3}


def build(bundle: Bundle, ctx: Context, profile: UserProfile) -> CardContent:
    lang = ctx.lang
    warnings = [
        localized_warning(lang, w)
        for w in sorted(
            ctx.active_warnings,
            key=lambda w: SEVERITY_RANK.get(w.get("severity", "yellow"), 0),
            reverse=True,
        )
    ]
    top = warnings[0] if warnings else {}
    highest = top.get("severity", "yellow")
    hazard = top.get("hazard", "other")

    subtitle = t(lang, "all_clear")
    if top:
        subtitle = f"{t(lang, 'severity.' + highest)} · {t(lang, 'hazard.' + hazard)}"

    return CardContent(
        data={
            "warnings": warnings,
            "district": ctx.location.get("admin2") or ctx.location.get("name"),
            "highest_severity": highest,
        },
        subtitle=subtitle,
        headline=t(lang, "insight.warnings.headline", title=top.get("title", "")),
        detail=top.get("description", ""),
        icon=icons.for_hazard(hazard),
        source=top.get("source", "imd"),
    )
