# Architecture

Team Mausam · SIH 2026 · PS 26076 (MoES / India Meteorological Department). This page is the
15-minute technical overview of the prototype. The numbered specs in this directory are the
normative detail; links to them are collected at the end.

## 1. System architecture

Two deployable parts. A **FastAPI backend** fetches weather, air-quality and marine data, derives
persona-specific insights, and runs a personalization engine that scores and ranks 33 card types
for the user in front of it. A **Flutter app** renders the ranked cards, explains why each one is
there, sends engagement events back, re-ranks live when a warning arrives over a WebSocket, works
offline from an on-device cache, and speaks English and Hindi (Marathi, Tamil and Bengali partial).
The app never computes ranking itself: the home screen is server-driven, so a card can be added or
reordered without an app release.

```
┌──────────────── Flutter app (Android / iOS / web) ─────────────────┐
│ Onboarding → Home (ranked cards) → Detail pages → Map → Places      │
│ Riverpod · Dio · JSON file cache (offline) · WS client · ARB i18n   │
└──────────────▲──────────────────────────────────────▲──────────────┘
               │ REST  /api/v1  (JSON, < 60 KB)        │ WS /ws/alerts
┌──────────────┴──────────────────────────────────────┴──────────────┐
│ FastAPI backend                                                     │
│  api/       health · locations · weather · auth · me · home ·       │
│             events · admin · ws                                     │
│  engine/    catalog (33 cards, affinities, gates, multipliers)      │
│             → context → scoring → explain → learning → builders     │
│  services/  snapshot assembly + derived metrics (CPCB AQI, comfort, │
│             workout windows, school run, commute, frost, packing,   │
│             planting, tides*, pollen*, traffic*)      *estimated    │
│  providers/ IMD (whitelist-aware) → Open-Meteo → scenario/mock      │
│             + RainViewer radar + geocoding                          │
│  core/      TTL cache · SQLite (Postgres via env) · JWT · i18n      │
│  static/    admin demo console (scenarios, demo clock, push warning)│
└─────────────────────────────────────────────────────────────────────┘
```

Stack: Flutter (stable 3.47.x) with Riverpod, go_router, Dio, flutter_map, fl_chart and ARB
localisation; FastAPI on Python 3.13 with Pydantic v2, httpx and SQLAlchemy 2. The reasoning per
choice, and what changed from the original brief, is in [01_ARCHITECTURE.md](01_ARCHITECTURE.md).

## 2. High-level flow

```
User (picks 1–3 personas, a location, a language)
  │
  ▼
Flutter app ── cached /home payload renders instantly (freshness chip)
  │
  ▼
GET /api/v1/home?lat&lon&personas&lang   (Bearer JWT: guest or demo OTP)
  │
  ▼
Snapshot assembly ── location resolve → forecast + air + marine (+ IMD) fetched concurrently,
  │                  each upstream behind a TTL cache; scenario overlay if one is active
  ▼
Derived metrics ── CPCB AQI, comfort, workout windows, school run, commute, frost, packing,
  │                planting, sea state, visibility, flight risk; tides/pollen/traffic "estimated"
  ▼
Personalization engine ── gate → relevance × context + urgency + learning → order → explain
  │
  ▼
Localized card payloads ── pinned[] · hero · cards[] · more_cards[] · banner · reasons per card
  │
  ▼
Flutter app ── renders by `renderer` kind, caches the payload, logs impressions/taps/dismissals
               back to POST /events (which changes the next ranking)

Side branch — live re-rank:
  Admin console ── POST /admin/warnings ── broadcast on WS /ws/alerts ── app receives
  `warning_issued` with `affects_you` ── banner → re-fetch /home → warning card animates to the top
```

## 3. Components

### 3.1 Flutter app (`app/`, package `mausam_app`)

- **Screens** (`lib/features/`): onboarding (language → persona tiles → location), home, a
  full-screen detail page per renderer, radar map (flutter_map, OSM tiles, RainViewer overlay),
  saved places, settings (language, units, personas, backend URL, low-bandwidth) and a demo sheet.
