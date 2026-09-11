# 08 · Pitch — SIH 2026 idea presentation

**Problem statement 26076 · Ministry of Earth Sciences / India Meteorological Department**
**Category: Software · Theme: Smart Automation · Team Mausam**

This is the source text for the idea-presentation deck
(`submission/TeamMausam_SIH2026_PS26076.pptx`) and for anything a team member has to say out loud.
**Every number below is measured, not estimated**, and each one names where it was measured.
The evidence file is [`QA_REPORT.md`](QA_REPORT.md) — an end-to-end walk of the judge demo script
against a live backend and the real app build, verdict **PASS**. If a claim is not in this document,
do not make it on stage.

---

## 1 · Problem

> **Development of personalized homepage for 'Mausam' mobile application**
>
> - **Health-conscious users:** Highlight Air Quality Index (AQI), pollen count, UV index, and humidity levels to help users manage allergies, asthma, or skin sensitivity.
> - **Outdoor fitness enthusiasts:** Show sunrise/sunset times, 'best running hours,' wind speed, and heat alerts to optimize workout planning.
> - **Beachgoers & surfers:** Display sea conditions, tide timings, wave height, and water temperature for safe and enjoyable beach activities.
> - **Travelers:** Provide quick access to saved destinations, severe weather alerts for flights, and packing suggestions (e.g., 'Carry a raincoat in London').
> - **Parents & families:** Emphasize school commute conditions, rain alerts, and severe weather warnings to plan daily routines.
> - **Agriculture & gardeners:** Show soil moisture, rainfall predictions, frost alerts, and seasonal planting guidance.
> - **Commuters:** Integrate weather with traffic updates, visibility conditions, and alerts for storms or fog that affect travel.
> - **Event planners:** Offer extended forecasts, probability of rain, and 'comfort index' for outdoor gatherings or weddings.
>
> — SIH 2026, PS ID 26076, quoted verbatim in [`00_VISION.md`](00_VISION.md)

**What the statement is really asking for.** Mausam today shows the same screen to everyone: the
same numbers in the same order, whether you are an asthmatic in Delhi in November, a fisherman in
Panaji, or a parent deciding whether the school van will make it. The eight user groups above do not
want *more* data — they want **the two or three things that matter to them, first, with the "so
what" attached**. A farmer does not need to know the soil moisture is 0.28 m³/m³; he needs to know
whether to irrigate. A parent does not need a 24-hour rainfall table at 07:15; she needs to know
whether the 07:00–09:00 school run is safe.

**Why this is hard, and why a static "eight tabs" answer fails.** Relevance is not a property of the
user alone. It moves with the **hour** (the school-run card is decisive at 07:30 and noise at 22:00),
the **place** (tides and sea state matter in Panaji and are meaningless in Delhi), the **season**, and
above all with **what the sky is doing right now** — when a red heatwave warning is issued, *every*
persona needs to see it above their own preferences. A personalized homepage is therefore a
**ranking problem over live data**, not a settings screen.

---

## 2 · Proposed solution

A **persona-aware, context-aware, self-adapting home screen**, driven entirely by the server. A
FastAPI backend assembles a unified weather / air-quality / marine **snapshot** for the user's
coordinates, derives the insights the problem statement actually asks for (best running hours, a
school-run verdict, a tide window, frost risk, a packing list, a commute-delay estimate), and runs a
deterministic **personalization engine** over **33 card types**: it gates cards the user cannot use
(no tides inland, no heat alert below 35 °C), scores what is left as
`0.5 × relevance × context + 0.5 × urgency + learning`, pins anything urgent, and returns an
**ordered** home screen — `pinned` / `hero` / `cards` / `more_cards` — with up to four
human-readable **reasons per card**. The Flutter app renders that order, sends taps, pins and
dismissals back so the next screen is better, re-ranks live when a warning arrives over a WebSocket,
works from cache with no network, and speaks English and Hindi end to end — chrome *and* card copy.

