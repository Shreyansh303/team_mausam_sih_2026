# 03 · Personalization engine (normative)

Pure, deterministic Python module `backend/app/engine/`. Inputs → ranked cards with reasons.
No I/O inside the engine; providers/services supply data, the engine only ranks and explains.

## Inputs
- `UserProfile`: `personas: [{id, weight}]` (primary weight 1.0, others 0.7; max 3), `pins: set[type]`,
  `hidden: set[type]`, `engagement: {type: {impressions, taps, expands, dismisses, pins}}`,
  `saved_places: []`, `language`, `units`.
- `Context`: `now` (tz-aware local), `daypart`, `is_weekend`, `season`, `location{lat, lon,
  district, state, is_coastal, elevation_m}`, `active_warnings[]`, `scenario`.
- `Snapshot`: unified weather/air/marine/derived data (05).
- `Catalog`: card definitions from 02 (affinities, gates, multipliers, urgency fn, builder).

## Algorithm
```
for card in catalog:
    if card.type in profile.hidden: continue
    if not card.gate(snapshot, context, profile): continue        # e.g. coastal, has places
    rel  = relevance(card, profile)                                # 0..1
    ctx  = clamp(card.time_mult(context) * card.season_mult(context), 0.4, 1.6)
    urg  = card.urgency(snapshot, context)                          # 0..1
    eng  = engagement_adj(profile.engagement.get(card.type))        # -0.25..+0.25
    score = 0.5 * rel * ctx + 0.5 * urg + eng
    pinned = card.type in profile.pins or urg >= 0.8
    if ENGINE_ML and not pinned:                                    # v2, see §Learning (v2)
        score += clamp(0.2 * (p_tap - 0.5), -0.1, +0.1)             # bounded; urg is untouched
    reasons = explain(card, rel, ctx, urg, eng, context, profile)
    build card payload via card.builder(snapshot, context, profile, language)

relevance(card, profile):
    contribs = [uw * card.affinity[p] for (p, uw) in profile.personas + [("base", 1.0)]]
    return min(1.0, max(contribs) + 0.15 * (sum(contribs) - max(contribs)))

engagement_adj(stats):
    if not stats: return 0
    x = stats.taps + 2*stats.expands + 3*stats.pins - 3*stats.dismisses
    return 0.25 * tanh(x / 8)
```
Ordering (stable, deterministic; ties broken by catalog order):
1. `pinned` cards sorted by urgency desc, then score desc (warnings ≥ orange always land here).
2. `current_conditions` hero.
3. Ranked cards by score desc — the first **8** are `cards`; the rest go to `more_cards`
   (rendered collapsed under "More for you"). Cards with `score < 0.12` also go to `more_cards`.
4. Hidden cards are listed in `hidden_types` so the app can offer "Restore".

## Explainability
Each card carries up to 4 `reasons` `{code, text}` chosen in this order, localized by backend:
- `persona:<id>` when that persona is the max contributor and rel ≥ 0.45 → "Because you follow Health".
- `urgency:<type>:<level>` when urg ≥ 0.3 → card-specific text ("AQI is Very Poor right now").
- `time:<daypart>` when time_mult ≥ 1.2 ("Morning commute window"); `season:<s>` when season_mult ≥ 1.2.
- `location:coastal` for gated marine cards; `places:saved` for traveler cards.
- `engagement:up` / `engagement:down` when |eng| ≥ 0.08 ("You often open this" / "You dismissed this before").
- `learning:up` / `learning:down` when |ml| ≥ 0.01 — v2 only, and it carries the signed value the
  ranker actually applied: "Learned from your taps (+0.04)". Never emitted with `ENGINE_ML=0`.
- `pinned:user` / `pinned:urgent`.

## Learning (v1, shipped)
Events from the app (`POST /events`): `impression, tap, expand, dismiss, pin, unpin, hide, unhide`.
Stored per user per card type (guests included via their guest token). `dismiss` = "show less".
Effect is immediate on next `/home`. `hide` removes the card until `unhide`. Visible in demo after
2 dismisses (−0.12) or 1 pin (pinned).

## Learning (v2, shipped behind `ENGINE_ML=1`)
Per-user logistic regression predicting `p_tap` from the events already logged by `POST /events`,
blended into the score as `score += 0.2 * (p_tap - 0.5)`. **v1 is the default and the fallback**:
with `ENGINE_ML=0` (the default) `/home` is byte-identical to v1 and `engine/ml.py` is never
called. Code: `backend/app/engine/ml.py`; weights in `ranker_weights` (`models/ranker_weights.py`).

**No new dependency.** numpy is not pinned, so the model is plain-Python sparse SGD over a
`{feature_name: value}` dict. scikit-learn was not added — the feature vector is ~15 non-zero
entries and training is capped, so a library would buy nothing and cost a wheel on every deploy.

**Features** (identical at training and prediction time; `feature_vector()`):

