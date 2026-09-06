# Mausam backend (FastAPI)

Team Mausam prototype for SIH 2026 · PS 26076. **Not an official IMD service.**

## Run (Windows)

```powershell
C:\Python313\python.exe -m venv .venv
.venv\Scripts\python -m pip install -r requirements-dev.txt
.venv\Scripts\python -m uvicorn app.main:app --reload --port 8000
.venv\Scripts\python -m pytest -q
```

Routers are mounted at `/api/v1` (the contract base in `docs/04_API_CONTRACT.md`) **and** at the
root, so `GET /weather/snapshot?...` works with a bare curl too. Interactive docs: `/docs`.

Endpoints shipped in phase A1:

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | status, version, provider availability, active scenario |
| GET | `/locations/search?q=&limit=` | curated cities first, then Open-Meteo (India ranked first) |
| GET | `/locations/reverse?lat=&lon=` | curated hit within 3 km, else BigDataCloud |
| GET | `/locations/popular` | curated Indian cities (coastal + hill included) |
| GET | `/weather/snapshot?lat=&lon=&scenario=&now_override=` | the full `Snapshot` |
| GET | `/weather/radar` | RainViewer frames + tile template |
| GET | `/weather/scenarios` | scenario names for the demo sheet |

## Configuration

Copy `.env.example` to `.env`. **No API key is required for the default setup** — Open-Meteo,
BigDataCloud and RainViewer are all keyless. `DATA_GOV_IN_KEY` (CPCB station AQI) and
`TOMTOM_KEY` (real traffic flow) are optional; without them those values are estimated.

## Data files (`app/data/`)

| File | Contents |
|---|---|
| `cities.json` | 212 curated Indian cities — id, name, state, district, lat/lon, tz, coastal flag, elevation, population, `popular` flag |
| `coastal_points.json` | 102 coastline points from Kutch to the Sundarbans plus Andaman & Nicobar and Lakshadweep; a location within 40 km of one is treated as coastal |
| `planting_calendar.json` | 7 agro zones × 12 months × 2–4 crops with stage + action |
| `imd_ids.json` | best-effort IMD station ids for 35 curated cities (district ids unknown until whitelisted) |
| `scenarios/*.json` | the 10 demo scenarios from `docs/05_BACKEND_SPEC.md` |
| `i18n/en.json` | English string seed (A2 completes `en` and adds `hi`) |

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
Open-Meteo plus derived values.

To switch it on for real:

1. Write to IMD (Data Supply / Web Services, `https://mausam.imd.gov.in`) with the deployment's
   static IP or domain, the purpose, and the endpoints needed
   (`current_wx_api.php`, `nowcastapi.php`, `warnings_district_api.php`, `aws_data_api.php`).
2. Once whitelisted, keep `IMD_ENABLED=1` and fill the `district_id` values in
   `app/data/imd_ids.json` (station ids are already populated).
3. `GET /health` then reports `providers.imd = "available"` and stays there.

## Tests

`pytest -q` runs entirely offline: `tests/conftest.py` replays the recorded upstream payloads in
`tests/fixtures/` through `respx`, and any unmocked request fails the suite. Re-record with:

```powershell
.venv\Scripts\python scripts\record_fixtures.py
```

That script hits the real APIs for Delhi, Panaji, Shimla, Mumbai and London and rewrites the
fixture envelopes (`{url, params, status, recorded_at, json}`). Commit the JSON.