The engine is ~460 lines of pure, I/O-free Python (scoring · context · explain · learning) over a
declarative card catalog, with the formula written in the docs before it was written in code
([`03_PERSONALIZATION_ENGINE.md`](03_PERSONALIZATION_ENGINE.md)), so it is fully unit
testable and fully explainable — the same two properties an operational agency needs before it will
put a ranker in front of the public.

---

## 3 · Uniqueness and differentiation

1. **Server-driven ranking — no app release to change the homepage.** The app never computes a
   score. `pinned / hero / cards / more_cards` arrives ordered from `GET /home`; nothing in the
   Flutter tree hardcodes a card order. IMD can add a card, reorder the feed, retire a card or
   change its copy from the backend, and every installed handset picks it up on the next refresh.
   This is the difference between a hackathon screen and something an agency can actually operate.
2. **Urgency outranks preference, and it is provable.** Any card whose computed urgency reaches
   0.8 is pinned above everything the user chose — a red warning reaches a beachgoer just as fast as
   it reaches a parent. `test_2_red_warning_is_pinned_first_for_every_persona` asserts it for all
   eight personas on every run.
3. **Explainable by construction.** Every card ships its own reasons from seven families
   (`persona:`, `urgency:`, `time:`, `season:`, `location:`, `engagement:`, `pinned:`), localized
   server-side. Long-press → *Why am I seeing this?* shows them, plus the card's score and what the
   ranker has learned about you. The app is not inventing the explanation; the engine ships it.
4. **It learns in front of you, and you can undo it.** `0.25 · tanh((taps + 2·expands + 3·pins −
   3·dismisses)/8)` — bounded at ±0.25 so learning can never override a warning. Measured live:
   three "Show less" taps moved `pollen` from rank 3 (score 0.470) to rank 8 (0.268) and into
   "More for you"; `POST /me/reset-learning` restored it to rank 3 / 0.470 exactly.
5. **Honest data, enforced.** Tides, pollen and traffic are modelled and say so — `"source":
   "estimated"` in the payload, an **Estimated** chip in the UI, and on tides a disclaimer naming
   INCOIS and the Survey of India. IMD's own endpoints returned `401` (IP not whitelisted) for the
   entire QA run and the app never once pretended otherwise; `GET /health` reports provider status
   truthfully. A weather product that guesses without saying so is worse than one that says
   "unknown".
6. **Built for the phone people actually have.** `?lite=1` drops `more_cards`, trims the hourly
   array to 12 and radar frames to 3, and turns radar tiles off on both the card and the map —
   payload **34.5 KB → 13.5 KB**. Offline, the last home renders from an on-device cache with an
   honest freshness chip. minSdk 24 (Android 7.0). 48 dp targets, TalkBack labels and a
   WCAG-AA contrast test that runs over the whole home screen in CI.
7. **Multilingual to the sentence, not just the buttons.** Under `?lang=hi`, 91 of 96 card strings
   render in Devanagari — titles, subtitles, headlines, advice bullets, reason chips, crop actions
   and date labels — with **zero** raw i18n keys leaking. The five exceptions are numeric readouts
   with unit symbols (`38 km/h WNW`), deliberately left in Latin.

---

## 4 · Technical approach

### Stack