- **Home** (`lib/features/home/`): persona chips, warning banner, quick actions, pinned block, hero,
  ranked cards and a collapsed "More for you". Every card goes through one `card_shell` (severity
  accent bar, `Estimated`/`Pinned` chips, reason chips, overflow menu); 15 renderer kinds live in
  `renderers/` with a `generic` fallback for unknown card types. Long-press opens the why sheet.
- **State and data** (`lib/data/`): Riverpod providers over repositories; a Dio client with auth and
  language interceptors; `cache/json_file_cache.dart` keeps the last `/home` payload so a cold start
  with no network still renders, falling back to bundled `assets/fixtures/home_sample.json`.
- **Events**: `events_repo` batches `impression, tap, expand, dismiss, pin, unpin, hide, unhide`
  and flushes them every 10 s or on background (batch ≤ 100).
- **WebSocket client** (`lib/data/ws/alerts_socket.dart`): reconnect with backoff, `pong` replies,
  a `location` message when the user moves, and a stream the home page listens to.
- **i18n**: ARB files for the app chrome (`lib/l10n/app_{en,hi,mr,ta,bn}.arb`); all card copy is
  localized server-side via the `lang` parameter, so switching language re-fetches home.
- **Android extras**: a home-screen widget that shows the last payload's hero and top pinned card
  and refreshes itself about hourly (`lib/data/widget/`, [06_MOBILE_SPEC.md](06_MOBILE_SPEC.md)
  §Home-screen widget). App id `com.teammausam.mausam_app`, minSdk 24.

### 3.2 Backend API (`backend/app/api/`)

One router per concern, all mounted at `/api/v1` and again at the root: `health`, `auth`, `me`,
`places`, `locations`, `weather`, `home`, `events`, `devices`, `admin`, `ws`. Pydantic v2 schemas
in `schemas/` define the wire shapes; [04_API_CONTRACT.md](04_API_CONTRACT.md) is the normative
contract for both sides. `api/home.py` is the only place the engine is called from.

### 3.3 Personalization engine (`backend/app/engine/`)

Pure, deterministic Python with no I/O, so it is unit-tested end to end. Modules follow the
pipeline: `catalog.py` (the 33 card definitions with per-persona affinities, gates and time/season
multipliers) → `context.py` (daypart, weekend, IMD season, coastal/elevation, active warnings, demo
clock) → `scoring.py` → `explain.py` → `learning.py` (and the optional `ml.py`) → `builders/`
(one module per card type, producing the localized payload) → `home.py` (assembles the response).

The algorithm in ten lines:

1. **Gate** — drop cards the user hid and cards whose precondition fails (coastal for tides, an
   active warning for the warnings card, a saved place for packing, `feels_like ≥ 35` for heat).
2. **Relevance** — the strongest persona affinity for the card plus 15 % of the other personas'
   contributions, so a Parent + Commuter sees blended cards rather than two stacked lists.
   Primary persona weight 1.0, others 0.7, everyone also carries an implicit `base` persona.
3. **Context multiplier** — time-of-day × season, clamped to 0.4–1.6: the school run ×1.5 at dawn on
   a weekday, AQI ×1.2 in winter, tides never at midnight.
4. **Urgency** — computed from the data itself: AQI Very Poor 0.75, red heatwave warning 1.0, dense
   fog 0.8, calm sea 0.
5. **Learning** — `0.25 · tanh((taps + 2·expands + 3·pins − 3·dismisses) / 8)`, i.e. ±0.25.
6. **Score** = `0.5 · relevance · context + 0.5 · urgency + learning`.
7. **Pinned** = user-pinned, or urgency ≥ 0.8 — an orange/red warning outranks every preference.
8. **Order** — pinned (by urgency) → `current_conditions` hero → top 8 by score → the rest into
   `more_cards`; ties broken by catalog order, so the same input always produces the same screen.
