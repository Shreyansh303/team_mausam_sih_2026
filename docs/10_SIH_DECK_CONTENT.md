# 10 · SIH finale deck — slide-by-slide content

Content for the **6-slide SIH idea-presentation deck**, laid out the way selected finale decks are:
dense, quantified, diagram-led, every claim carrying a number and a source.

**Ground rule, same as the rest of this repo:** every number marked ✅ is measured in this
repository and traceable to [`QA_REPORT.md`](QA_REPORT.md) or a command you can re-run. Every number
marked ⚠️ is an **external statistic you must source and cite before printing** — a suggested
authority is named. Do not put an unsourced number on a slide; a judge will ask.

Measured on **2026-09-09**, commit `b528eaf`. Re-run `pytest -q` and `flutter test` before the final
print and update the two test counts if they have moved.

---

# SLIDE 1 · Title

Keep the mandated SIH fields exactly as the portal shows them. This slide is a form, not a canvas.

```
SMART INDIA HACKATHON 2026

Problem Statement ID    – 26076
Problem Statement Title – Development of personalized homepage for
                          'Mausam' mobile application
Theme                   – Smart Automation
PS Category             – Software
Team ID                 – <fill from portal>
Team Name               – Team Mausam
```

**Footer strip (small, one line, non-negotiable — say it before a judge asks):**
> Team Mausam prototype for SIH 2026. Not an IMD product; not affiliated with or endorsed by IMD or
> MoES. Uses IMD's public warning colour conventions, no IMD logos.

**Visual:** one phone mock at right showing the Parent home screen
(`assets/screenshots/c1_step03_persona_parent.png`), nothing else. Let slide 2 do the talking.

---

# SLIDE 2 · Idea, Solution & Prototype

**Slide title:** `MAUSAM PERSONALIZED — one screen, eight people, ranked live`

### Top band — the problem in one line

> Mausam shows **the same screen in the same order to everyone** — an asthmatic in Delhi in
> November, a fisherman in Panaji, and a parent deciding whether the school van will make it.
> The eight groups in the PS do not want *more* data. They want **the two or three things that
> matter to them, first, with the "so what" attached.**

### The insight (put this in a highlighted box — it is the intellectual core)

> **Relevance is not a property of the user.** It moves with the **hour** (the school-run card is
> decisive at 07:30 and noise at 22:00), the **place** (tides matter in Panaji, are meaningless in
> Delhi), the **season**, and above all with **what the sky is doing right now**.
> A personalized homepage is therefore a **ranking problem over live data — not a settings screen.**

### THE SOLUTION — 4 boxes with icons

| Box | Headline | Body |
|---|---|---|
| 1 | **Persona-aware ranking** | Users pick 1–3 of 8 personas. Every one of **33 card types** carries an affinity per persona; the engine returns an **ordered** feed, not a fixed list. ✅ |
| 2 | **Context-aware, not just role-aware** | Hour, weekday/weekend, IMD season, coastal vs inland, elevation and active warnings all move cards. A parent at 07:30 sees *School run* first; at 22:00 she does not. ✅ |
| 3 | **Urgency outranks preference** | Any card reaching urgency ≥ 0.8 pins above everything the user chose. A red warning reaches a beachgoer as fast as a parent — asserted for **all 8 personas on every test run**. ✅ |
| 4 | **Explainable + it learns** | ≤ 4 reasons per card from 7 families, localized server-side. Long-press → *Why am I seeing this?* Learning bounded at **±0.25** so it can never bury a warning. ✅ |

### WHY WE STAND OUT — 6 differentiators (this is the slide's centre of gravity)

1. **Server-driven — no app release to change the homepage.**
   The app computes **zero** scores. `pinned / hero / cards / more_cards` arrives ordered from
   `GET /home`. IMD can add, reorder, retire or re-word a card from the backend and every installed
   handset picks it up on the next refresh. ✅ *This is the difference between a hackathon screen and
   something an agency can operate.*

