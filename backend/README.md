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

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | status, version, provider availability, push transport + device count, active scenario + demo clock |
| GET | `/locations/search?q=&limit=` | curated cities first, then Open-Meteo (India ranked first) |
| GET | `/locations/reverse?lat=&lon=` | curated hit within 3 km, else BigDataCloud |
| GET | `/locations/popular` | curated Indian cities (coastal + hill included) |
| GET | `/weather/snapshot?lat=&lon=&scenario=&now_override=` | the full `Snapshot` |
| GET | `/weather/radar` | RainViewer frames + tile template |
| GET | `/weather/scenarios` | scenario names for the demo sheet |
| POST | `/auth/guest` · `/auth/request-otp` · `/auth/verify-otp` | JWT guest + demo OTP (`123456`) |
| GET/PUT | `/me`, `/me/profile`, `/me/card-prefs`, `/me/places` | profile, pins/hides, saved places (max 8) |
| GET | `/home` | **the personalized home** — `lat/lon` or `place_id`, `lang`, `personas`, `now_override`, `scenario`, `event_date`, `lite=1` |
| POST | `/events` | engagement batch (≤ 100); `pin/hide` also write card-prefs |
| POST/DELETE | `/me/devices`, `/me/devices/{token}` | register / unregister this handset's push token (optional) |
| GET | `/admin/state` | `{scenario, now_override, warnings, connected_clients, devices, push_transport}` |
| POST | `/admin/scenario` `/admin/now-override` | global demo scenario + demo clock |
| POST/DELETE | `/admin/warnings`, `/admin/warnings/{id}` | push / clear a warning (broadcasts on the WebSocket) |
| POST | `/admin/reset-user` | clear one user's learning |
| GET | `/admin/devices` | registered push devices (tokens redacted) |
| GET | `/admin/console` | the single-file demo console |
| WS | `/ws/alerts?token=&lat=&lon=` | live alerts |

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
| `ENGINE_ML` | `0` | `1` blends the v2 ML ranker into `/home` (below). `0` is the deterministic v1 ranker, which is also the fallback |
| `DEFAULT_SCENARIO` | `live` | scenario used before the console changes it |
| `CORS_ORIGINS` | `*` | comma list, or `*` |
| `HTTP_TIMEOUT_S` | `8` | per-provider timeout |
| `IMD_ENABLED` / `IMD_BASE_URL` | `1` / `https://mausam.imd.gov.in/api` | see IMD integration below |
| `DATA_GOV_IN_KEY` / `TOMTOM_KEY` | empty | optional upstreams |
| `FCM_SERVICE_ACCOUNT_FILE` / `FCM_PROJECT_ID` | empty | optional push — both must be set to switch off the `noop` transport (below) |
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

## Push notifications (FCM)

The WebSocket above only reaches an app that is **open**. `services/push.py` is the second
delivery path, for a phone whose app is closed. Design, message schema and the security notes:
[`../docs/09_PUSH_NOTIFICATIONS.md`](../docs/09_PUSH_NOTIFICATIONS.md).

**With no configuration** (the default, and what CI runs) the transport is `noop`: devices can
still register, every admin broadcast is logged as `push (noop): warning_issued → N device(s)`
and nothing leaves the process. `GET /health` says which transport is live:

```jsonc
"push": {"transport": "noop", "devices": 0}
```

### Turning on real delivery

1. **Create the Firebase project** — <https://console.firebase.google.com> → *Add project*
   (Analytics not needed). Project settings → *Cloud Messaging* → make sure the
   **Firebase Cloud Messaging API (V1)** is enabled.
2. **Add the Android app** with package name `com.teammausam.mausam_app` and download
   `google-services.json`. That file belongs to the *app*, not the backend — it is only needed
   once the Flutter side is wired (see below), and it must not be committed.
3. **Download a service account** — Project settings → *Service accounts* →
   *Generate new private key* → a JSON file with `client_email` and `private_key`. **This is a
   secret**: keep it outside the repo (`.gitignore` does not save you if you paste it in a doc).
4. **Point the backend at it**:

   ```bash
   # backend/.env
   FCM_SERVICE_ACCOUNT_FILE=/absolute/path/to/fcm-service-account.json
   FCM_PROJECT_ID=your-firebase-project-id
   ```

   On Render, upload the JSON as a *Secret File* and set `FCM_SERVICE_ACCOUNT_FILE` to its mount
   path (`/etc/secrets/<name>`) — `infra/render.yaml` already declares both keys with no values.
   Restart; `/health` should now report `"transport": "fcm"`.
5. **Register a device and push**:

   ```bash
   TOKEN=$(curl -s -X POST localhost:8000/api/v1/auth/guest | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
   curl -X POST localhost:8000/api/v1/me/devices -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"token":"<fcm registration token>","platform":"android","lat":28.61,"lon":77.21,"lang":"hi"}'
   curl -s localhost:8000/api/v1/admin/devices -H "X-Admin-Key: mausam-admin"
   # then push a warning exactly as in the demo above — every registered device gets it
   ```

Auth is the documented OAuth2 flow, done with the libraries already pinned (PyJWT + httpx, no
Google SDK): an RS256 assertion signed with the service-account key is exchanged at
`oauth2.googleapis.com/token` for an access token (cached ≈1 h), then one
`POST /v1/projects/{id}/messages:send` per device. A token FCM rejects with `404 UNREGISTERED`
is deleted from the registry automatically. Any push failure is logged and swallowed — it never
turns an admin call into a 500.