9. **Explain** — up to four reasons per card from the families `persona:`, `urgency:`, `time:`,
   `season:`, `location:`, `engagement:`, `pinned:`, localized server-side.
10. **Test** — determinism, warning pinning, coastal gating, persona switching, time of day, the
    dismiss/pin effect and per-persona coverage are asserted in `backend/tests/`.

An optional second learner (`ENGINE_ML=1`) fits a per-user logistic regression on the logged events
and adds `0.2 · (p_tap − 0.5)` to the score, clamped to ±0.1 and never applied to urgency or pinned
cards, so it cannot lift a card above a warning. Off by default; the output is then byte-identical
to the rule-based ranker. Details: [03_PERSONALIZATION_ENGINE.md](03_PERSONALIZATION_ENGINE.md).

### 3.4 Services and derived metrics (`backend/app/services/`)

`snapshot.py` resolves the location, fetches forecast, air and marine data concurrently (IMD in
parallel when enabled), normalises them into one `Snapshot`, applies any active scenario overlay
and caches the result for 5 minutes keyed by rounded coordinates and scenario. Derived services:

| Service | Output | Basis |
|---|---|---|
| `aqi_cpcb.py` | AQI on the CPCB scale, dominant pollutant, category | pollutant sub-indices, linear interpolation inside each band |
| `comfort.py` | comfort index, heat index, dew point | NWS Rothfusz heat index, Magnus dew point |
| `workout.py`, `school_commute.py`, `commute.py` | best workout windows, school-run verdict, commute windows and delay | hourly forecast, user windows, traffic |
| `frost.py`, `planting.py`, `packing.py`, `flight_risk.py` | frost risk, crop stage and action, packing list per saved place, flight-risk level | daily forecast, agro-zone calendar |
| `marine.py`, `visibility.py`, `nowcast.py` | sea state (Douglas), surf/swim safety, visibility category, 3-h nowcast when IMD is unavailable | marine and hourly forecast |
| `warnings.py` | merged, location-filtered warnings | IMD (when available) + admin-pushed + scenario, sorted by severity |
| `tides.py`, `pollen.py`, traffic in `commute.py` | **estimated** | harmonic tide approximation; monthly pollen index (Open-Meteo pollen is null for India); time-of-day × weather congestion unless `TOMTOM_KEY` is set |

Anything modelled carries `"source": "estimated"` and the app shows an **Estimated** chip; estimates
are never presented as observations ([00_VISION.md](00_VISION.md), product principle 6). Exact
formulas and the CPCB band table: [05_BACKEND_SPEC.md](05_BACKEND_SPEC.md).

### 3.5 Providers and the fallback chain (`backend/app/providers/`)

Each provider is an httpx client with an 8 s timeout, one retry on 5xx/timeouts, and a TTL cache
keyed by coordinates rounded to two decimals. The chain per field is **IMD → Open-Meteo →
estimated**, and every value records its `source`.