2. **A real ranking engine, written in the spec before the code.**
   `score = 0.5 · relevance · context + 0.5 · urgency + learning`, pure I/O-free Python over a
   declarative catalog, **deterministic** and unit-tested. ✅

3. **Honest data, enforced by convention.**
   Tides, pollen and traffic are modelled and **say so** — `"source": "estimated"`, an **Estimated**
   chip on screen, and a tides disclaimer naming INCOIS / Survey of India. IMD's endpoints returned
   `401` for the entire QA run and the app **never once pretended otherwise**. ✅

4. **Built for the phone people actually have.**
   `?lite=1` → payload **34.5 KB → 13.5 KB**. Offline home from on-device cache with an honest
   freshness chip. **minSdk 24 (Android 7.0)**, 48 dp targets, TalkBack labels, WCAG-AA contrast
   test in CI. ✅

5. **Multilingual to the sentence, not just the buttons.**
   Under `?lang=hi`, **91 of 96 card strings** render in Devanagari — titles, advice bullets, reason
   chips, crop actions, date labels — with **zero raw i18n keys leaking**. The 5 exceptions are
   numeric readouts (`38 km/h WNW`), deliberately Latin. ✅

6. **Live re-rank in milliseconds.**
   A warning pushed from the admin console reaches connected clients over `/ws/alerts`; `/home`
   answered in **17.7 ms** on the request immediately after the push. ✅

### PROTOTYPE — what is actually built and running (put a "RUNNING, NOT MOCKED" stamp here)

- **Flutter app** — onboarding, ranked home, **15 renderer kinds** across 33 card types, full-screen
  detail page each, radar map, saved places, settings, demo sheet, WebSocket client, offline cache,
  en/hi complete.
- **FastAPI backend** — provider chain, 33 card builders, the engine, auth, saved places, events,
  admin console, `/ws/alerts`, Docker + Render config, GitHub Actions CI.
- **Evidence:** `pytest -q` → **386 passed** ✅ · `flutter test` → **125 passed** ✅ ·
  `flutter analyze` → clean ✅ · **10/10 demo steps PASS** ✅ · **63 screenshots** ✅ ·
  **108 commits** ✅

**Visual:** the 3×3 persona screenshot grid from `README.md` — same morning, same location, only the
personas change. It makes the entire argument without a word.

---

# SLIDE 3 · Technical Approach

**Slide title:** `SERVER-DRIVEN RANKING OVER LIVE DATA`

### Main visual — the request path (draw this as the central diagram)

```
 Flutter app ──GET /api/v1/home?lat&lon&personas&lang&now_override&scenario&lite──▶ FastAPI
                                                                                      │
   ① SNAPSHOT ASSEMBLY (concurrent, cached)   IMD → Open-Meteo → estimated ◀───────────┤
        forecast · air quality · marine · radar · reverse geocode                      │
                                                                                       │
   ② DERIVED METRICS  CPCB AQI · NWS heat index · Magnus dew point · Douglas sea state │
        workout windows · school run · commute+traffic · frost · packing · planting    │
        tides* · pollen* · traffic*                                     *estimated     │
                                                                                       │
   ③ ENGINE  gate → relevance → context multiplier → urgency → learning → score        │
   ④ EXPLAIN (≤4 reasons/card) → 33 BUILDERS → localized card payloads                 │
                                                                                       ▼
        { banner, pinned[], hero, cards[], more_cards[], hidden_types[],
          freshness, sources, engine, context, location }
 Flutter app ◀────── ranked, localized, ready to draw. The app computes nothing. ───────┘

 POST /events   impression·tap·expand·dismiss·pin·unpin·hide·unhide (batched ≤100) ──▶ learning
 WS  /ws/alerts hello · ping · warning_issued{affects_you} · warning_cleared ·
                scenario_changed · now_override                                    ──▶ re-rank
```

