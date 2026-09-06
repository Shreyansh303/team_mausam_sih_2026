# 05 · Backend spec (FastAPI)

## Layout
```
backend/
  pyproject.toml            # or requirements.txt + requirements-dev.txt (pin majors)
  .env.example              # all env vars with defaults
  Dockerfile                # python:3.13-slim, uvicorn, port 8000
  app/
    main.py                 # create_app(), CORS, routers, static, lifespan (db init, cache)
    config.py               # pydantic-settings: DEMO_MODE=1, ADMIN_KEY, JWT_SECRET, DATABASE_URL (sqlite:///./data/mausam.db),
                            #   REDIS_URL, DATA_GOV_IN_KEY, TOMTOM_KEY, IMD_BASE_URL, IMD_ENABLED=1, DEFAULT_SCENARIO=live,
                            #   CORS_ORIGINS, HTTP_TIMEOUT_S=8, CACHE_TTL_* , LOG_LEVEL
    core/  cache.py (TTLCache/Redis facade, key builder, get_or_fetch), db.py (SQLAlchemy 2, session dep),
           security.py (JWT create/verify, guest ids, admin dep), i18n.py (t(lang,key,**kw), loads app/i18n/*.json),
           timeutil.py (tz, dayparts, season), geo.py (haversine, coastal check), errors.py
    providers/ base.py (Provider protocol + Result[source]), open_meteo.py (forecast, air, marine, geocode),
           bigdatacloud.py (reverse), rainviewer.py, imd.py (current_wx, nowcast, warnings; whitelisting-aware),
           cpcb.py (optional data.gov.in), tomtom.py (optional), scenarios.py (overlay loader/merger)
    services/ snapshot.py (aggregate providers → Snapshot, per-location cache), aqi_cpcb.py, comfort.py (comfort index, heat index, dew point),
           workout.py, school_commute.py, commute.py (+traffic estimator), frost.py, packing.py, planting.py,
           tides.py (estimated), pollen.py (estimated), marine.py (sea state, surf, swim safety), visibility.py, flight_risk.py,
           nowcast.py (derive when IMD unavailable), warnings.py (merge imd+admin+scenario, filter by location)
    engine/ catalog.py (CardDef table from 02), context.py, scoring.py, explain.py, learning.py, builders/<type>.py (33), home.py (assemble HomeResponse)
    api/   auth.py, me.py, places.py, locations.py, home.py, weather.py, events.py, admin.py, ws.py, health.py
    models/ (SQLAlchemy): user.py, place.py, card_pref.py, engagement.py, event.py, admin_warning.py
    schemas/ (Pydantic v2): user.py, location.py, warning.py, snapshot.py, card.py, home.py, events.py, admin.py
    data/  cities.json (≥150 Indian cities: id, name, admin1, admin2, lat, lon, tz, is_coastal, elevation_m, population),
           coastal_points.json (≥80 lat/lon points along the Indian coastline incl. islands),
           planting_calendar.json, i18n/ en.json hi.json mr.json ta.json bn.json, scenarios/*.json
    static/admin/index.html (+ inline JS/CSS)
  scripts/ gen_fixtures.py (writes docs/fixtures/home_<persona>.json per persona via TestClient, scenario clear_pleasant + one severe)
  tests/   conftest.py (respx mocks for all providers using recorded JSON in tests/fixtures/), test_providers.py,
           test_aqi.py, test_derived.py, test_engine.py (03 §tests), test_api.py, test_i18n.py, test_ws_admin.py
```
Dependencies: fastapi, uvicorn[standard], pydantic>=2, pydantic-settings, httpx, sqlalchemy>=2,
pyjwt, cachetools, python-dotenv, websockets (via uvicorn[standard]), respx + pytest + pytest-asyncio
(dev). Optional: redis, scikit-learn, numpy, psycopg[binary].

