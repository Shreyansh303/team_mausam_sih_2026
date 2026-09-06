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
- `pinned:user` / `pinned:urgent`.

## Learning (v1, shipped)
Events from the app (`POST /events`): `impression, tap, expand, dismiss, pin, unpin, hide, unhide`.
Stored per user per card type (guests included via their guest token). `dismiss` = "show less".
Effect is immediate on next `/home`. `hide` removes the card until `unhide`. Visible in demo after
2 dismisses (−0.12) or 1 pin (pinned).

## Learning (v2, optional stretch — only if time remains after all phases)
Logistic regression (scikit-learn) predicting P(tap) from features `[persona one-hots, daypart
one-hot, season one-hot, urgency, is_coastal, card type one-hot]`, trained on synthetic + logged
events; blended as `score += 0.2 * (p_tap - 0.5)`. Ship behind `ENGINE_ML=1`.

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