### THE SCORING FORMULA (put this in a mono box — judges love seeing the actual maths)

```
gate    drop hidden cards + cards whose precondition fails
        (coastal for tides · active warning for warnings · saved place for packing
         · feels_like ≥ 35 for heat)
rel     min(1, max(contribs) + 0.15 · (Σcontribs − max(contribs)))
        contribs = persona weight × card affinity   primary 1.0 · others 0.7 · base 1.0
ctx     clamp(time_multiplier × season_multiplier, 0.4, 1.6)
urg     from the data itself — AQI Very Poor 0.75 · red heatwave 1.0 · dense fog 0.8 · calm sea 0
eng     0.25 · tanh((taps + 2·expands + 3·pins − 3·dismisses) / 8)        ∈ [−0.25, +0.25]
────────────────────────────────────────────────────────────────────────────────────────
score   0.5 · rel · ctx + 0.5 · urg + eng
pinned  card in user pins  OR  urg ≥ 0.8
order   pinned (urgency ↓, score ↓) → hero → top 8 by score → rest to "More for you"
```

### STACK — compact table

| Layer | Choice | Why |
|---|---|---|
| Mobile | **Flutter 3.47** (Android/iOS/web) · Riverpod · go_router · Dio · flutter_map · fl_chart · ARB | one codebase, runs on low-end Android |
| Backend | **FastAPI** · Python 3.13 · Pydantic v2 · httpx · SQLAlchemy 2 | the engine is numeric rules code |
| Engine | pure Python, **no I/O** — catalog · context · scoring · explain · learning · 33 builders | deterministic, unit-testable, explainable |
| Storage | **SQLite** default → PostgreSQL via `DATABASE_URL` | zero-setup demo, production path kept |
| Cache | in-process TTL → Redis via `REDIS_URL` | forecast 10 m · air 15 m · marine 30 m · geocode 24 h |
| Live alerts | **WebSocket** `/ws/alerts` (FCM = production transport, designed) | demoable with no Firebase project |
| Auth | guest token + demo OTP, JWT HS256 | mirrors Mausam's OTP flow, no SMS vendor |
| Deploy | Docker · `infra/render.yaml` · APK via GitHub Actions artifact | judges sideload the APK |

> **No API key is required for the default setup. Nothing depends on IMD being reachable.** ✅

### DATA SOURCES — probed, with real status (do not hide the 401; own it)

| Source | Status | Used for |
|---|---|---|
| IMD `current_wx_api` · `nowcastapi` · `warnings_district_api` · `aws_data_api` | **401 — needs IP whitelisting.** Provider detects it, backs off 10 min, falls through | station obs, 3-h nowcast, district warnings |
| Open-Meteo forecast / air / marine / geocoding | keyless **200** | current + hourly + 16-day, UV, visibility, soil moisture & temp, sunrise/sunset; PM2.5/PM10/O₃/NO₂/SO₂/CO → **CPCB scale**; waves, swell, SST |
| BigDataCloud reverse geocode · RainViewer | keyless **200** | lat/lon → district/state; radar frames + tiles |
| CPCB via data.gov.in · TomTom traffic | optional free key | station AQI / real traffic — **estimated** without them |

Chain per field is **IMD → Open-Meteo → estimated**, and **every value records its `source`.** ✅

### Offline assets that make it work in a village
**212 cities** (106 popular) · **102 coastal points** · **7 agro-zones × 12 months** planting
calendar · **10 scenario overlays** for demo. ✅

---

# SLIDE 4 · Feasibility & Viability

**Slide title:** `NOT A MOCK-UP — A RUNNING SYSTEM, WALKED END TO END`

### Banner box (top, high contrast)

