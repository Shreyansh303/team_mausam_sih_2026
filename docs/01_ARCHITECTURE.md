# 01 · Architecture and stack decisions

## System overview
```
┌──────────────── Flutter app (Android/iOS/web) ────────────────┐
│ Onboarding → Home (ranked cards) → Detail sheets → Map → Places│
│ Riverpod state · Dio client · JSON file cache (offline)         │
│ WebSocket client (live alerts) · ARB i18n · engagement events   │
└───────────────▲────────────────────────────────▲───────────────┘
                │ REST /api/v1  (JSON)             │ WS /ws/alerts
┌───────────────┴────────────────────────────────┴───────────────┐
│ FastAPI backend                                                 │
│  api/        routers: auth, me, places, locations, home,        │
│              weather, events, admin, ws                          │
│  engine/     card catalog · context · scoring · explain ·        │
│              learning · builders (one per card type)             │
│  services/   snapshot aggregation · derived metrics (AQI-CPCB,   │
│              comfort, workout windows, commute, frost, packing,  │
│              planting, tides*, pollen*, traffic*)   *estimated   │
│  providers/  IMD (needs whitelisting) → Open-Meteo (default)     │
│              → Scenario/Mock overlay · RainViewer · geocoding    │
│  core/       TTL cache (in-proc, optional Redis) · DB (SQLite    │
│              default, Postgres via env) · JWT auth · i18n        │
│  static/     admin demo console (scenarios, push warnings)       │
└─────────────────────────────────────────────────────────────────┘
```

## Stack (final)
| Layer | Choice | Why |
|---|---|---|
| Mobile | **Flutter** (stable), Riverpod, go_router, Dio, flutter_map, fl_chart, intl/ARB | Single codebase, broad low-end device support, strong animation for card re-rank. Toolchain installed under `D:\sdk` by `scripts/setup_flutter_windows.ps1`. |
| Backend | **FastAPI** (Python 3.13), Pydantic v2, httpx, SQLAlchemy 2 | Engine + derived metrics are numeric/rules code — Python is the natural fit; one language for engine + optional ML. |
| DB | **SQLite by default**, PostgreSQL when `DATABASE_URL` set | Zero-setup demo; production path preserved. |
| Cache | **In-process TTL cache**, Redis when `REDIS_URL` set | Same reason. TTLs: forecast 10 min, air 15 min, marine 30 min, geocode 24 h. |
| Live alerts | **WebSocket** `/ws/alerts` (+ FCM documented as production path) | Demoable without Firebase project setup; app re-ranks on message. |
| Auth | Demo **OTP** (`123456`) + guest tokens, JWT HS256 | Mirrors Mausam's OTP flow without SMS vendor. |
| Maps/radar | **flutter_map + OSM tiles + RainViewer radar tiles** | Keyless. |
| Deploy | Docker + `infra/docker-compose.yml`; Render/Railway free tier; APK via local build or GitHub Actions artifact | Judges sideload the APK; backend URL configurable in app settings. |

Decisions changed from the original brief and why: Firebase Auth/FCM → optional (setup friction,
no demo gain); Mapbox → flutter_map/OSM (no token); Postgres/Redis → optional (zero-setup demo);
Node/Express → FastAPI (engine lives in Python).

## Data sources (probed 2026-09-07 from this machine)
| Source | Endpoint | Status | Used for |
|---|---|---|---|
| IMD current weather | `https://mausam.imd.gov.in/api/current_wx_api.php?id=<stationId>` | 401 "IP needs to be whitelisted" | Current obs (when whitelisted) |
| IMD nowcast | `https://mausam.imd.gov.in/api/nowcastapi.php?id=<districtId>` | 401 whitelist | 3-h nowcast |
| IMD district warnings | `https://mausam.imd.gov.in/api/warnings_district_api.php?id=<districtId>` | 401 whitelist | District warnings |
| IMD AWS | `https://mausam.imd.gov.in/api/aws_data_api.php?id=` | 401 whitelist | Station obs |
| Open-Meteo forecast | `https://api.open-meteo.com/v1/forecast` | 200, no key | current/hourly/daily, UV, visibility, soil moisture/temp, sunrise/sunset, apparent temp, 16-day |
| Open-Meteo air quality | `https://air-quality-api.open-meteo.com/v1/air-quality` | 200 | PM2.5, PM10, O3, NO2, SO2, CO, (pollen fields exist; likely null for India → estimator) |
| Open-Meteo marine | `https://marine-api.open-meteo.com/v1/marine` | 200 | wave height/period/direction, swell, SST, current |
| Open-Meteo geocoding | `https://geocoding-api.open-meteo.com/v1/search` | 200 | place search (rank `country_code=IN` first, but allow foreign for travelers) |
| BigDataCloud reverse geocode | `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude&longitude&localityLanguage=en` | free, no key | lat/lon → city/district/state |
| RainViewer | `https://api.rainviewer.com/public/weather-maps.json` → `{host}{path}/256/{z}/{x}/{y}/2/1_1.png` | 200 | radar tiles |
| CPCB via data.gov.in (optional) | needs free API key | optional | station AQI when `DATA_GOV_IN_KEY` set |
| Traffic (optional) | TomTom Traffic Flow, needs key | optional | else estimated from time-of-day × weather |

Provider chain per field: **IMD → Open-Meteo → estimated/mock**. Every value records its
`source`. Scenario overlays (`?scenario=`) deep-merge on top for demos.

## Environments
- Dev: backend on `http://localhost:8000`, Flutter web on `http://localhost:8080` (CORS allowed),
  Android device via `adb` (backend URL = machine LAN IP, editable in app Settings).
- Demo: backend on Render/Railway; app points to its URL; admin console at `/admin/console`.

## Non-functional targets
- `/home` p95 < 400 ms warm (cache hit), < 2.5 s cold. Payload < 60 KB.
- App cold start to cached home < 1 s; works with no network.
- All strings localizable; contrast AA; touch targets ≥ 48 dp; TalkBack labels on cards.
