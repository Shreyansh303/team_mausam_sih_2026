# Mausam backend (FastAPI)

Team Mausam prototype for SIH 2026 · PS 26076. **Not an official IMD service.**

## Run (Windows)

```powershell
C:\Python313\python.exe -m venv .venv
.venv\Scripts\python -m pip install -r requirements-dev.txt
.venv\Scripts\python -m uvicorn app.main:app --reload --port 8000
.venv\Scripts\python -m pytest -q
```

macOS/Linux is the same with `.venv/bin/python`. Nothing else is required — no key, no Docker,
no database server; SQLite is created on first boot at `backend/data/mausam.db`.

Routers are mounted at `/api/v1` (the contract base in `docs/04_API_CONTRACT.md`) **and** at the
root, so `GET /weather/snapshot?...` works with a bare curl too. Interactive docs: `/docs`.

| What | URL |
|---|---|
| API base | `http://localhost:8000/api/v1` |
| OpenAPI docs | `http://localhost:8000/docs` |
| Demo console | `http://localhost:8000/admin/console` |
| Live alerts | `ws://localhost:8000/ws/alerts?token=&lat=&lon=` |
| Health | `http://localhost:8000/health` |

### Endpoints

| Method | Path | Phase | Purpose |
|---|---|---|---|
| GET | `/health` | A1 | status, version, provider availability, active scenario + demo clock |
| GET | `/locations/search?q=&limit=` | A1 | curated cities first, then Open-Meteo (India ranked first) |
| GET | `/locations/reverse?lat=&lon=` | A1 | curated hit within 3 km, else BigDataCloud |
| GET | `/locations/popular` | A1 | curated Indian cities (coastal + hill included) |
| GET | `/weather/snapshot?lat=&lon=&scenario=&now_override=` | A1 | the full `Snapshot` |
| GET | `/weather/radar` | A1 | RainViewer frames + tile template |
| GET | `/weather/scenarios` | A1 | scenario names for the demo sheet |
| POST | `/auth/guest` · `/auth/request-otp` · `/auth/verify-otp` | A2 | JWT guest + demo OTP (`123456`) |
| GET/PUT | `/me`, `/me/profile`, `/me/card-prefs`, `/me/places` | A2 | profile, pins/hides, saved places (max 8) |
| GET | `/home` | A2 | **the personalized home** — `lat/lon` or `place_id`, `lang`, `personas`, `now_override`, `scenario`, `event_date`, `lite=1` |
| POST | `/events` | A2 | engagement batch (≤ 100); `pin/hide` also write card-prefs |
| GET | `/admin/state` | A3 | `{scenario, now_override, warnings, connected_clients}` |
| POST | `/admin/scenario` `/admin/now-override` | A3 | global demo scenario + demo clock |
| POST/DELETE | `/admin/warnings`, `/admin/warnings/{id}` | A3 | push / clear a warning (broadcasts on the WebSocket) |
| POST | `/admin/reset-user` | A3 | clear one user's learning |
| GET | `/admin/console` | A3 | the single-file demo console |
| WS | `/ws/alerts?token=&lat=&lon=` | A3 | live alerts |

## Configuration

Copy `.env.example` to `.env`. **No API key is required for the default setup** — Open-Meteo,
BigDataCloud and RainViewer are all keyless. `DATA_GOV_IN_KEY` (CPCB station AQI) and
`TOMTOM_KEY` (real traffic flow) are optional; without them those values are estimated.

| Variable | Default | Meaning |
|---|---|---|
| `DEMO_MODE` | `1` | enables the demo OTP, `demo_otp` in the response and token-less WebSocket clients |
| `LOG_LEVEL` | `INFO` | `INFO` prints one timing line per `/home` request |
| `ADMIN_KEY` | `mausam-admin` | value of the `X-Admin-Key` header on `/admin/*` — **change it on a public deploy** |
| `JWT_SECRET` | dev value | HS256 signing key for guest/OTP tokens |
| `JWT_EXPIRE_DAYS` | `30` | token lifetime |
| `DATABASE_URL` | `sqlite:///./data/mausam.db` | relative SQLite paths resolve against `backend/`; a Postgres URL also works |
| `REDIS_URL` | empty | reserved; the cache is in-process today |
| `DEFAULT_SCENARIO` | `live` | scenario used before the console changes it |
| `CORS_ORIGINS` | `*` | comma list, or `*` |
| `HTTP_TIMEOUT_S` | `8` | per-provider timeout |
| `IMD_ENABLED` / `IMD_BASE_URL` | `1` / `https://mausam.imd.gov.in/api` | see IMD integration below |
| `DATA_GOV_IN_KEY` / `TOMTOM_KEY` | empty | optional upstreams |
| `CACHE_TTL_*` | forecast 600 · air 900 · marine 1800 · geocode 86400 · radar 300 · imd 600 · snapshot 300 | seconds |

## Demo console (`/admin/console`)