> [`QA_REPORT.md`](QA_REPORT.md) is a **378-line evidence file**. Every one of the **10 steps of the
> demo script** was driven through the **real Flutter build against a real backend on live weather
> data**, and read back out of the **app's own accessibility tree** — not out of the code that was
> supposed to produce it. **Verdict: PASS, 10/10.**
> **9 defects were found by looking at the demo. All 9 fixed, each with a regression test.** ✅

### THE EVIDENCE TABLE (this is the slide — make it big)

| Verified | Number |
|---|---|
| Backend tests, fully offline (upstream replayed via `respx`) | **386 passed** ✅ |
| App tests · static analysis | **125 passed** · `flutter analyze` clean ✅ |
| Demo steps walked end to end | **10 / 10 PASS** ✅ |
| Scenario overlays, each verified to pin the right cards | **10 / 10** ✅ |
| Card types · renderer kinds · personas | **33** · **15** · **8** ✅ |
| Warm `/home` | **2 ms** server-side · **4.6 ms** median round trip · **3.6 ms** under `lite=1` ✅ |
| `/home` on the first request after a live warning push | **17.7 ms** ✅ |
| Payload | **34.5 KB** full → **13.5 KB** lite (target < 60 KB) ✅ |
| Languages offered · complete | **5** · **2** (en, hi — 606 backend + 353 app strings each) ✅ |
| Cities · coastal points in the offline gazetteer | **212** · **102** ✅ |
| Learning: "Show less" taps to demote a card out of the feed | **3** (rank 3 → 8, score 0.470 → 0.268); `reset-learning` restored it exactly ✅ |
| Release APK | **62.5 MB**, 3 ABIs, minSdk 24 / targetSdk 36 ✅ |
| CI | `backend` + `flutter` workflows **both green**; flutter job uploads a release APK ✅ |

### FOUR FEASIBILITIES (mirror the reference deck's structure)

| | |
|---|---|
| **Technical** | Already built and green in CI. The engine has **no I/O**, so scaling `/home` is scaling a cache in front of a handful of upstream calls — the warm path never leaves the process (**2 ms**). ✅ |
| **Operational** | **Zero-setup by design**: no API key, no Docker daemon, no DB server for the demo; SQLite on first boot; Render blueprint for deployment. A new machine goes from `git clone` to a green test suite with one script. ✅ |
| **Economic** | Every data source in the default path is **keyless and free**. Optional paid sources (TomTom traffic, CPCB) degrade to labelled estimates rather than breaking. Hosting fits a free Render web service for the demo. ✅ |
| **Institutional** | Server-driven cards mean the homepage is a **backend deployment, not an app-store release cycle** — the constraint that actually governs a government app. The IMD provider is written; whitelisting flips it on with **no code change**. ✅ |

### RISKS → MITIGATION (already in the repo, not aspirational)

| Risk | Mitigation |
|---|---|
| **IMD APIs need whitelisting**, answer `401` from any un-approved host | `providers/imd.py` is written against the real endpoints, detects the 401, backs off 10 min, falls through. `README.md` documents the exact request to file. On approval `/health` reports `imd = available` and IMD warnings merge first — **no code change**. |
| A judged demo depends on the network | The offline path **is a demo step**: kill the backend, the home still renders from cache with an honest freshness chip; clear the cache too and it falls back to a bundled sample that labels itself "Sample data". |
| Modelled values mistaken for observations | `"source": "estimated"` + **Estimated** chip + tides disclaimer. Enforced by convention (docs/00 principle 6, honest data), photographed in QA step 4d. |
| A ranker that cannot be explained cannot be operated | ≤ 4 reasons per card; formula normative in docs/03; **9 engine tests** including determinism, warning-pinning, coastal gating, persona coverage. |
| Learning could bury a safety-critical card | Engagement bounded **±0.25**; urgency ≥ 0.8 pins regardless. **A user cannot dismiss their way out of a red warning.** |

### HONEST SCOPE BOUNDARIES (say these before a judge finds them — it buys credibility)