## Providers (exact requests)
**Open-Meteo forecast** `GET https://api.open-meteo.com/v1/forecast` params:
`latitude, longitude, timezone=auto, forecast_days=16, current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m`
`hourly=temperature_2m,relative_humidity_2m,dew_point_2m,apparent_temperature,precipitation_probability,precipitation,weather_code,cloud_cover,visibility,wind_speed_10m,wind_direction_10m,wind_gusts_10m,uv_index,is_day,soil_temperature_0cm,soil_moisture_0_to_1cm,soil_moisture_9_to_27cm`
`daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,sunrise,sunset,daylight_duration,uv_index_max,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max`.
Current-hour `uv_index`/`visibility` come from the matching hourly row. Visibility m → km.
**Open-Meteo air** `https://air-quality-api.open-meteo.com/v1/air-quality`:
`current=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen`, `hourly=pm10,pm2_5,ozone,nitrogen_dioxide,sulphur_dioxide,carbon_monoxide`, `forecast_days=2`, `timezone=auto`.
**Open-Meteo marine** `https://marine-api.open-meteo.com/v1/marine`:
`current=wave_height,wave_direction,wave_period,swell_wave_height,ocean_current_velocity,sea_surface_temperature`, `hourly=wave_height`, `forecast_days=2`, `timezone=auto`. Treat HTTP 400 or null wave_height as "not marine".
**Geocode** `https://geocoding-api.open-meteo.com/v1/search?name=&count=10&language=en&format=json`; rank `country_code==IN` first; also match curated `cities.json` by prefix first (instant).
**Reverse** `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude&longitude&localityLanguage=en` → `city|locality`, `principalSubdivision` (state), `localityInfo.administrative` level 5/6 for district; fallback nearest curated city (≤ 60 km) else "Lat, Lon".
**RainViewer** `https://api.rainviewer.com/public/weather-maps.json` → `tile_template = "{host}{path}/256/{z}/{x}/{y}/2/1_1.png"`.
**IMD** (`IMD_ENABLED`, `IMD_BASE_URL=https://mausam.imd.gov.in/api`): `current_wx_api.php?id=`, `nowcastapi.php?id=`, `warnings_district_api.php?id=`. Station/district ids: `data/imd_ids.json` map for curated cities (populate what is known; unknown → skip). On 401 containing "whitelisted" → mark provider `unavailable` for 10 min, log once, return None. Parse defensively; any exception → None. Document whitelisting request path in README.
Every provider call: httpx.AsyncClient, timeout `HTTP_TIMEOUT_S`, 1 retry on 5xx/timeouts, cached by rounded (lat, lon, 2 dp) + kind with TTLs from 01.

## Snapshot assembly (`services/snapshot.py`)
1. Resolve location (reverse geocode if only lat/lon; curated hit if within 3 km).
2. Fetch forecast, air, marine (only if `is_coastal` candidate or unknown) concurrently (`asyncio.gather`), IMD in parallel when enabled.
3. Normalize into `Snapshot` (04). Fill `current.uv_index`/`visibility_km` from hourly.
4. Compute derived services; attach `sources` and `fetched_at`.
5. Apply scenario overlay if `scenario != live` (deep-merge JSON: `overrides.current`, `overrides.hourly_all` (broadcast to each hour), `overrides.daily_all`, `overrides.air_quality`, `overrides.marine`, plus `warnings[]` appended with `source: scenario`, `nowcast` replaced). Recompute derived after overlay.
6. Cache the assembled snapshot 5 min keyed by (lat2dp, lon2dp, scenario).

## Formulas
**CPCB AQI** (sub-index per pollutant, linear interpolation inside band; AQI = max; dominant = argmax).
| Band | PM2.5 | PM10 | NO2 | O3 | SO2 | CO (mg/m³) | AQI |
|---|---|---|---|---|---|---|---|
| Good | 0–30 | 0–50 | 0–40 | 0–50 | 0–40 | 0–1 | 0–50 |
| Satisfactory | 31–60 | 51–100 | 41–80 | 51–100 | 41–80 | 1.1–2 | 51–100 |
| Moderate | 61–90 | 101–250 | 81–180 | 101–168 | 81–380 | 2.1–10 | 101–200 |
| Poor | 91–120 | 251–350 | 181–280 | 169–208 | 381–800 | 10.1–17 | 201–300 |
| Very Poor | 121–250 | 351–430 | 281–400 | 209–748 | 801–1600 | 17.1–34 | 301–400 |
| Severe | 250+ | 430+ | 400+ | 748+ | 1600+ | 34+ | 401–500 |
Open-Meteo CO is µg/m³ → divide by 1000. Category advice strings live in i18n.
**Dew point** (Magnus): `γ = ln(RH/100) + 17.625·T/(243.04+T); Td = 243.04·γ/(17.625−γ)`.
**Heat index** (NWS Rothfusz, °F): if T ≥ 80°F: `HI = −42.379 + 2.04901523T + 10.14333127R − 0.22475541TR − 0.00683783T² − 0.05481717R² + 0.00122874T²R + 0.00085282TR² − 0.00000199T²R²` with the two NWS adjustments; else `HI = 0.5·(T + 61 + (T−68)·1.2 + R·0.094)`. Convert back to °C. `feels_like_c` = Open-Meteo apparent temperature; `heat_index_c` = this.
**Beaufort** (km/h upper bounds): 1,5,11,19,28,38,49,61,74,88,102,117, else 12.
**Sea state** (Douglas by wave height) and **surf/swim** rules: 02 §16. **Visibility** categories: 02 §29.
**Workout score / windows, school commute, commute impact & delay, frost risk, packing rules, comfort index, flight risk**: exactly as in 02.
**Tides (estimated)**: `P = 12.4206012 h`. `days_since_new_moon = ((t − 2000-01-06T18:14Z) / 1 day) mod 29.530588853`; `spring = 0.7 + 0.3·|cos(2π·days_since_new_moon / 14.765294)|`; amplitude `A = amp[state]·spring` with amp: Gujarat 3.0, Maharashtra 1.8, Goa 1.1, Karnataka 0.9, Kerala 0.6, Tamil Nadu 0.6, Puducherry 0.6, Andhra Pradesh 0.9, Odisha 1.4, West Bengal 2.2, Andaman 1.2, Lakshadweep 0.8, default 1.0; `height(t) = A·cos(2π·(t − t0)/P + φ)`, `φ = 2π·(lon/360)` (deterministic pseudo-phase), `t0 = 2000-01-01T00:00Z`. Sample 5-min steps for 30 h → extrema = events. `source: "estimated"`, disclaimer key `tides.disclaimer`.
**Pollen (estimated)** when Open-Meteo pollen null: monthly base (index 0–4) tree `[1,3,3,3,2,1,0,0,1,2,1,1]`, grass `[1,2,3,3,2,1,1,1,2,2,2,1]`, weed `[1,1,1,1,1,1,1,2,3,3,2,1]` (Jan..Dec); −1 if rain in last 6 h or humidity > 85; +1 if wind > 20 and humidity < 50; clamp 0–4; index = max; level: 0 Low, 1 Low, 2 Moderate, 3 High, 4 Very High (Extreme never for estimates).
**Traffic (estimated)**: congestion base by hour: 8–10 & 17–20 → 70; 7,10,16,20 → 50; 11–15 → 40; else 20; × weather multiplier (rain 1.3, heavy 1.6, fog 1.5, storm 1.8), cap 100. TomTom when `TOMTOM_KEY`.
**Nowcast (derived)** when IMD unavailable: next 3 h max of precip prob / codes: thunderstorm codes (95–99) → severe "Thunderstorm likely"; precip prob ≥ 60 or codes 61–82 → moderate "Rain likely by HH:MM"; fog 45/48 → moderate; else none "No significant weather in next 3 hours".
**Warnings merge**: IMD (when available) + admin-injected (DB, `expires_at > now`) + scenario. Filter: same district, or same state for cyclone/heatwave/cold_wave, or within `radius_km` of (lat, lon). Sort severity desc.

