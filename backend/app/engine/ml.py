"""Learning v2 (03 §"Learning (v2)"): a bounded logistic-regression tap-propensity model.

Off by default. `ENGINE_ML=1` switches it on; with the flag off nothing in this module is
reached and `scoring.evaluate` produces the v1 score byte for byte.

What it does
------------
Predicts `p_tap` — the probability that *this* user opens *this* card type in *this* context —
from the events already logged by `POST /events`, and blends it into the v1 score as

    score += ML_WEIGHT * (p_tap - 0.5)          # ML_WEIGHT = 0.2, so the term is ±0.1

**The bound is the point.** Three guarantees, each of them tested in `tests/test_ml.py`:

1. `adjustment()` is clamped to ±`ML_MAX` (0.1), so a maximally confident model moves a card
   by less than a tenth of a score point.
2. It is added to `score` only — never to `urgency` — so it cannot push a card past the
   `urgency >= 0.8` pin threshold in 03 §Algorithm.
3. It is applied only to cards that are **not** pinned, and 03 §Ordering renders the whole
   pinned block above `cards`. A learned card therefore cannot outrank a pinned orange/red
   warning no matter what the model believes. This is the safety claim in docs/08 §Risks.

Implementation notes
--------------------
No new dependency: numpy is not pinned in `requirements.txt`, so the model is ~40 lines of
plain-Python SGD over a sparse `{feature_name: value}` dict. The vector is small (about 15
non-zero features per example) and training is capped at `MAX_EVENTS x EPOCHS` updates, which
is why it can run inline on `POST /events` instead of needing a worker.

Everything above `# --- persistence` is pure and deterministic, like the rest of `app/engine/`.
The two functions below it are the DB side used by `api/events.py` and `api/home.py`, exactly
the split `learning.py` already uses for v1.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import datetime
from typing import TYPE_CHECKING, Any

from app.core.timeutil import UTC, daypart as daypart_of, is_weekend as is_weekend_of
from app.core.timeutil import parse_any, season as season_of, tz_for

if TYPE_CHECKING:  # pragma: no cover - typing only, keeps this module import-cycle free
    from sqlalchemy.orm import Session

#: Bumped whenever the feature set changes; a row written by an older version is retrained.
MODEL_VERSION = "2.0"

#: 03 §Learning v2 — `score += 0.2 * (p_tap - 0.5)`.
ML_WEIGHT = 0.2
#: Hard ceiling on the learned term. `ML_WEIGHT * (p - 0.5)` already lives in (-0.1, 0.1);
#: the clamp is belt-and-braces so a future weight change cannot quietly widen the bound.
ML_MAX = 0.1
#: Cold start: below this many labelled events the model returns exactly 0.5 → zero effect.
MIN_EVENTS = 8
#: `p_tap` for a user the model knows nothing about.
COLD_START_P = 0.5

#: Training budget per `POST /events` call — bounded work, no background worker needed.
MAX_EVENTS = 300
EPOCHS = 5
LEARNING_RATE = 0.15
L2 = 0.002
WEIGHT_CLIP = 5.0

#: Implicit-feedback labels. `unpin` / `unhide` are corrections, not preferences — skipped.
POSITIVE_ACTIONS = {"tap": 1.0, "expand": 1.0, "pin": 2.0}
NEGATIVE_ACTIONS = {"impression": 1.0, "dismiss": 2.0, "hide": 3.0}

#: Recency half-life-ish constant for `exp(-age_days / RECENCY_DAYS)`.
RECENCY_DAYS = 7.0
#: `tanh(impressions / VOLUME_SCALE)` — "how much do we actually know about this card type".
VOLUME_SCALE = 10.0

#: The demo clock and every logged `ts` are IST unless the client says otherwise (04 §Base).
DEFAULT_TZ = "Asia/Kolkata"


def sigmoid(z: float) -> float:
    if z >= 0:
        return 1.0 / (1.0 + math.exp(-min(z, 60.0)))
    e = math.exp(max(z, -60.0))
    return e / (1.0 + e)


def urgency_band(urgency: float | None) -> str:
    """Three bands plus `unknown` — see `feature_vector` for why `unknown` exists."""
    if urgency is None:
        return "unknown"
    if urgency >= 0.6:
        return "high"
    if urgency >= 0.3:
        return "medium"
    return "low"


# --------------------------------------------------------------------------- features


def feature_vector(
    *,
    card_type: str,
    daypart: str,
    season: str,
    is_weekend: bool,
    personas: list[tuple[str, float]],
    persona_match: float,
    urgency: float | None,
    counters: dict[str, int] | None,
    last_ts: float | None,
    now_ts: float,
) -> dict[str, float]:
    """The sparse feature vector, built identically at training and at prediction time.

    Blocks, in the order 03 §Learning v2 lists them:

    * `type:<card_type>` one-hot — what the model mostly learns from tap history.
    * `daypart:<d>` / `season:<s>` / `weekend` — the time-of-day and calendar context, taken
      from the *event's own* timestamp when training and from `Context.now` when predicting.
    * `persona:<id>` one-hots (persona weight as the value) and `persona_match`, the v1
      `relevance` for this card — "does this card belong to who the user says they are".
    * `urg:<band>` — the urgency band. Reconstructable from a logged event only when the
      client put `meta.urgency` on it; every other event lands in `urg:unknown`, whose weight
      is what actually trains today. The band is therefore wired end to end but contributes
      nothing until the app starts sending it, which is the safe direction to fail in: the
      bound in this module exists precisely so that learning cannot re-weight urgency.
    * `hist_*` — the per-user, per-card-type counters from `POST /events` (impressions, taps,
      expands, dismisses, pins), as rates rather than raw counts so a heavy user and a light
      user live on the same scale.
    * `recency` — `exp(-age_days / 7)` since this card type was last interacted with.

    `is_coastal` from the docs sketch is deliberately absent: it is a hard *gate* in the
    catalog, not a preference, and it is not recoverable from a logged event.
    """
    counts = counters or {}
    impressions = float(counts.get("impressions", 0) or 0)
    taps = float(counts.get("taps", 0) or 0)
    expands = float(counts.get("expands", 0) or 0)
    dismisses = float(counts.get("dismisses", 0) or 0)
    pins = float(counts.get("pins", 0) or 0)
    denom = impressions + 1.0

    if last_ts is None:
        recency = 0.0
    else:
        age_days = max(0.0, (now_ts - last_ts) / 86400.0)
        recency = math.exp(-age_days / RECENCY_DAYS)

    feats: dict[str, float] = {
        "bias": 1.0,
        f"type:{card_type}": 1.0,
        f"daypart:{daypart}": 1.0,
        f"season:{season}": 1.0,
    }
    if is_weekend:
        feats["weekend"] = 1.0
    for pid, weight in personas:
        feats[f"persona:{pid}"] = float(weight)
    feats["persona_match"] = max(0.0, min(1.0, float(persona_match)))
    feats[f"urg:{urgency_band(urgency)}"] = 1.0
    feats["hist_tap_rate"] = min(1.0, taps / denom)
    feats["hist_expand_rate"] = min(1.0, expands / denom)
    feats["hist_dismiss_rate"] = min(1.0, dismisses / denom)
    feats["hist_pinned"] = 1.0 if pins > 0 else 0.0
    feats["hist_volume"] = math.tanh(impressions / VOLUME_SCALE)
    feats["recency"] = recency
    return feats


# --------------------------------------------------------------------------- model


@dataclass
class Example:
    """One labelled training row."""

    features: dict[str, float]
    label: float
    weight: float = 1.0


@dataclass
class RankerModel:
    """A user's learned weights. Pure: no I/O, no clock of its own."""

    weights: dict[str, float] = field(default_factory=dict)
    stats: dict[str, dict[str, float]] = field(default_factory=dict)
    n_events: int = 0
    version: str = MODEL_VERSION

    @property
    def ready(self) -> bool:
        """False → `p_tap` is the 0.5 cold-start prior and the score is untouched."""
        return (
            self.version == MODEL_VERSION
            and self.n_events >= MIN_EVENTS
            and bool(self.weights)
        )

    def seen(self, card_type: str) -> bool:
        """Has this user ever interacted with this card type? (`stats` is written per type.)"""
        return card_type in self.stats

    def last_ts(self, card_type: str) -> float | None:
        row = self.stats.get(card_type) or {}
        value = row.get("last_ts")
        return float(value) if value is not None else None

    def p_tap(self, features: dict[str, float]) -> float:
        """Raw model output. `0.5` — a zero contribution — until the model is `ready`."""
        if not self.ready:
            return COLD_START_P
        z = 0.0
        for name, value in features.items():
            weight = self.weights.get(name)
            if weight:
                z += weight * value
        return sigmoid(z)

    def predict(self, card_type: str, features: dict[str, float]) -> float:
        """`p_tap` with a **per-card-type** cold start on top of the per-user one.

        A card type this user has never touched stays at exactly 0.5. The reason is honesty
        rather than accuracy: a logistic model fitted on one user's sparse log spends its
        always-on features (bias, daypart, season) as a "cards are usually not tapped" prior,
        so an unseen card comes back around p = 0.2 and would be demoted — and labelled
        "Learned from what you skip" — for cards that have never been on screen. Restricting
        the learned term to types the user has actually seen keeps every claim the why sheet
        makes true, and leaves everything else on the untouched v1 score.
        """
        if not self.ready or not self.seen(card_type):
            return COLD_START_P
        return self.p_tap(features)

    def adjustment(self, card_type: str, features: dict[str, float]) -> float:
        """03 §Learning v2 — `0.2 * (p_tap - 0.5)`, hard-clamped to ±`ML_MAX`."""
        return clamp_adjustment(ML_WEIGHT * (self.predict(card_type, features) - 0.5))