- The release APK has **not been installed on a physical device**. Everything was verified in the
  **web build, which shares 100 % of the Dart code**, plus a static APK check. Say *"verified in the
  web build and a static APK check"*, never *"tested on a handset"*.
- The APK is **debug-signed** — installs and runs, not a Play-store build.
- **Marathi, Tamil, Bengali are best-effort** (69 app / 54 backend keys, per-key English fallback).
  Claim *"5 offered, 2 complete"*, never *"5 complete"*.

---

# SLIDE 5 · Impact & Benefits

**Slide title:** `EIGHT GROUPS, EIGHT DIFFERENT FIRST SCREENS`

### PERSONA IMPACT TABLE — every PS bullet mapped to a shipped card

| Persona | What now lands at the top of *their* screen | Cards behind it |
|---|---|---|
| **Health-conscious** | "Air quality is Severe (463) — move your workout indoors" | `aqi` (CPCB), `pollen`, `uv_index`, `humidity`, `health_advisory` |
| **Outdoor fitness** | "Best run: 06:00–07:30" with AQI and heat index attached | `best_workout_window`, `sun_times`, `wind`, `heat_alert` |
| **Beachgoers & surfers** | "Sea is Very Rough — 4.5 m waves", next tide window, water temp | `sea_conditions`, `tides` (Estimated), `water_temp` |
| **Travellers** | "London · Raincoat/umbrella · rain chance up to 53 % in 3 days" | `saved_places`, `travel_alerts`, `packing_suggestions` |
| **Parents & families** | "School run 07:00–09:00 · Caution", with reasons, before 07:30 | `school_commute`, `rain_alert`, `warnings` |
| **Agriculture & gardeners** | Soil moisture, rainfall outlook, tonight's frost risk, what to sow | `soil_moisture`, `rainfall_outlook`, `frost_alert`, `planting_guidance` |
| **Commuters** | "Severe impact on your commute (+22 min)", visibility 0.3 km, fog watch | `commute_conditions`, `visibility`, `storm_fog_alert` |
| **Event planners** | 14-day outlook, rain probability for the wedding date, comfort index | `extended_forecast`, `rain_probability`, `comfort_index` |

> **Every signal the PS names has a card, and the mapping is machine-checked** — `PERSONA_COVERAGE`
> in `catalog.py`, asserted on every test run, photographed per persona in QA step 3. ✅

### A LIVE JOURNEY (mirror the reference deck's stakeholder narrative — draw as a 5-step flow)

```
IMD / admin issues an ORANGE THUNDERSTORM warning for Delhi
        │
        ▼
Backend merges it into the snapshot, urgency = 0.8 → PINNED for every persona
        │
        ▼
/ws/alerts pushes warning_issued{affects_you:true} to every connected client
        │
        ▼
Parent's phone: orange banner appears, warning card ANIMATES to the top,
school-run verdict flips to "Avoid"        /home served in 17.7 ms ✅
        │
        ▼
The parent did not have to be looking for it. That is the whole point.
```

### BENEFITS, in the order a judge weighs them

| | |
|---|---|
| **Safety** | Orange+ pins to the top for *every* persona and reaches connected clients in **milliseconds** (17.7 ms measured). The user does not have to go looking for the warning. ✅ |
| **Time** | The answer is on the **first screen**, not three taps down a menu of tables. |
| **Trust** | Reasons on every card, provider status on `/health`, "Estimated" wherever modelled. **Trust is the entire asset of a national met service — and the thing a personalization layer can most easily spend.** |
| **Reach** | Hindi complete to the sentence · low-bandwidth mode (13.5 KB) · offline cache · **Android 7.0+** · TalkBack · AA contrast · large text. *The people who most need a frost alert or a fog warning are not on flagship phones.* ✅ |
| **Operability for IMD** | Server-driven cards = the homepage is a **backend deployment**, not a release cycle. The IMD provider is written; whitelisting flips it on. ✅ |

