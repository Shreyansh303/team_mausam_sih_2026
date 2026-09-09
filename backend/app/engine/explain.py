"""Reason codes and localized texts — 03 §Explainability, in the order listed there.

`persona:<id>` → `urgency:<type>:<level>` → `time:<daypart>` / `season:<s>` →
`location:coastal` / `places:saved` → `engagement:up|down` → `learning:up|down` →
`pinned:user|urgent`. At most four reasons per card.

`learning:*` is the Learning v2 family (03, `ENGINE_ML=1`). It carries the signed value of the
bounded ML term the ranker actually applied — "Learned from your taps (+0.04)" — so the why
sheet can show the ML contribution instead of the user having to take it on trust. With the
flag off `Scored.ml` is 0.0 and the reason is never emitted.
"""

from __future__ import annotations

from app.core.i18n import t
from app.engine.context import Context, UserProfile
from app.engine.scoring import Scored
from app.schemas.card import Reason, severity_for

MAX_REASONS = 4
PERSONA_MIN_RELEVANCE = 0.45
URGENCY_MIN = 0.3
MULT_MIN = 1.2
ENGAGEMENT_MIN = 0.08
#: Learning v2 — below this the learned term is not worth a line in the why sheet.
LEARNING_MIN = 0.01

#: 02 §Affinity gates — the cards that only exist near the coast.
COASTAL_CARDS = {"sea_conditions", "tides", "water_temp"}
#: 02 — the traveler cards gated on "≥ 1 saved place".
PLACE_CARDS = {"saved_places", "travel_alerts", "packing_suggestions"}


def reasons_for(scored: Scored, ctx: Context, profile: UserProfile) -> list[Reason]:
    lang = ctx.lang
    out: list[Reason] = []

    def add(code: str, text: str) -> None:
        if len(out) < MAX_REASONS and not any(r.code == code for r in out):
            out.append(Reason(code=code, text=text))

    if scored.top_persona and scored.relevance >= PERSONA_MIN_RELEVANCE:
        pid = scored.top_persona
        add(f"persona:{pid}", t(lang, f"reason.persona.{pid}"))

    if scored.urgency >= URGENCY_MIN:
        level = severity_for(scored.urgency)
        add(
            f"urgency:{scored.type}:{level}",
            t(
                lang,
                f"reason.urgency.{scored.type}",
                level=t(lang, f"reason.level.{level}"),
            ),
        )

    if scored.time_mult >= MULT_MIN:
        add(f"time:{ctx.daypart}", t(lang, f"reason.time.{ctx.daypart}"))
    if scored.season_mult >= MULT_MIN:
        add(f"season:{ctx.season}", t(lang, f"reason.season.{ctx.season}"))

    if scored.type in COASTAL_CARDS:
        add("location:coastal", t(lang, "reason.coastal"))
    if scored.type in PLACE_CARDS and profile.saved_places:
        add("places:saved", t(lang, "reason.places.saved"))

    if scored.engagement >= ENGAGEMENT_MIN:
        add("engagement:up", t(lang, "reason.engagement.up"))
    elif scored.engagement <= -ENGAGEMENT_MIN:
        add("engagement:down", t(lang, "reason.engagement.down"))

    if abs(scored.ml) >= LEARNING_MIN:
        delta = f"{scored.ml:+.2f}"
        direction = "up" if scored.ml > 0 else "down"
        add(f"learning:{direction}", t(lang, f"reason.learning.{direction}", delta=delta))

    if scored.pinned_by_user:
        add("pinned:user", t(lang, "reason.pinned.user"))
    elif scored.pinned:
        add("pinned:urgent", t(lang, "reason.pinned.urgent"))

    return out[:MAX_REASONS]