def clamp_adjustment(value: float) -> float:
    """The bound, in one place so a test can point at it."""
    return max(-ML_MAX, min(ML_MAX, value))


def balance(examples: list[Example]) -> list[Example]:
    """Rescale the two classes to equal total weight.

    Without this the model is calibrated to the raw base rate — cards are far more often
    *not* tapped than tapped — so the bias term drifts negative and **every** card, including
    ones the user has never even seen, comes back with `p_tap` well under 0.5 and a small
    negative adjustment. Ranking-wise that is a harmless constant, but the why sheet would
    then tell a user "Learned from what you skip" about a card that has never been on screen.

    Balancing puts the untouched card back on the 0.5 prior, which is exactly the docs/03
    contract: `0.2 * (p_tap - 0.5)` is zero for a card the model has learned nothing about.
    """
    pos = sum(e.weight for e in examples if e.label >= 0.5)
    neg = sum(e.weight for e in examples if e.label < 0.5)
    if pos <= 0.0 or neg <= 0.0:
        return examples
    half = (pos + neg) / 2.0
    pos_scale, neg_scale = half / pos, half / neg
    return [
        Example(
            features=e.features,
            label=e.label,
            weight=e.weight * (pos_scale if e.label >= 0.5 else neg_scale),
        )
        for e in examples
    ]