### NATIONAL-SCALE IMPACT — → [`11_IMPACT_NUMBERS.md`](11_IMPACT_NUMBERS.md)

**The external statistics for this slide are sourced and cited in
[`11_IMPACT_NUMBERS.md`](11_IMPACT_NUMBERS.md).** Use it directly; it is organised as five slide
blocks. Headlines:

- **Block A — the incumbent's own store page.** Mausam: **3.13 / 5** from 4.4k ratings, **~990k
  downloads** against **958M** Indian internet users = **~0.1% reach**. Its top reviews complain
  about exactly what this prototype fixes (no saved favourites, district-level only, charts not
  understandable, slow). *This is the strongest opening in the deck — it is not opinion.*
- **Block B — the harm.** Lightning **2,558 deaths (2023)** · fog road deaths **~15,115 (2024)** ·
  heat **733 (2024, independent count)** · **46%** of the workforce in agriculture, **51%** of net
  sown area rainfed.
- **Block C — the multiplier.** **24 h notice cuts damage 30%** (UN SG / GCA) · **1:9**
  benefit–cost · **23,000 lives + $162B/yr** globally available from better warnings.
- **Block D — "OUR PROMISE"** with the arithmetic visible: `0.30 × 18,406 ≈ 5,500 lives/yr` as an
  upper bound, the honest discount stated on the slide, and *"every 1% converted is 55 lives a
  year"* as the number a judge can hold.
- **Block E — growth.** 958M online, 1.14B smartphones, ~95% village 4G, rural growing **4×** urban
  — so distribution is not the constraint; **product experience is, and that is this PS.**

**The bridge sentence to say out loud:**
> *"India already has the warning. IMD issues it. The UN's own number for closing the last mile is
> 30% less damage and a 9:1 return. Our contribution is measured: from the moment a warning is
> issued it is pinned above every user's own preferences and served in **17.7 ms** — to a farmer, a
> beachgoer and a parent alike."*

The second half is measured ✅; only the first half needs a citation, which is why it lands.

**Two numbers to verify by hand before printing** (see 11 §Verify before printing): the MoRTH fog
fatality figure (press summaries conflate accidents with fatalities — screenshot the weather table)
and the Mausam store rating (dated screenshot; it drifts).

### Alignment (one line each, with logos)

- **UN SDG 3** Good Health & Well-being · **SDG 11** Sustainable Cities (resilience) ·
  **SDG 13** Climate Action (early warning)
- **UN "Early Warnings for All" (2027)** — the last-mile delivery problem is exactly this
- **Digital India / Bhashini** — regional-language delivery of government services

---

# SLIDE 6 · Research & References

Mirror the reference deck: clickable tiles, competitor analysis, proof documents.

### OUR WORK — link tiles

| Tile | Link |
|---|---|
| **GitHub repository** — full source, 108 commits, CI green | `github.com/Shreyansh303/team_mausam_sih_2026` |
| **QA evidence** — 10/10 demo steps, 9 defects found & fixed | `docs/QA_REPORT.md` |
| **Personalization engine spec** — formulas, tests, explainability | `docs/03_PERSONALIZATION_ENGINE.md` |
| **API contract** — REST + WebSocket, normative for both sides | `docs/04_API_CONTRACT.md` |
| **Card catalog** — all 33 cards, affinities, gates, urgency rules | `docs/02_CARD_CATALOG.md` |
| **Push design** — FCM as production alert transport | `docs/09_PUSH_NOTIFICATIONS.md` |
| **63 screenshots** — every persona, scenario, offline, Hindi | `assets/screenshots/` |

### STANDARDS & SCIENCE WE IMPLEMENT (not invented — cite them)