| Layer | Choice | Why |
|---|---|---|
| Mobile | **Flutter 3.47** (Android / iOS / web), Riverpod, go_router, Dio, flutter_map, fl_chart, ARB i18n | one codebase, runs on low-end Android, strong re-rank animation |
| Backend | **FastAPI**, Python 3.13, Pydantic v2, httpx, SQLAlchemy 2 | the engine and the derived metrics are numeric rules code; one language for both, and for the optional ML ranker |
| Engine | pure Python, no I/O — catalog · context · scoring · explain · learning · 33 builders | deterministic and unit-testable; the same input always produces the same screen |
| Storage | **SQLite** by default, PostgreSQL when `DATABASE_URL` is set | zero-setup demo, production path preserved |
| Cache | in-process TTL cache, Redis when `REDIS_URL` is set | forecast 10 min · air 15 min · marine 30 min · geocode 24 h |
| Live alerts | **WebSocket** `/ws/alerts` (FCM documented as the production transport) | demoable with no Firebase project; the app re-ranks on the message |
| Auth | guest tokens + demo OTP, JWT HS256 | mirrors Mausam's OTP flow with no SMS vendor |
| Deploy | Docker + `infra/docker-compose.yml`, Render/Railway free tier; APK from local build or a GitHub Actions artifact | judges sideload the APK, backend URL is editable in Settings |

**No API key is required for the default setup.** Nothing in the repo depends on IMD being
reachable.

### Request path

```
Flutter app ──GET /api/v1/home?lat&lon&personas&lang&now_override&scenario&lite──▶ FastAPI
                                                                                    │
   snapshot assembly (cached upstream calls)  IMD → Open-Meteo → estimated ◀─────────┤
   derived metrics (CPCB AQI, comfort, workout windows, school run, commute,         │
                    frost, packing, planting, tides*, pollen*, traffic*)  *estimated │
   engine: gate → relevance → context multiplier → urgency → learning → score        │
   explain (≤ 4 reasons/card) → builders → localized card payloads                   │
                                                                                    ▼
        { banner, pinned[], hero, cards[], more_cards[], hidden_types[],
          freshness, sources, engine, context, location }
Flutter app ◀── ranked, localized, ready to draw. The app computes nothing. ──────────┘

POST /events  (impression·tap·expand·dismiss·pin·unpin·hide·unhide, batched ≤ 100)  ──▶ learning
WS /ws/alerts (hello · ping · warning_issued{affects_you} · warning_cleared ·
               scenario_changed · now_override)                                     ──▶ re-rank
```

### The scoring formula, in full

```
gate    drop hidden cards and cards whose precondition fails
        (coastal for tides · an active warning for the warnings card ·
         a saved place for packing · feels_like ≥ 35 for heat)
rel     min(1, max(contribs) + 0.15 · (sum(contribs) − max(contribs)))
        contribs = persona weight × card affinity; primary 1.0, others 0.7, base 1.0
ctx     clamp(time_multiplier × season_multiplier, 0.4, 1.6)
urg     computed from the data itself — AQI Very Poor 0.75, red heatwave 1.0,
        dense fog 0.8, a calm sea 0
eng     0.25 · tanh((taps + 2·expands + 3·pins − 3·dismisses) / 8)      ∈ [−0.25, +0.25]
score   0.5 · rel · ctx + 0.5 · urg + eng
pinned  card in user pins, or urg ≥ 0.8
order   pinned (urgency desc, then score desc) → current_conditions hero →
        top 8 by score → the rest into "More for you"; ties broken by catalog order
```

### Data sources (probed, with status)

| Source | Status | Used for |
|---|---|---|
| IMD `current_wx_api` · `nowcastapi` · `warnings_district_api` · `aws_data_api` | **401 — needs IP/domain whitelisting**; the provider detects it, backs off 10 min and falls through | station observations, 3-h nowcast, district warnings |
| Open-Meteo forecast / air quality / marine / geocoding | keyless, 200 | current, hourly, 16-day, UV, visibility, soil moisture & temperature, sunrise/sunset; PM2.5/PM10/O₃/NO₂/SO₂/CO → **CPCB** AQI scale; waves, swell, SST; place search |
| BigDataCloud reverse geocoding · RainViewer | keyless, 200 | lat/lon → district/state; radar frames and tiles |
| CPCB via data.gov.in · TomTom traffic | optional, free key | station AQI / real traffic flow — **estimated** without them |

Provider chain per field is **IMD → Open-Meteo → estimated**, and every value records its `source`.

---