def train(examples: list[Example], *, weights: dict[str, float] | None = None) -> dict[str, float]:
    """Deterministic SGD on the logistic loss with L2 decay and a weight clip.

    Fixed learning rate, fixed epoch count, examples consumed in the order given (the caller
    sorts by `Event.id`, which is insertion order). Same events in → same weights out; there
    is no RNG anywhere in this module.
    """
    w: dict[str, float] = dict(weights or {})
    if not examples:
        return w
    rows = balance(examples)
    for _ in range(EPOCHS):
        for ex in rows:
            z = 0.0
            for name, value in ex.features.items():
                weight = w.get(name)
                if weight:
                    z += weight * value
            gradient = (sigmoid(z) - ex.label) * ex.weight
            for name, value in ex.features.items():
                if value == 0.0:
                    continue
                current = w.get(name, 0.0)
                updated = current - LEARNING_RATE * (gradient * value + L2 * current)
                w[name] = max(-WEIGHT_CLIP, min(WEIGHT_CLIP, updated))
    return {k: round(v, 6) for k, v in sorted(w.items()) if abs(v) >= 1e-6}


# --------------------------------------------------------------------------- persistence
#
# The two functions below touch the DB (like `learning.apply_events`); everything above is pure.


def _event_time(ts: str | None, created_at: datetime | None) -> datetime:
    """The event's local time: the client `ts` when it parses, else the UTC row time in IST."""
    if ts:
        try:
            return parse_any(ts)
        except ValueError:
            pass
    if created_at is not None:
        aware = created_at if created_at.tzinfo else created_at.replace(tzinfo=UTC)
        return aware.astimezone(tz_for(DEFAULT_TZ))
    return datetime.now(tz_for(DEFAULT_TZ))


def _meta_urgency(meta: Any) -> float | None:
    if not isinstance(meta, dict):
        return None
    value = meta.get("urgency")
    if isinstance(value, (int, float)):
        return float(value)
    return None