A single HTML file (`app/static/admin/index.html`), no build step. Open
`http://localhost:8000/admin/console`, paste the admin key (default `mausam-admin`) and press
**Save** — the backend base and the key are kept in `localStorage`. Panels:

1. **Scenario** — one button per `data/scenarios/*.json`; the active one is highlighted. Sets the
   global default for `/home` and `/weather/snapshot` and broadcasts `scenario_changed`.
2. **Demo clock** — a `datetime-local` field (read as IST) → `now_override`, plus **Clear** and
   three one-click times. Broadcasts `now_override`.
3. **Push a warning** — severity, hazard, title, description, location (pick a city from
   `/locations/popular` or type lat/lon + district/state), `radius_km` (75) and `ttl_minutes`
   (120), with the five presets from `docs/05_BACKEND_SPEC.md`:
   *Orange thunderstorm — Delhi · Red cyclone — Goa · Orange dense fog — Delhi ·
   Red heatwave — Nagpur · Orange very heavy rain — Mumbai*.
4. **Active warnings** — table of live warnings with a Delete button each.
5. **Connected clients** — the WebSocket client count, refreshed every 5 s, plus a
   *Connect this page to `/ws/alerts`* button and a live message feed.
6. **Reset a user** — clears engagement + pins/hides for one `usr_…` id.

Every `/admin/*` call needs `X-Admin-Key`; the console page itself does not (it asks for the key).

```bash
curl -X POST http://localhost:8000/api/v1/admin/warnings \
  -H "X-Admin-Key: mausam-admin" -H "Content-Type: application/json" \
  -d '{"severity":"orange","hazard":"thunderstorm","title":"Thunderstorm warning — Delhi",
       "description":"Lightning and gusty winds likely in the next 3 hours.",
       "district":"New Delhi","state":"Delhi","lat":28.61,"lon":77.21,
       "radius_km":75,"ttl_minutes":120}'
```

### The 60-second judge demo

1. Start the backend, open `/admin/console`, open the app (or a second browser tab on `/home`).
2. Console → **Orange thunderstorm — Delhi** preset → **Push warning**.
3. Every connected client instantly receives
   `{"type":"warning_issued","warning":{…},"affects_you":true}` on `/ws/alerts` and re-fetches.
4. `GET /api/v1/home?lat=28.61&lon=77.21&personas=parent` now returns the `warnings` card in
   `pinned` (urgency 0.8), `banner` set to the orange warning, and `context.warning_count = 1`.
   A client 1 100 km away (Mumbai) gets the same broadcast with `affects_you: false` and an
   unchanged `/home`.
5. Console → **Delete** on the row → `warning_cleared` goes out and `/home` returns to normal.
   Nothing has to be deleted for the demo to end cleanly: the warning expires by itself after
   `ttl_minutes`.

Scenario buttons work the same way for weather itself (`thunderstorm`, `heatwave`, `dense_fog`,
`cyclone`, `severe_aqi`, …) and the demo clock lets you show the 07:30 school run at any hour.

## Live alerts (`/ws/alerts`)

```
ws://localhost:8000/ws/alerts?token=<jwt>&lat=28.61&lon=77.21
```

`token` is a guest or OTP JWT. In `DEMO_MODE=1` it may be omitted (handy for the console and for
`wscat`); an *invalid* token is always rejected with close code 1008. Server → client messages are
exactly the six in `docs/04_API_CONTRACT.md`: `hello`, `ping` (every 30 s — reply `{"type":"pong"}`),
`warning_issued` (with `affects_you` computed from the client's coordinates via radius, district or
state match), `warning_cleared`, `scenario_changed`, `now_override`. Client → server: `pong` and
`{"type":"location","lat":..,"lon":..}` when the user changes location.

The registry is in-process (`app/api/ws.py`), so run **one** backend instance — which is what the
Render free plan gives you.

## Honest data

Anything modelled carries `"source": "estimated"` and the UI must label it:

* **Tides** — a deterministic harmonic approximation (`services/tides.py`), never an observation.
  Real tables come from INCOIS / the Survey of India.
* **Pollen** — Open-Meteo's CAMS pollen fields are Europe-only and come back `null` for every
  Indian coordinate (verified in `tests/fixtures/air_*.json`), so the monthly estimator in
  `services/pollen.py` is the normal path for India.
* **Traffic** — time-of-day × weather model unless `TOMTOM_KEY` is set.

## IMD integration (needs whitelisting)

`https://mausam.imd.gov.in/api/*` answers `401 — Your IP/Domain … needs to be whitelisted`
from any host IMD has not approved (recorded in `tests/fixtures/imd_current_delhi.json`).
`providers/imd.py` handles this: on a 401 containing "whitelist" it marks the provider
unavailable for 10 minutes, logs once, and returns `None` so the snapshot falls back to
Open-Meteo plus derived values. Nothing in the demo depends on IMD being reachable.

The four endpoints this project uses (probed 2026-09-07, see `docs/01_ARCHITECTURE.md`):