## 5 · Feasibility and viability

**This is not a mock-up. It is a running system, and it has been walked end to end.**

[`QA_REPORT.md`](QA_REPORT.md) is a 378-line evidence file: every one of the ten steps of the judge
demo script was driven through the **real Flutter web build against a real local backend on live
weather data**, and read back out of the app's own accessibility tree rather than out of the code
that was supposed to produce it. **Verdict: PASS — all ten steps.** Nine defects were found *by
looking at the demo*, and all nine are fixed, each with a regression test that fails if it returns.

| Verified | Number | Where |
|---|---|---|
| Backend tests, fully offline (upstream payloads replayed through `respx`) | **348 passed** | `pytest -q` |
| App tests · static analysis | **103 passed** · `flutter analyze` clean | `flutter test` |
| Demo steps walked end to end | **10 of 10 PASS** | QA_REPORT §Results per demo step |
| Scenario overlays, each verified to render with the right cards pinned | **10 of 10** | QA_REPORT §Scenario overlays |
| Card types · renderers | **33** · **15** | `backend/app/engine/catalog.py` |
| Personas | **8**, 1–3 selectable | QA_REPORT step 3 — all eight photographed |
| Languages offered · complete | **5** · **2** (en, hi — 604 backend + 353 app strings each) | QA_REPORT step 8 |
| Cities in the offline gazetteer | **212** (106 popular), 102 coastal points | `backend/app/data/` |
| Warm `/home` | **2 ms** server-side · **4.6 ms** median round trip · **3.6 ms** under `lite=1` | QA_REPORT §Headline numbers |
| `/home` on the first request after a live warning push | **17.7 ms** | QA_REPORT step 5e |
| Payload | **34.5 KB** full, **13.5 KB** under `lite=1` (target < 60 KB) | measured 2026-09-09 |
| Learning: "Show less" taps to demote a card out of the feed | **3** (rank 3 → 8, score 0.470 → 0.268) | QA_REPORT step 6c |
| Release APK | **62 496 756 B**, 3 ABIs, minSdk 24 / targetSdk 36 | QA_REPORT §Release APK |
| CI | `backend` and `flutter` workflows both green on GitHub; the flutter job uploads a release APK and a web bundle | `.github/workflows/` |
| QA screenshots | **40** (`assets/screenshots/01`–`40`) | QA_REPORT |

**Operational viability.** Zero-setup by design: no API key, no Docker daemon, no database server
for the demo, SQLite on first boot, and a Docker/Render path for deployment. The engine has no I/O,
so scaling `/home` is scaling a cache in front of a handful of upstream calls — the warm path never
leaves the process.

### Risks and how each is already handled

| Risk | Mitigation, already in the repo |
|---|---|
| **IMD APIs need whitelisting** and answer `401` from any un-approved host | `providers/imd.py` is written against the real endpoints, detects the `401`, backs off 10 min and falls through to Open-Meteo. `README.md` §IMD integration path documents the exact request to file (static IP/domain, the four endpoints, the rate, and a request for the unpublished district-id list). The moment access is granted, `GET /health` reports `imd = available` and IMD warnings merge ahead of everything else — **no code change**. |
| A judged demo depends on the network | The offline path is a *feature* and is on the demo script: kill the backend and the home still renders from cache with an honest freshness chip; clear the cache too and it falls back to a bundled sample payload that labels itself "Sample data". |
| Modelled values could be mistaken for observations | `"source": "estimated"` on the value, an **Estimated** chip in the UI, and a disclaimer on tides. Enforced by convention (docs/00 principle 6, honest data) and visible in QA_REPORT step 4d. |
| A ranker that cannot be explained cannot be operated | Every card ships ≤ 4 reasons; the formula is normative in docs/03 and asserted by nine engine tests including determinism, warning-pinning, coastal gating and persona coverage. |
| Learning could bury a safety-critical card | The engagement term is bounded at ±0.25 and urgency ≥ 0.8 pins regardless. A user cannot dismiss their way out of a red warning. |