## Scenarios (`data/scenarios/*.json`)
`live` (no overlay), `clear_pleasant`, `heatwave`, `heavy_rain`, `thunderstorm`, `cyclone` (adds red cyclone warning; marine overrides wave 4.5 m), `dense_fog` (visibility 0.2 km, hourly 0.3), `frost` (tmin −1, clear, calm), `severe_aqi` (pm2_5 320, pm10 480), `monsoon_flood` (orange very_heavy_rain + hourly prob 90, 22 mm/h). Each file: `{"name","description","overrides":{...},"warnings":[...],"nowcast":{...}}`. Scenario warnings use the request location's district/state.

## i18n
`app/data/i18n/<lang>.json`, flat keys with `{placeholders}`; `en` and `hi` complete; `mr`, `ta`, `bn`
may be partial (fallback to `en` per key; tests assert no missing keys for en/hi). Keys cover:
`card.<type>.title`, categories, `reason.*`, `insight.<type>.*` templates, `advice.*`, `condition.<code>`,
`tides.disclaimer`, `estimated`. Condition text for Hindi uses IMD-style vocabulary (e.g. "गरज के साथ बारिश").

## Admin console (`/admin/console`)
Single-file HTML/JS. Fields: backend base (prefilled), admin key (localStorage). Panels: (1) Scenario
buttons with active highlight; (2) Demo clock (datetime-local → now-override, "Clear"); (3) Push
warning form (severity, hazard, title, description, location: select from `/locations/popular` or
lat/lon, radius, TTL) + presets: "Orange thunderstorm — Delhi", "Red cyclone — Goa", "Orange dense fog — Delhi",
"Red heatwave — Nagpur", "Orange very heavy rain — Mumbai"; (4) Active warnings table with delete; (5)
Connected WS clients count (auto refresh 5 s); (6) Reset user learning by id.

## WebSocket manager (`api/ws.py`)
In-memory `{ws: {user_id, lat, lon}}`; ping every 30 s; drop on failure. `broadcast_warning(w)` sends
to all with `affects_you` = within `radius_km` or district/state match. `broadcast(type, payload)` for
scenario/now-override changes.

## Performance
`/home` fetches saved-place snapshots concurrently (max 5, `lite` fields only). Snapshot cache 5 min;
provider caches per 01. Log timing per request at INFO (`home lat lon personas ms`).

## Tests (must pass, offline — no network in tests)
`pytest -q` with `respx` mocking every external host using recorded JSON fixtures captured once by
`scripts/record_fixtures.py` (run it manually; commit the JSON). Coverage targets: providers parse,
CPCB table edges (30/31, 250+), dew point/heat index known values, workout windows on a synthetic
day, school-commute verdict table, frost table, tides determinism, pollen fallback, engine tests from
03, API tests: guest → profile → home for each persona (8) → events → learning effect → admin warning
→ home pinned → ws receives `warning_issued`; i18n hi has every en key; `lite` trims arrays.