| Endpoint | Used for |
|---|---|
| `current_wx_api.php?id=<stationId>` | current station observation |
| `nowcastapi.php?id=<districtId>` | 3-hour nowcast |
| `warnings_district_api.php?id=<districtId>` | district colour-coded warnings |
| `aws_data_api.php?id=<stationId>` | AWS station observation |

To switch it on for real:

1. Write to IMD (Data Supply / Web Services, `https://mausam.imd.gov.in`, or the nearest
   Regional Meteorological Centre) asking for API access. Include: the **static public IP or the
   domain** of the deployment, the organisation and purpose (SIH 2026, PS 26076 prototype), the
   four endpoints above, the expected request rate (this backend caches IMD responses for
   `CACHE_TTL_IMD` = 10 min per station), and a contact. Ask them to confirm the **district id
   list** as well — IMD does not publish it, which is why every `district_id` in
   `app/data/imd_ids.json` is `null`.
2. Once whitelisted, keep `IMD_ENABLED=1` and fill the `district_id` values in
   `app/data/imd_ids.json` (station ids are already populated for 35 cities).
3. `GET /health` then reports `providers.imd = "available"`, `Snapshot.sources.imd` follows, and
   IMD warnings merge ahead of scenario/admin ones in `services/warnings.merge()`.

Until then the provider chain is **IMD → Open-Meteo → estimated**, exactly as documented, and the
admin console supplies warnings for demos.

## Deploy

### Docker / compose (any machine with Docker)

```bash
cd infra
docker compose up --build          # → http://localhost:8000
```

`infra/docker-compose.yml` builds `backend/Dockerfile`, reads `backend/.env` when it exists and
bind-mounts `backend/data/` so the SQLite file survives restarts.

### Render free tier (the demo deploy)

1. Push this repo to GitHub.
2. Render dashboard → **New → Blueprint** → select the repo. It picks up `infra/render.yaml`:
   Python runtime, `rootDir: backend`, `pip install -r requirements.txt`,
   `uvicorn app.main:app --host 0.0.0.0 --port $PORT`, health check on `/health`.
3. Render generates `ADMIN_KEY` and `JWT_SECRET`. Copy the generated `ADMIN_KEY` from the service's
   **Environment** tab — it is what the console asks for.
4. Wait for the first deploy, then check:
   `https://<service>.onrender.com/health` and `https://<service>.onrender.com/admin/console`.

Free-plan facts worth knowing before a live demo: the instance sleeps after ~15 minutes idle and
the next request takes ~30 s to wake it (hit `/health` a minute before you present); the disk is
ephemeral, so guest users and pushed warnings reset on every deploy; WebSockets work and there is
exactly one instance, which is what the in-process connection registry needs.

### Pointing the app at it

The Flutter app keeps the backend URL in **Settings → Backend URL** (`docs/06_MOBILE_SPEC.md`):

* Android emulator on this machine → `http://10.0.2.2:8000`
* real phone on the same Wi-Fi → `http://<your-LAN-IP>:8000` (find it with `ipconfig`)
* Flutter web on this machine → `http://localhost:8000`
* Render → `https://<service>.onrender.com`

The app derives the WebSocket URL from that base (`http` → `ws`, `https` → `wss`) and appends
`/ws/alerts`. `CORS_ORIGINS=*` is the default, so Flutter web works out of the box.

## Tests

`pytest -q` runs entirely offline: `tests/conftest.py` replays the recorded upstream payloads in
`tests/fixtures/` through `respx`, and any unmocked request fails the suite. The same suite runs in
GitHub Actions on every push and PR that touches `backend/` (`.github/workflows/backend.yml`,
Python 3.13, pip cache). Re-record the upstream fixtures with:

```powershell
.venv\Scripts\python scripts\record_fixtures.py
```

That script hits the real APIs for Delhi, Panaji, Shimla, Mumbai and London and rewrites the
fixture envelopes (`{url, params, status, recorded_at, json}`). Commit the JSON.
`scripts\gen_fixtures.py` regenerates the contract samples in `docs/fixtures/` from those
recordings (offline, deterministic apart from the random `usr_`/`plc_` ids).

## Data files (`app/data/`)

| File | Contents |
|---|---|
| `cities.json` | 212 curated Indian cities — id, name, state, district, lat/lon, tz, coastal flag, elevation, population, `popular` flag |
| `coastal_points.json` | 102 coastline points from Kutch to the Sundarbans plus Andaman & Nicobar and Lakshadweep; a location within 40 km of one is treated as coastal |
| `planting_calendar.json` | 7 agro zones × 12 months × 2–4 crops with stage + action |
| `imd_ids.json` | best-effort IMD station ids for 35 curated cities (district ids unknown until whitelisted) |
| `scenarios/*.json` | the 10 demo scenarios from `docs/05_BACKEND_SPEC.md` |
| `i18n/*.json` | `en` + `hi` complete (597 keys); `mr`, `ta`, `bn` partial with per-key fallback |