### Honest scope boundaries (say these before a judge finds them)

- The release APK has **not been installed on a physical device** — no phone and no emulator image
  on the build machine. Everything was verified in the **web build, which shares 100 % of the Dart
  code**, plus a static APK check (package id, label, SDKs, ABIs, permissions, signature). Say
  "verified in the web build and a static APK check", never "tested on a handset".
- The APK is **debug-signed**. It installs and runs; it is not a Play-store build, which needs a
  real keystore.
- **Marathi, Tamil and Bengali are best-effort** — 69 app and 54 backend keys each, falling back to
  English per key. Claim "5 languages offered, 2 complete", never "5 complete".
- Tides, pollen and traffic are **modelled**, not observed. That is stated on screen.
- The app does not fetch card preferences at start-up, so pins and hides survive a session but not
  a reinstall (a one-line change, listed under future scope).

---

## 6 · Impact and benefits

**Who benefits.** Mausam is the public face of India's national met service. Every bullet of the
problem statement is a group whose day is already shaped by the weather and who currently has to
read a generic screen and do the interpretation themselves. The prototype does that interpretation
server-side and puts the answer first.

| Persona | What now lands at the top of *their* screen | The cards behind it |
|---|---|---|
| **Health-conscious** | "Air quality is Severe (463) — move your workout indoors" | `aqi` (CPCB scale), `pollen`, `uv_index`, `humidity`, `health_advisory` |
| **Outdoor fitness** | "Best run: 06:00–07:30" with the AQI and heat index attached | `best_workout_window`, `sun_times`, `wind`, `heat_alert` |
| **Beachgoers & surfers** | "Sea is Very Rough — 4.5 m waves", next tide window, water temp | `sea_conditions`, `tides` (Estimated), `water_temp` |
| **Travellers** | "London · Raincoat / umbrella · rain chance up to 53 % in 3 days" | `saved_places` (local times), `travel_alerts`, `packing_suggestions` |
| **Parents & families** | "School run 07:00–09:00 · Caution" with the reasons, before 07:30 | `school_commute`, `rain_alert`, `warnings` |
| **Agriculture & gardeners** | Soil moisture, the rainfall outlook, tonight's frost risk, what to sow | `soil_moisture`, `rainfall_outlook`, `frost_alert`, `planting_guidance` (7 agro-zones × 12 months) |
| **Commuters** | "Severe impact on your commute (+22 min)", visibility 0.3 km, fog watch | `commute_conditions`, `visibility`, `storm_fog_alert` |
| **Event planners** | 14-day outlook, rain probability for the wedding date, comfort index | `extended_forecast`, `rain_probability`, `comfort_index` |

Every signal the problem statement names has a card. The mapping is machine-checked:
`PERSONA_COVERAGE` in `backend/app/engine/catalog.py`, asserted by docs/03 §Tests 7 on every test
run, and photographed per persona in QA_REPORT step 3.

**Benefits, in the order a judge will weigh them.**

- **Safety.** A warning at orange or above pins to the top for *every* persona and reaches connected
  clients over the WebSocket in milliseconds — measured: `/home` served **17.7 ms** on the request
  immediately after an admin push. The user does not have to be looking for the warning.
- **Time.** The answer is on the first screen instead of three taps down a menu of tables.
- **Trust.** Reasons on every card, provider status on `/health`, and "Estimated" wherever the value
  is modelled. Trust is the whole asset of a national met service, and it is the thing a
  personalization layer can most easily spend.
- **Reach.** Hindi complete to the sentence, three more languages started, low-bandwidth mode,
  offline cache, Android 7.0 and up, TalkBack labels, AA contrast, a large-text setting. The people
  who most need a frost alert or a fog warning are not on flagship phones.
- **Operability for IMD.** Server-driven cards mean the homepage is a backend deployment, not an app
  store release cycle. The IMD provider is already written; whitelisting flips it on.