| block | features | notes |
|---|---|---|
| card | `type:<card_type>` | one-hot, 33 types |
| time | `daypart:<d>`, `season:<s>`, `weekend` | from the *event's own* `ts` when training, from `Context.now` when predicting |
| persona | `persona:<id>` (value = persona weight), `persona_match` | `persona_match` is the v1 `relevance` for this card |
| urgency | `urg:low\|medium\|high\|unknown` | reconstructable from a logged event only when the client sends `meta.urgency`; every event today lands in `urg:unknown`, so the real bands train to 0 and contribute nothing until the app sends it |
| history | `hist_tap_rate`, `hist_expand_rate`, `hist_dismiss_rate` (÷ `impressions+1`), `hist_pinned`, `hist_volume` = `tanh(impressions/10)` | the per-user, per-card-type counters, as rates so heavy and light users share a scale |
| recency | `recency` = `exp(-age_days / 7)` | since this card type was last interacted with |
| bias | `bias` | |

`is_coastal` from the original sketch is **not** a feature: it is a hard gate in the catalog, not
a preference, and it is not recoverable from a logged event.

**Labels and the training set.** Each logged event is one example, with the features computed as
of that event (running prefix counters, not today's totals): `tap`/`expand`/`pin` → 1 (weights
1/1/2), `impression`/`dismiss`/`hide` → 0 (weights 1/2/3); `unpin`/`unhide` are corrections and
are skipped. Implicit feedback needs negatives, so **each positive is paired with one sampled
negative** on a card type the user has never engaged with, drawn by rotating deterministically
through the sorted candidate list — no RNG anywhere. The two classes are then rescaled to equal
total weight, which is what keeps an untouched card on the 0.5 prior instead of inheriting the
"cards are usually not tapped" base rate.

**Update rule.** SGD on the logistic loss, `w -= 0.15 * ((sigmoid(w·x) - y) * weight * x + 0.002 * w)`,
5 epochs over the most recent 300 events, weights clipped to ±5 and rounded to 6 dp on save.
Deterministic: fixed learning rate, fixed epochs, examples consumed in `Event.id` order — the same
log always trains to the same weight vector. Training runs **inline on `POST /events`** (15 ms at
the 300-event cap; a 100-event batch round-trips in under 20 ms), so there is no worker.

**Cold start, twice over.** `p_tap = 0.5` — exactly zero contribution — until the user has at
least **8** labelled events (`MIN_EVENTS`), *and* per card type: a type this user has never
interacted with also stays at 0.5. The second guard is about honesty rather than accuracy. A
model fitted on one sparse log spends its always-on features as a "cards are usually not tapped"
prior, so an unseen card comes back around `p = 0.2` and would be demoted — and labelled "Learned
from what you skip" — for a card that has never been on screen.

**The bounds** (`tests/test_ml.py` proves each one):
1. The term is clamped to **±0.1** (`0.2 * (p_tap - 0.5)` with `p_tap ∈ (0,1)`, plus an explicit
   `clamp_adjustment`), so no learned preference moves a card by a tenth of a score point.
2. It is added to `score` only, **never to `urgency`** — so it cannot push a card past the
   `urgency >= 0.8` pin threshold.
3. It is applied **only to cards that are not pinned** (and not to the hero, which is lifted out
   of the ranking anyway). §Ordering renders the whole pinned block above `cards`, so a card the
   model loves cannot outrank a pinned orange or red warning — structurally, not by arithmetic.

`POST /me/reset-learning` and `POST /admin/reset-user` delete the weights row along with the
counters, prefs and event log. `GET /health` reports `engine.ml`; `GET /admin/state` reports
`engine_ml`.

## Context derivation
- `now` = query `now_override` (ISO) if given (demo), else server time converted to the location tz.
- `season` from month (02). `daypart` from hour (02). `is_weekend` = Sat/Sun.
- `is_coastal`: within 40 km of any point in `data/coastal_points.json` OR marine provider returns
  non-null wave height. `elevation_m` from forecast API.
- `active_warnings` = provider warnings (IMD when available) + admin-injected + scenario, filtered
  to the location's district/state or within 75 km, and `valid_to > now`.

## Tests required (`backend/tests/test_engine.py`)
1. Determinism: same inputs → identical order and scores.
2. Red warning is pinned first for every persona.
3. Coastal gating: Goa shows `sea_conditions`, Delhi does not.
4. Persona switch changes top-3 (health vs fitness vs agriculture).
5. Time-of-day: parent at 07:30 weekday ranks `school_commute` in top 3; at 22:00 it does not.
6. Two dismisses lower a card's score by ≥ 0.1; pin puts it in the pinned section.
7. Every persona alone yields ≥ 3 of its own cards (per coverage list in 02) in the top 8 under
   the `clear_pleasant` scenario.
8. Hidden card never appears; `hidden_types` lists it.
9. Payload of `/home` for each persona validates against the Pydantic models (no None in
   required fields).

Learning v2 has its own file, `backend/tests/test_ml.py`: flag off → `/home` byte-identical and
`engine/ml.py` never reached · flag on with no events → byte-identical (cold start) · taps raise
`p_tap` and dismisses lower it · a maximally favourable model cannot outrank an orange/red warning
· reset clears the weights · the same events train to the same weights.
