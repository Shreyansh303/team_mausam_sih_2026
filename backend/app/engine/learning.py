"""Learning v1 (03 §Learning): engagement counters → a bounded score adjustment.

`engagement_adj` is pure; `apply_events` is the DB side-effect used by `POST /events`. The
effect is immediate on the next `/home`: two dismisses subtract ≈ 0.12, one pin pins the card.
"""

from __future__ import annotations

import math
from typing import Any

from sqlalchemy.orm import Session

#: 03 — `x = taps + 2*expands + 3*pins − 3*dismisses`, adjustment `0.25 * tanh(x / 8)`.
TAP_W = 1
EXPAND_W = 2
PIN_W = 3
DISMISS_W = 3
SCALE = 8.0
MAX_ADJ = 0.25

#: `pin/unpin/hide/unhide` also write card-prefs (04 §Engagement events).
PREF_ACTIONS = {
    "pin": ("pinned", True),
    "unpin": ("pinned", False),
    "hide": ("hidden", True),
    "unhide": ("hidden", False),
}

COUNTER_FOR = {
    "impression": "impressions",
    "tap": "taps",
    "expand": "expands",
    "dismiss": "dismisses",
    "pin": "pins",
}


def engagement_adj(stats: dict[str, int] | None) -> float:
    """−0.25 … +0.25 (03). No stats → no adjustment."""
    if not stats:
        return 0.0
    x = (
        TAP_W * int(stats.get("taps", 0))
        + EXPAND_W * int(stats.get("expands", 0))
        + PIN_W * int(stats.get("pins", 0))
        - DISMISS_W * int(stats.get("dismisses", 0))
    )
    return MAX_ADJ * math.tanh(x / SCALE)


def apply_events(
    db: Session, *, user_id: str, events: list[dict[str, Any]]
) -> dict[str, dict[str, int]]:
    """Fold a batch into the engagement counters, the raw event log and card-prefs."""
    from app.models.event import Event
    from app.services import users as users_svc

    touched: set[str] = set()
    for ev in events:
        card_type = str(ev["type"])
        action = str(ev["action"])
        touched.add(card_type)

        db.add(
            Event(
                user_id=user_id,
                card_type=card_type,
                action=action,
                ts=ev.get("ts"),
                meta=ev.get("meta"),
            )
        )

        counter = COUNTER_FOR.get(action)
        if counter:
            row = users_svc.engagement_row(db, user_id, card_type)
            setattr(row, counter, int(getattr(row, counter) or 0) + 1)
        elif action == "unpin":
            row = users_svc.engagement_row(db, user_id, card_type)
            row.pins = max(0, int(row.pins or 0) - 1)

        pref = PREF_ACTIONS.get(action)
        if pref:
            field, value = pref
            pref_row = users_svc.pref_row(db, user_id, card_type)
            setattr(pref_row, field, value)

    db.flush()
    engagement = users_svc.engagement_for(db, user_id)
    return {t: engagement.get(t, {}) for t in sorted(touched) if engagement.get(t)}