def build_examples(
    rows: list[Any],
    *,
    personas: list[tuple[str, float]],
    affinity: Any = None,
) -> tuple[list[Example], dict[str, dict[str, float]], int]:
    """Turn the raw event log into labelled examples, oldest first.

    Every feature is computed **as of that event** — the counters are the running prefix
    totals for that card type, not today's totals — so the model is trained on what was
    actually knowable at the time.

    Implicit feedback needs negatives. A user who only ever taps produces only positive rows,
    and a model trained on those just raises every card equally. So each positive row is
    paired with one **sampled negative** on a card type the user has never engaged with,
    drawn by rotating deterministically through the sorted candidate list (no RNG). That is
    what makes "ten taps on `aqi`" mean *aqi rather than the others*, which is the whole
    point of the ranker.
    """
    from app.engine.catalog import CARD_TYPES, HERO_TYPE, affinity_map

    counters: dict[str, dict[str, int]] = {}
    last_ts: dict[str, float] = {}
    examples: list[Example] = []
    labelled = 0

    def relevance_of(card_type: str) -> float:
        if affinity is not None:
            return float(affinity(card_type))
        row = affinity_map(card_type)
        contribs = [w * row.get(pid, 0.0) for pid, w in [*personas, ("base", 1.0)]]
        if not contribs:
            return 0.0
        top = max(contribs)
        return min(1.0, top + 0.15 * (sum(contribs) - top))

    engaged: set[str] = {
        str(r.card_type) for r in rows if str(r.action) in POSITIVE_ACTIONS
    }
    candidates = sorted(t for t in CARD_TYPES if t != HERO_TYPE and t not in engaged)
    negative_cursor = 0

    for row in rows:
        card_type = str(row.card_type)
        action = str(row.action)
        when = _event_time(row.ts, row.created_at)
        now_ts = when.timestamp()
        counts = counters.setdefault(
            card_type,
            {"impressions": 0, "taps": 0, "expands": 0, "dismisses": 0, "pins": 0},
        )

        label: float | None = None
        weight = 1.0
        if action in POSITIVE_ACTIONS:
            label, weight = 1.0, POSITIVE_ACTIONS[action]
        elif action in NEGATIVE_ACTIONS:
            label, weight = 0.0, NEGATIVE_ACTIONS[action]

        if label is not None:
            shared = {
                "daypart": daypart_of(when),
                "season": season_of(when),
                "is_weekend": is_weekend_of(when),
                "personas": personas,
                "now_ts": now_ts,
            }
            examples.append(
                Example(
                    features=feature_vector(
                        card_type=card_type,
                        persona_match=relevance_of(card_type),
                        urgency=_meta_urgency(row.meta),
                        counters=dict(counts),
                        last_ts=last_ts.get(card_type),
                        **shared,
                    ),
                    label=label,
                    weight=weight,
                )
            )
            labelled += 1

            if label == 1.0 and candidates:
                other = candidates[negative_cursor % len(candidates)]
                negative_cursor += 1
                examples.append(
                    Example(
                        features=feature_vector(
                            card_type=other,
                            persona_match=relevance_of(other),
                            urgency=None,
                            counters=dict(
                                counters.get(other)
                                or {
                                    "impressions": 0,
                                    "taps": 0,
                                    "expands": 0,
                                    "dismisses": 0,
                                    "pins": 0,
                                }
                            ),
                            last_ts=last_ts.get(other),
                            **shared,
                        ),
                        label=0.0,
                        weight=1.0,
                    )
                )

        counter_name = {
            "impression": "impressions",
            "tap": "taps",
            "expand": "expands",
            "dismiss": "dismisses",
            "pin": "pins",
        }.get(action)
        if counter_name:
            counts[counter_name] += 1
        last_ts[card_type] = now_ts

    stats = {t: {"last_ts": v} for t, v in sorted(last_ts.items())}
    return examples, stats, labelled


def train_user(db: "Session", user_id: str) -> RankerModel:
    """Retrain one user's weights from their most recent `MAX_EVENTS` events.

    Called inline from `POST /events` when `ENGINE_ML=1`. Bounded by construction:
    at most `MAX_EVENTS * 2 * EPOCHS` sparse updates (~3 ms measured on the demo machine),
    so it does not need a background task.
    """
    from sqlalchemy import select

    from app.models.event import Event
    from app.models.ranker_weights import RankerWeights
    from app.models.user import User

    rows = list(
        db.execute(
            select(Event)
            .where(Event.user_id == user_id)
            .order_by(Event.id.desc())
            .limit(MAX_EVENTS)
        ).scalars()
    )
    rows.reverse()  # oldest first — the prefix counters depend on it

    user = db.get(User, user_id)
    personas = [
        (str(p["id"]), float(p.get("weight", 1.0)))
        for p in (user.personas or [])
        if isinstance(p, dict) and p.get("id")
    ]

    examples, stats, labelled = build_examples(rows, personas=personas)
    weights = train(examples)

    row = db.get(RankerWeights, user_id)
    if row is None:
        row = RankerWeights(user_id=user_id)
        db.add(row)
    row.weights = weights
    row.stats = stats
    row.n_events = labelled
    row.version = MODEL_VERSION
    row.trained_at = datetime.now(UTC)
    db.flush()
    return RankerModel(
        weights=weights, stats=stats, n_events=labelled, version=MODEL_VERSION
    )


def model_for(db: "Session", user_id: str) -> RankerModel | None:
    """Load a user's model for `api/home.py`. `None` when nothing has been trained yet."""
    from app.models.ranker_weights import RankerWeights

    row = db.get(RankerWeights, user_id)
    if row is None:
        return None
    return RankerModel(
        weights=dict(row.weights or {}),
        stats={k: dict(v) for k, v in (row.stats or {}).items()},
        n_events=int(row.n_events or 0),
        version=str(row.version or ""),
    )