---

## 7 · Future scope

Priority order; the same four are listed in the top-level `README.md` §13 Future Scope.

1. **FCM as the production alert transport.** The WebSocket is the demoable stand-in and proves
   the re-rank path end to end, but it only reaches an app that is open. Firebase Cloud Messaging
   delivers the same `warning_issued` payload to a backgrounded or closed app; the server-side
   broadcast point already exists (one place in the admin router), so this is a transport swap plus
   a Firebase project, not an architecture change. **This is the one that matters for a real
   deployment** — a warning that only reaches foregrounded apps is not a warning system.
2. **ML ranker v2.** Logistic regression over the events already being logged, predicting
   P(tap) from persona / daypart / season / urgency / coastal / card-type features, blended as
   `score += 0.2 · (p_tap − 0.5)` behind an `ENGINE_ML=1` flag, with the deterministic v1 formula
   staying as the fallback and the floor. Specified in docs/03 §Learning v2. The bound matters: an
   ML term that cannot exceed ±0.2 cannot bury a warning either.
3. **More languages.** Marathi, Tamil and Bengali are started (69 app / 54 backend keys with
   per-key fallback); completing them and adding the remaining scheduled languages is translation
   work, not engineering — the pipeline, the parity test and the fallback are already in place, and
   `test/l10n_test.dart` fails the build if a locale drifts.
4. **Android home-screen widget.** The single highest-visibility surface for a weather app, and
   the payload it needs (`hero` plus the top pinned card) is already exactly what `/home` returns
   under `?lite=1`.

**Smaller, near-term items** already identified:

- A **physical-device smoke test** of the release APK — first launch, the location-permission
  prompt, GPS onboarding and background event flushing are the only paths the web build cannot
  exercise.
- Seed the app's hidden/pinned state from `GET /me/card-prefs` at start-up so preferences survive a
  reinstall (one call in `main`).
- A **release keystore** and `key.properties` for a Play-store build.
- The **IMD whitelisting request** itself, and the district-id list that comes with it.

---

## 8 · Sources and evidence

| What | Where |
|---|---|
| Problem statement, personas, product principles, judge demo script | [`00_VISION.md`](00_VISION.md) |
| Stack decisions, probed data sources, non-functional targets | [`01_ARCHITECTURE.md`](01_ARCHITECTURE.md) |
| All 33 cards: affinities, gates, data shapes, insight and urgency rules | [`02_CARD_CATALOG.md`](02_CARD_CATALOG.md) |
| Scoring formulas, explainability, learning, required tests | [`03_PERSONALIZATION_ENGINE.md`](03_PERSONALIZATION_ENGINE.md) |
| REST + WebSocket contract (normative for both sides) | [`04_API_CONTRACT.md`](04_API_CONTRACT.md) |
| **End-to-end QA walk — every number in §5** | [`QA_REPORT.md`](QA_REPORT.md) |
| Where the build deviates from the specs, and why | [`DEVIATIONS.md`](DEVIATIONS.md) |
| Screenshots (40 from the QA walk) | `assets/screenshots/01`–`40` |
| Repository | <https://github.com/Shreyansh303/team_mausam_sih_2026> |

**Team Mausam** — Smart India Hackathon 2026, PS 26076 (MoES / IMD), category Software, theme Smart
Automation. *(Team roster: to be filled in by the team before submission — no member list is
recorded anywhere in this repository, and this document will not invent one. Individual
contributions are visible in the git history.)*

**Disclaimer, to be repeated on the title slide.** This is a **Team Mausam prototype built for
SIH 2026. It is not an IMD product and is not affiliated with or endorsed by IMD or MoES.** It uses
IMD's public colour conventions for warnings but no IMD logos or branding. The Android app id is
`com.teammausam.mausam_app` and its display name is "Mausam Personalized (Team Mausam prototype)".