| What | Standard | Where used |
|---|---|---|
| Air Quality Index | **CPCB** National AQI, 6 bands, sub-index per pollutant | `services/aqi_cpcb.py` |
| Heat index | **NWS Rothfusz** regression + both adjustments | `services/comfort.py` |
| Dew point | **Magnus** formula | `services/comfort.py` |
| Sea state | **Douglas** scale | `services/marine.py` |
| Wind | **Beaufort** scale | `services/marine.py` |
| UV bands | **WHO** Global Solar UV Index | `builders/uv_index.py` |
| Warning colours | **IMD** yellow / orange / red convention | `AppTheme.warningSeverityColor` |
| Rainfall intensity bands | **IMD** classification | `builders/rain_alert.py` |
| Agro-zones | 7 Indian zones × 12 months | `data/planting_calendar.json` |

> Implementing the **national** standard rather than a global one is a differentiator: an Indian
> user sees the AQI number they see everywhere else in India.

### DATA SOURCES

| Source | Role |
|---|---|
| **IMD** `mausam.imd.gov.in/api` | Primary, whitelisting pending — station obs, nowcast, district warnings |
| **Open-Meteo** forecast / air-quality / marine | Fallback, keyless — the prototype runs on this today |
| **RainViewer** | Radar frames and tiles |
| **BigDataCloud** | Reverse geocoding |
| **CPCB** (data.gov.in) · **TomTom** | Optional, keyed — station AQI, real traffic flow |
| **INCOIS** / **Survey of India** | Named in the tides disclaimer as the authoritative source we are *not* using |

### COMPETITIVE LANDSCAPE — why this is not "just another weather app"

| Product | What it does | What it does **not** do |
|---|---|---|
| **Mausam (IMD, today)** | Authoritative Indian data, official warnings | One screen for everyone; no persona, no ranking, no explanation |
| **AccuWeather / Weather.com** | Polished global apps, some personalization | Not IMD-authoritative for India; no CPCB AQI; no agro/tide layer for Indian users; closed ranking |
| **Windy / Ventusky** | Excellent maps for enthusiasts | Expert-facing, not a citizen homepage; no warnings-first ranking |
| **Damini (lightning), Meghdoot (agri)** | IMD's own targeted apps — right idea, right audience | **Separate apps per audience.** Our approach is the inverse: one app that becomes the right app. |
| **Team Mausam** | Persona × context × urgency ranking, explainable, server-driven, offline, bilingual | — |

> **The Damini/Meghdoot point is the strongest competitive line in the deck**, because it is IMD's
> own evidence that different audiences need different things — and it shows the current answer is
> *more apps*, which is a distribution problem. A ranked homepage solves it inside the app people
> already have.

### ⚠️ MARKET / ADOPTION CONTEXT — source before printing

| Claim | Authority |
|---|---|
| Weather-app market size / CAGR | Grand View Research or MarketsandMarkets weather-forecasting-services report |
| India smartphone + rural internet users | **TRAI** subscription data |
| Government digital-services adoption | **Digital India** / MeitY dashboards |

---

## Design notes for whoever builds the slides

- **Density is correct for SIH.** The reference deck runs 1,700–3,100 characters per slide. Do not
  "clean it up" into six bullet points — judges score on substance and you get one slide per topic.
- **Every claim gets its number inline**, the way the tables above are written. A claim without a
  number reads as a wish.
- **Lead each slide with a diagram or the screenshot grid**, then let text wrap around it. Slides
  2 and 3 are diagram-led; 4 and 5 are table-led.
- **Colour code by IMD severity** where relevant (yellow `#F5C518`, orange `#F28C28`, red `#D32F2F`,
  green `#2E7D32`) — it signals domain literacy.
- **Keep the ✅ evidence claims and the ⚠️ external claims visually distinct** in your own working
  copy, then strip the marks before printing — but only after every ⚠️ has a citation.
- **The disclaimer line goes on slide 1 and nowhere else.** Once is honest; repeated is defensive.
- Re-run `pytest -q` and `flutter test` the morning of the presentation; if the counts moved,
  update slides 2 and 4.
