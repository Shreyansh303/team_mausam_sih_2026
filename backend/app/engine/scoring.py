"""Deterministic scoring and ordering — the formulas in 03 §Algorithm, verbatim.

```
rel  = relevance(card, profile)
ctx  = clamp(time_mult * season_mult, 0.4, 1.6)
urg  = card.urgency(snapshot, context)
eng  = engagement_adj(profile.engagement[type])
score = 0.5 * rel * ctx + 0.5 * urg + eng
pinned = type in profile.pins or urg >= 0.8
```
"""

from __future__ import annotations

from dataclasses import dataclass, field

from app.engine.catalog import CARDS, HERO_TYPE, CardDef
from app.engine.context import Bundle, Context, UserProfile
from app.engine.learning import engagement_adj

CTX_MIN = 0.4
CTX_MAX = 1.6
W_RELEVANCE = 0.5
W_URGENCY = 0.5
PIN_URGENCY = 0.8
#: 03 §Ordering — the first 8 ranked cards are `cards`; the rest are `more_cards`.
VISIBLE_CARDS = 8
#: 03 §Ordering — anything below this also drops into `more_cards`.
MIN_VISIBLE_SCORE = 0.12


def clamp(value: float, lo: float = CTX_MIN, hi: float = CTX_MAX) -> float:
    return max(lo, min(hi, value))


def relevance(card: CardDef, profile: UserProfile) -> float:
    """03: `min(1, max(contribs) + 0.15 * (sum(contribs) − max(contribs)))`."""
    pairs = [*profile.personas, ("base", 1.0)]
    contribs = [weight * card.affinity.get(pid, 0.0) for pid, weight in pairs]
    if not contribs:
        return 0.0
    top = max(contribs)
    return min(1.0, top + 0.15 * (sum(contribs) - top))


def context_multiplier(card: CardDef, ctx: Context) -> float:
    return clamp(card.time_mult(ctx) * card.season_mult(ctx))


@dataclass
class Scored:
    """One catalog entry evaluated for this user, in this context."""

    card: CardDef
    relevance: float
    ctx: float
    urgency: float
    engagement: float
    score: float
    pinned: bool
    pinned_by_user: bool
    time_mult: float = 1.0
    season_mult: float = 1.0
    top_persona: str | None = None

    @property
    def type(self) -> str:
        return self.card.type

    @property
    def order(self) -> int:
        return self.card.order


@dataclass
class Ranking:
    """The ordered result: pinned → hero → cards → more_cards, plus `hidden_types`."""

    pinned: list[Scored] = field(default_factory=list)
    hero: Scored | None = None
    cards: list[Scored] = field(default_factory=list)
    more_cards: list[Scored] = field(default_factory=list)
    hidden_types: list[str] = field(default_factory=list)
    skipped: list[str] = field(default_factory=list)

    def all_scored(self) -> list[Scored]:
        out = list(self.pinned)
        if self.hero is not None:
            out.append(self.hero)
        return out + self.cards + self.more_cards


def top_persona_for(card: CardDef, profile: UserProfile) -> str | None:
    """The persona that contributes the most to `relevance` (03 §Explainability)."""
    best: tuple[float, str] | None = None
    for pid, weight in profile.personas:
        value = weight * card.affinity.get(pid, 0.0)
        if value <= 0:
            continue
        if best is None or value > best[0]:
            best = (value, pid)
    return best[1] if best else None


def evaluate(card: CardDef, bundle: Bundle, ctx: Context, profile: UserProfile) -> Scored:
    rel = relevance(card, profile)
    tm = card.time_mult(ctx)
    sm = card.season_mult(ctx)
    ctx_mult = clamp(tm * sm)
    urg = max(0.0, min(1.0, float(card.urgency(bundle, ctx))))
    eng = engagement_adj(profile.stats(card.type))
    score = W_RELEVANCE * rel * ctx_mult + W_URGENCY * urg + eng
    pinned_by_user = card.type in profile.pins
    return Scored(
        card=card,
        relevance=round(rel, 4),
        ctx=round(ctx_mult, 4),
        urgency=round(urg, 4),
        engagement=round(eng, 4),
        score=round(score, 4),
        pinned=pinned_by_user or urg >= PIN_URGENCY,
        pinned_by_user=pinned_by_user,
        time_mult=tm,
        season_mult=sm,
        top_persona=top_persona_for(card, profile),
    )


def rank(bundle: Bundle, ctx: Context, profile: UserProfile) -> Ranking:
    """03 §Algorithm + §Ordering. Stable and deterministic; ties break on catalog order."""
    result = Ranking()
    scored: list[Scored] = []

    for card in CARDS:
        if card.type in profile.hidden and card.type != HERO_TYPE:
            result.hidden_types.append(card.type)
            continue
        if card.type == HERO_TYPE:
            result.hero = evaluate(card, bundle, ctx, profile)
            continue
        try:
            open_gate = card.gate(bundle, ctx, profile)
        except Exception:  # pragma: no cover - a broken gate must not break the home screen
            open_gate = False
        if not open_gate:
            result.skipped.append(card.type)
            continue
        scored.append(evaluate(card, bundle, ctx, profile))

    pinned = [s for s in scored if s.pinned]
    rest = [s for s in scored if not s.pinned]

    result.pinned = sorted(pinned, key=lambda s: (-s.urgency, -s.score, s.order))
    ranked = sorted(rest, key=lambda s: (-s.score, s.order))

    visible: list[Scored] = []
    overflow: list[Scored] = []
    for s in ranked:
        if len(visible) < VISIBLE_CARDS and s.score >= MIN_VISIBLE_SCORE:
            visible.append(s)
        else:
            overflow.append(s)

    result.cards = visible
    result.more_cards = overflow
    return result