- `imd.py` is written against the real endpoints (`current_wx_api`, `nowcastapi`,
  `warnings_district_api`, `aws_data_api`). IMD answers `401 — your IP/domain needs to be
  whitelisted` from any host it has not approved; the provider detects that response, marks itself
  unavailable for 10 minutes, logs once and returns `None`, so the snapshot falls through to
  Open-Meteo plus derived values. Once a deployment is whitelisted and the district ids in
  `backend/app/data/imd_ids.json` are filled in, `/health` reports `providers.imd = "available"` and
  IMD warnings merge ahead of scenario and admin ones — no code change. Steps:
  [../backend/README.md](../backend/README.md#imd-integration-needs-whitelisting).
- `open_meteo.py` (forecast, air, marine, geocoding), `bigdatacloud.py` (reverse geocoding) and
  `rainviewer.py` (radar) are keyless and the default path; `cpcb.py` (station AQI via data.gov.in)
  and `tomtom.py` (traffic flow) are optional, need a free key, and are estimated without one.
- `scenarios.py` deep-merges one of ten scripted situations (`heatwave`, `cyclone`, `dense_fog`,
  `frost`, `severe_aqi`, `thunderstorm`, `heavy_rain`, `monsoon_flood`, `clear_pleasant`, `live`)
  over the live snapshot for demos, globally from the console or per request with `?scenario=`.

### 3.6 Storage and cache (`backend/app/core/`)

- **Database**: SQLAlchemy 2 over SQLite by default (`backend/data/mausam.db`, created on first
  boot); a Postgres `DATABASE_URL` works unchanged. Tables (`backend/app/models/`): users, saved
  places, card preferences (pins/hides), per-card engagement counters, the raw event log, admin
  warnings, push devices and per-user ranker weights.
- **Cache**: in-process TTL cache (`cache.py`); Redis is reserved via `REDIS_URL` but not required.
  TTLs in seconds: forecast 600 · air 900 · marine 1800 · geocode 86 400 · radar 300 · IMD 600 ·
  assembled snapshot 300. Pushing or clearing a warning invalidates the snapshot bucket only.
- **Auth** (`security.py`): HS256 JWT for guest tokens and the demo OTP flow (`123456` in
  `DEMO_MODE=1`), 30-day lifetime; `/admin/*` is protected by an `X-Admin-Key` header.
- **i18n** (`i18n.py`): flat key files in `backend/app/data/i18n/`, English and Hindi complete,
  Marathi/Tamil/Bengali partial with per-key fallback to English.

### 3.7 Live alerts

`/ws/alerts?token=&lat=&lon=` keeps an in-process registry of connected clients (`api/ws.py`),
pings every 30 s and drops dead sockets. When the console pushes a warning the server writes the
row, invalidates the snapshot cache and broadcasts `warning_issued` with `affects_you` computed per
connection (within `radius_km`, or the same district/state); a client in Mumbai receives the same
Delhi broadcast with `affects_you: false` and an unchanged home. The registry is in-memory, so the
backend runs as a single instance — what the free Render plan provides.

The WebSocket only reaches an app that is open. The production path is **FCM push**: the backend
transport, device registry (`POST /me/devices`) and data-only message schema are implemented and
tested; with no Firebase credentials the transport is `noop` and nothing leaves the process. The
app-side wiring waits on a Firebase project because `google-services.json` cannot be committed.
Design and rollout: [08_PUSH_NOTIFICATIONS.md](08_PUSH_NOTIFICATIONS.md).

### 3.8 Admin demo console

`GET /admin/console` serves a single HTML file (`backend/app/static/admin/index.html`, no build
step) that drives the demo: scenario buttons, a demo clock (`now_override`, read as IST), a
push-warning form with five presets (Orange thunderstorm — Delhi, Red cyclone — Goa, Orange dense
fog — Delhi, Red heatwave — Nagpur, Orange very heavy rain — Mumbai), an active-warnings table with
delete, the connected-client count and a per-user learning reset (key stored in `localStorage`).

## 4. Request path and measured performance

`GET /home` → snapshot (cached upstream calls) → derived metrics → engine (relevance × context +
urgency + learning) → localized card payloads → `pinned` / `hero` / `cards` / `more_cards`. Saved
places are fetched concurrently (max 5, lite fields only); one timing line per request at `INFO`.

| Measure | Value | Target ([01_ARCHITECTURE.md](01_ARCHITECTURE.md)) |
|---|---|---|
| Warm `/home`, server-side | **2 ms** | p95 < 400 ms |
| First `/home` for a location (snapshot cache cold) | **~15 ms** | < 2.5 s |
| Median round trip over loopback | 4.6 ms full · 3.6 ms `lite=1` · 17.7 ms first request after an admin push | — |
| Payload | **34.5 KB** · **13.5 KB** under `lite=1` | < 60 KB |

Measured on an M1 MacBook Air against a local backend; end-to-end figures in [QA_REPORT.md](QA_REPORT.md).
`lite=1` empties `more_cards`, trims hourly arrays to 12 and radar frames to 3 (low-bandwidth mode).

## 5. Data sources

| Source | Status | Used for |
|---|---|---|
| IMD `current_wx_api` · `nowcastapi` · `warnings_district_api` · `aws_data_api` | **needs IP/domain whitelisting** — returns `401` otherwise; the provider detects this, backs off for 10 min and falls through | station observations, 3-h nowcast, district colour-coded warnings |
| Open-Meteo forecast | keyless, 200 | current/hourly/daily, UV, visibility, soil moisture and temperature, sunrise/sunset, 16-day |
| Open-Meteo air quality | keyless, 200 | PM2.5, PM10, O₃, NO₂, SO₂, CO (→ **CPCB** AQI scale) |
| Open-Meteo marine | keyless, 200 | wave height/period/direction, swell, sea-surface temperature |
| Open-Meteo geocoding · BigDataCloud reverse geocoding | keyless, 200 | place search (India ranked first), lat/lon → district/state |
| RainViewer | keyless, 200 | radar frames + tiles (past + nowcast) |
| CPCB via data.gov.in · TomTom traffic | optional, need a free key | station AQI / real traffic flow; **estimated** without them |

Endpoint URLs and probe results: [01_ARCHITECTURE.md](01_ARCHITECTURE.md) §Data sources. Curated
reference data in `backend/app/data/`: 212 Indian cities, 102 coastline points (within 40 km =
coastal), a planting calendar for 7 agro zones, IMD station ids for 35 cities, 10 scenario files.

## 6. API at a glance

Base URL `{BACKEND}/api/v1`. JSON UTF-8, metric units, times ISO-8601 in the location's timezone.
Auth is `Authorization: Bearer <jwt>` (guest or OTP user). [04_API_CONTRACT.md](04_API_CONTRACT.md)
is normative for both sides; interactive docs at `/docs`.

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/health` | – | status, version, provider availability, push transport, active scenario + demo clock |
| POST | `/auth/guest` · `/auth/request-otp` · `/auth/verify-otp` | – | JWT guest / demo OTP (`123456`), guest merge |
| GET/PUT/POST | `/me` · `/me/profile` · `/me/card-prefs` · `/me/places` · `/me/reset-learning` · `/me/devices` | ✓ | profile, personas, pins/hides, saved places (max 8), clear learning, push-token registry |
| GET | `/locations/search` · `/locations/reverse` · `/locations/popular` | – | place search (India first), reverse geocode, curated cities |
| **GET** | **`/home`** | ✓ | **the personalized home** — `lat`/`lon` or `place_id`, `lang`, `personas`, `now_override`, `scenario`, `event_date`, `lite=1` |
| GET | `/weather/snapshot` · `/weather/radar` · `/weather/scenarios` | – | full snapshot, RainViewer frames, scenario list |
| POST | `/events` | ✓ | engagement batch ≤ 100 (`impression, tap, expand, dismiss, pin, unpin, hide, unhide`) |
| GET/POST/DELETE | `/admin/state` · `/admin/scenario` · `/admin/now-override` · `/admin/warnings[/{id}]` · `/admin/reset-user` · `/admin/devices` | `X-Admin-Key` | demo control; pushing/clearing a warning broadcasts on the WebSocket |
| GET | `/admin/console` | – | the single-file demo console (asks for the key itself) |
| WS | `/ws/alerts?token=&lat=&lon=` | ✓ | live alerts |

`/home` returns `{generated_at, location, context, banner, pinned[], hero, cards[], more_cards[],
hidden_types[], freshness, sources, engine}`; each `Card` carries `type, title, subtitle, size,
renderer, urgency, severity, score, reasons[], insight, data, actions[], personas[], source,
estimated`. Ten real payloads (one per persona, plus severe and coastal) are in [fixtures/](fixtures/).

**WebSocket messages.** Server → client: `hello`, `ping` (every 30 s), `warning_issued` (with
`affects_you`), `warning_cleared`, `scenario_changed`, `now_override`. Client → server: `pong` and
`{"type":"location","lat":…,"lon":…}`. The app re-fetches `/home` and animates the diff on
`warning_issued && affects_you`, `scenario_changed` and `now_override`; unknown types are ignored
so the server can add more.

## 7. Deployment

- **Local** (no API key, Docker daemon or database server needed): `uvicorn app.main:app --port
  8000` from `backend/`; `flutter run -d chrome` or a USB phone from `app/`. The app stores only the
  backend origin (Settings → Backend URL, or `--dart-define=BACKEND_URL=<origin>`) and derives
  `/api/v1` and `ws://`/`wss://` itself. Step-by-step for every platform: [RUNNING.md](RUNNING.md).
- **Docker**: [../infra/docker-compose.yml](../infra/docker-compose.yml) builds
  `backend/Dockerfile`, reads `backend/.env` when present and bind-mounts `backend/data/` so the
  SQLite file survives restarts. `cd infra && docker compose up --build` → `http://localhost:8000`.
- **Render free tier** (the demo deploy): [../infra/render.yaml](../infra/render.yaml) is a
  Blueprint — Python runtime, `rootDir: backend`, health check on `/health`, generated `ADMIN_KEY`
  and `JWT_SECRET`, optional keys declared with no values. The instance sleeps after about 15 min
  idle and takes about 30 s to wake; the disk is ephemeral, so demo data resets on each deploy.
- **CI** (GitHub Actions): [../.github/workflows/backend.yml](../.github/workflows/backend.yml)
  runs the backend suite fully offline on Python 3.13 — recorded upstream payloads are replayed
  through `respx` and any unmocked host fails the run (386 tests at last verification, 2026-09-11).
  [../.github/workflows/flutter.yml](../.github/workflows/flutter.yml) pins Flutter 3.47.2 and
  runs `flutter analyze`, `flutter test` (125 tests), `flutter build apk --release` (uploaded as the
  `app-release-apk` artifact, 62.5 MB, all ABIs, debug-signed) and `flutter build web`.
- **APK sideload**: download `app-release.apk` from the workflow artifact or build it locally,
  then `adb install -r` or copy it to the phone and open it. Build with
  `--dart-define=BACKEND_URL=http://<laptop-LAN-IP>:8000` for any APK handed to someone else; the
  app otherwise defaults to the emulator alias `10.0.2.2` and shows a "Sample data" banner.

## 8. Where to read more

| Document | What it covers |
|---|---|
| [00_VISION.md](00_VISION.md) | problem statement, the eight personas, product principles, demo script |
| [01_ARCHITECTURE.md](01_ARCHITECTURE.md) | stack decisions, data-source probe results, environments, non-functional targets |
| [02_CARD_CATALOG.md](02_CARD_CATALOG.md) | every card: personas, affinities, data, insight and urgency rules |
| [03_PERSONALIZATION_ENGINE.md](03_PERSONALIZATION_ENGINE.md) | scoring formulas, explainability, learning v1 and v2 |
| [04_API_CONTRACT.md](04_API_CONTRACT.md) | REST + WebSocket contract (normative) |
| [05_BACKEND_SPEC.md](05_BACKEND_SPEC.md) | backend layout, exact provider requests, derived-metric formulas, scenarios |
| [06_MOBILE_SPEC.md](06_MOBILE_SPEC.md) | app layout, screens, renderers, offline, i18n, the home-screen widget |
| [07_PITCH.md](07_PITCH.md) | the pitch in long form: problem, solution, feasibility, impact, future scope |
| [08_PUSH_NOTIFICATIONS.md](08_PUSH_NOTIFICATIONS.md) | FCM push: why the WebSocket is not enough, transport, message schema, rollout |
| [QA_REPORT.md](QA_REPORT.md) | end-to-end walk of the demo script, measurements, defects found and fixed |
| [DEVIATIONS.md](DEVIATIONS.md) | where the implementation deviates from the numbered specs |
| [../backend/README.md](../backend/README.md) | backend configuration, console, push, ranker v2, IMD whitelisting, deploy |