### What the app side still needs

Not wired yet, on purpose: adding `firebase_messaging` without a `google-services.json` breaks
`flutter build apk`, and that file cannot be committed. When a Firebase project exists:

* add `firebase_core` + `firebase_messaging` (+ `flutter_local_notifications`) and drop
  `google-services.json` into `app/android/app/`;
* request `POST_NOTIFICATIONS` on Android 13+, then `POST /me/devices` with the token, the current
  `lat`/`lon` and the UI language — again on every `onTokenRefresh`, and `DELETE` on sign-out;
* handle the **data-only** message: on `type == "warning_issued"` refetch `/home` and re-rank; if
  `affects_you == "true"`, raise a *local* notification built from `data.title` / `data.severity`
  in the user's language (the server deliberately sends no `notification` block, so the OS cannot
  show a message in the wrong language);
* key on `warning.id` — the WebSocket and the push can both deliver the same warning.

## Ranker v2 (ML)

`ENGINE_ML=1` turns on the learned term specified in `docs/03` §"Learning (v2)". **It is off by
default and v1 is the fallback**: with the flag off, `/home` is byte-identical to what it has
always returned and `app/engine/ml.py` is never called at all (there is a test that asserts
exactly that). Nothing about the API contract changes; the only visible difference is one extra
reason code on a card.

### Enable it

```bash
# one process
ENGINE_ML=1 .venv/bin/python -m uvicorn app.main:app --reload --port 8000
# or persist it
echo ENGINE_ML=1 >> .env
```

Confirm it is live:

```bash
curl -s localhost:8000/health | python -c "import sys,json;print(json.load(sys.stdin)['engine'])"
# {'ml': True}
curl -s localhost:8000/admin/state -H 'X-Admin-Key: mausam-admin' | grep -o '"engine_ml":[a-z]*'
```

### What it learns

A per-user logistic regression over the events `POST /events` already logs, predicting `p_tap` —
"will this user open this card type in this context" — blended as `score += 0.2 * (p_tap - 0.5)`.
Features: the card type, the daypart/season/weekend of the event, the user's personas and the v1
`relevance` for that card, the urgency band, the per-card-type engagement rates (taps, expands,
dismisses, pins over impressions), and recency. Training is plain-Python SGD (no numpy, no
scikit-learn), 5 epochs over the most recent 300 events, and runs **inline on `POST /events`** —
15 ms at the cap, so a 100-event batch still round-trips in under 20 ms.

`p_tap` is exactly `0.5` — a zero contribution — until the user has 8 labelled events, and also
for any card type the user has never interacted with. A brand-new user therefore sees the v1
screen, unchanged, which is why the cold-start test can assert byte equality.

**The bound.** The learned term is clamped to ±0.1, is added to `score` and never to `urgency`,
and is only applied to cards that are **not** pinned. Since `docs/03` §Ordering renders the whole
pinned block above `cards`, no amount of learning can lift a card over a pinned orange or red
warning, and nothing can be pushed past the `urgency >= 0.8` pin threshold. `tests/test_ml.py`
proves this with a model that is maximally confident about every card in the catalog.

When the term is at least 0.01 the card carries an extra reason the why sheet can show:

```json
{"code": "learning:up", "text": "Learned from your taps (+0.09)"}
```

localized in `en` and `hi` (`reason.learning.up` / `reason.learning.down`).

### Try it end to end

```bash
BASE=http://localhost:8000/api/v1
TOKEN=$(curl -s -X POST $BASE/auth/guest | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
curl -s -X POST $BASE/events -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
     -d "$(python -c "import json;print(json.dumps({'events':[{'type':'aqi','action':'tap'}]*10}))")"
curl -s "$BASE/home?lat=28.61&lon=77.21" -H "Authorization: Bearer $TOKEN" \
 | python -c "import sys,json;b=json.load(sys.stdin);c=[x for x in b['cards']+b['more_cards'] if x['type']=='aqi'][0];print(c['score'],[r['code'] for r in c['reasons']])"
```

`POST /me/reset-learning` (or `POST /admin/reset-user`) deletes the weights along with the
counters, the card prefs and the raw event log, and the score returns to its v1 value exactly.

### Inspect the weights

They are a plain JSON object per user in the `ranker_weights` table
(`app/models/ranker_weights.py`), so no tooling is needed:

```bash
python - <<'EOF'
import json, sqlite3
for uid, n, ver, w in sqlite3.connect("data/mausam.db").execute(
        "select user_id, n_events, version, weights from ranker_weights"):
    d = json.loads(w)
    print(uid, "n_events=%d" % n, "v=%s" % ver, "features=%d" % len(d))
    for k, v in sorted(d.items(), key=lambda kv: -abs(kv[1]))[:8]:
        print("   %-24s %+.3f" % (k, v))
EOF
```

A positive `type:aqi` means this user opens the AQI card; a negative `type:humidity` means they
dismiss it. `stats` on the same row holds the per-card-type last-interaction timestamps that feed
the recency feature, and `version` is bumped whenever the feature set changes so an old row is
retrained rather than mixed with new features.

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
