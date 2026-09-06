# 04 · API contract (normative — backend and app both conform to this)

Base URL: `{BACKEND}/api/v1`. JSON UTF-8. Times are ISO-8601 with offset in the **location's**
timezone (`2026-09-07T07:30:00+05:30`). Units: °C, km/h, mm, km, hPa, m, µg/m³.
Auth: `Authorization: Bearer <jwt>` (guest or OTP user). Language: `?lang=hi` or
`Accept-Language`; default `en`. Errors: `{"error": {"code": "string", "message": "string"}}`
with the proper HTTP status (400 validation, 401 auth, 404, 429, 502 upstream, 503 no data).

## Endpoints
| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/health` | – | `{status, version, time, providers:{imd, open_meteo, marine, air}, scenario, now_override}` |
| POST | `/auth/guest` | – | `{token, user}` — creates a guest user |
| POST | `/auth/request-otp` `{phone}` | – | `{ok:true, demo_otp:"123456"}` (`demo_otp` only when `DEMO_MODE=1`) |
| POST | `/auth/verify-otp` `{phone, otp}` | – | `{token, user}`; merges a guest if `X-Guest-Token` header present |
| GET | `/me` | ✓ | `User` |
| PUT | `/me/profile` | ✓ | body: partial `User` fields `personas, language, units, home_location, school_windows, commute_windows` → `User` |
| GET | `/me/card-prefs` | ✓ | `{pins:[type], hidden:[type]}` |
| PUT | `/me/card-prefs` | ✓ | same body → same |
| POST | `/me/reset-learning` | ✓ | clears engagement + prefs → `{ok:true}` |
| GET | `/me/places` | ✓ | `Place[]` |
| POST | `/me/places` | ✓ | `{name, lat, lon, country, country_code, admin1, admin2, kind}` → `Place` (max 8) |
| DELETE | `/me/places/{id}` | ✓ | `{ok:true}` |
| GET | `/locations/search?q=&limit=8` | – | `LocationResult[]` (India first, then world) |
| GET | `/locations/reverse?lat=&lon=` | – | `LocationResult` |
| GET | `/locations/popular` | – | `LocationResult[]` curated Indian cities (≥ 40, includes coastal + hill) |
| GET | `/home` | ✓ | **the personalized home** — see params + `HomeResponse` |
| GET | `/weather/snapshot?lat=&lon=&scenario=` | – | `Snapshot` (for detail screens / debugging) |
| GET | `/weather/radar` | – | `{host, past:[{time,path}], nowcast:[{time,path}], tile_template}` |
| POST | `/events` | ✓ | `{events:[{type, action, ts, meta?}]}` → `{ok:true, engagement:{type:{taps,expands,dismisses,pins,impressions}}}` |
| GET | `/admin/state` | admin | `{scenario, now_override, warnings:Warning[], connected_clients}` |
| POST | `/admin/scenario` `{name}` | admin | sets global default scenario → state |
| POST | `/admin/now-override` `{now: ISO or null}` | admin | global demo clock → state |
| POST | `/admin/warnings` | admin | `{severity, hazard, title, description, district?, state?, lat?, lon?, radius_km=75, ttl_minutes=120}` → `Warning`; broadcasts on WS |
| DELETE | `/admin/warnings/{id}` | admin | `{ok:true}`; broadcasts `warning_cleared` |
| POST | `/admin/reset-user` `{user_id}` | admin | `{ok:true}` |
| GET | `/admin/console` | – (key entered in page) | HTML demo console |
| WS | `/ws/alerts?token=&lat=&lon=` | ✓ | live alerts (below) |

Admin auth: header `X-Admin-Key: <ADMIN_KEY>` (env; default `mausam-admin` in DEMO_MODE).

### `GET /home` query params
`lat`, `lon` (required unless `place_id`), `place_id` (saved place or curated id), `lang`,
`personas` (comma list; overrides profile personas for this request only — "switch role view"),
`now_override` (ISO; demo clock; overrides admin global), `scenario` (name; overrides global),
`event_date` (YYYY-MM-DD; focus date for `rain_probability`), `lite=1` (hourly arrays trimmed to
12, radar frames to 3, `more_cards` omitted).

## Objects
```jsonc
User {
  "id": "usr_…", "phone": "+91…" | null, "is_guest": true, "language": "en", "units": "metric",
  "personas": [{"id": "parent", "weight": 1.0}, {"id": "commuter", "weight": 0.7}],
  "home_location": LocationResult | null,
  "school_windows": [{"label":"morning_drop","start":"07:00","end":"09:00"},{"label":"afternoon_pickup","start":"13:00","end":"16:00"}],
  "commute_windows": [{"label":"morning","start":"08:00","end":"10:00"},{"label":"evening","start":"17:00","end":"20:00"}],
  "created_at": "…"
}
LocationResult {
  "id": "geo:28.61,77.21" | "city:delhi", "name": "New Delhi", "admin1": "Delhi", "admin2": "New Delhi",
  "country": "India", "country_code": "IN", "lat": 28.61, "lon": 77.21, "timezone": "Asia/Kolkata",
  "is_coastal": false, "elevation_m": 216, "population": 16787941 | null
}
Place { "id": "plc_…", "name", "lat", "lon", "country", "country_code", "admin1", "admin2",
        "kind": "home|work|school|travel|other", "timezone", "is_coastal", "created_at" }
Warning { "id", "severity": "yellow|orange|red", "hazard": "heavy_rain|very_heavy_rain|thunderstorm|lightning|squall|hail|heatwave|cold_wave|fog|dust_storm|cyclone|strong_wind|snow|flood|other",
          "title", "description", "issued_at", "valid_from", "valid_to", "district": str|null, "state": str|null,
          "lat": num|null, "lon": num|null, "radius_km": num|null, "source": "imd|admin|scenario", "color_hex": "#F28C28" }
Reason { "code": "persona:health", "text": "Because you follow Health" }
Insight { "headline": "Avoid outdoor exercise today", "detail": "PM2.5 is 190 µg/m³ …", "icon": "mask" }
Action { "id": "details|share|pin|unpin|dismiss|hide|open_map|open_places|open_settings", "label": "Details" }
Card {
  "type": "aqi", "instance_id": "aqi", "title": "Air quality", "subtitle": "Very Poor · 312",
  "size": "hero|large|medium|small", "renderer": "gauge",          // renderer kind from 02
  "urgency": 0.75, "severity": "info|advisory|watch|warning|severe", "pinned": false, "score": 0.81,
  "reasons": [Reason], "insight": Insight, "data": { … per 02 … }, "actions": [Action],
  "personas": ["health"], "source": "open-meteo|imd|estimated|scenario|mixed", "estimated": false,
  "updated_at": "…"
}
HomeResponse {
  "generated_at": "…", "location": LocationResult,
  "context": { "now": "…", "daypart": "dawn", "is_weekend": false, "season": "monsoon",
               "is_coastal": false, "scenario": "live", "active_personas": ["parent","commuter"],
               "warning_count": 1, "lang": "en" },
  "banner": { "warning_id", "severity", "title", "color_hex" } | null,   // highest active ≥ orange
  "pinned": [Card], "hero": Card, "cards": [Card], "more_cards": [Card], "hidden_types": ["pollen"],
  "freshness": { "weather": "…", "air": "…", "marine": "…"|null, "warnings": "…" },
  "sources":   { "weather": "open-meteo", "air": "open-meteo", "marine": "open-meteo"|null, "warnings": "admin|imd|scenario|none" },
  "engine": { "version": "1.0", "weights": {"relevance": 0.5, "urgency": 0.5} }
}
Snapshot {
  "location": LocationResult, "fetched_at": "…", "sources": {…},
  "current": { "time", "temp_c", "feels_like_c", "humidity_pct", "dew_point_c", "wind_kph", "wind_dir_deg", "gust_kph",
               "pressure_hpa", "visibility_km", "uv_index", "cloud_pct", "precip_mm", "condition_code", "condition_text", "is_day" },
  "hourly": [ { "time", "temp_c", "feels_like_c", "humidity_pct", "dew_point_c", "precip_prob_pct", "precip_mm", "wind_kph",
                "wind_dir_deg", "gust_kph", "uv_index", "visibility_km", "cloud_pct", "condition_code", "is_day",
                "soil_moisture_surface", "soil_moisture_root", "soil_temp_c" } ],   // 48
  "daily": [ { "date", "tmax_c", "tmin_c", "feels_like_max_c", "precip_prob_max_pct", "precip_sum_mm", "uv_index_max",
               "sunrise", "sunset", "daylight_minutes", "wind_max_kph", "gust_max_kph", "condition_code" } ],  // 16
  "air_quality": { "time", "aqi", "category", "dominant_pollutant", "pm2_5", "pm10", "o3", "no2", "so2", "co", "hourly": [{"time","aqi"}], "source" },
  "pollen": { "index", "level", "dominant", "by_type": {"tree","grass","weed"}, "source" },
  "marine": null | { "time", "wave_height_m", "wave_period_s", "wave_direction_deg", "swell_height_m", "current_kph", "sst_c", "sea_state", "hourly": [{"time","wave_height_m"}], "source" },
  "tides": null | { "events": [{"time","type","height_m"}], "now_height_m", "trend", "source": "estimated" },
  "warnings": [Warning], "nowcast": { "issued_at", "valid_till", "text", "severity", "hazards", "source" },
  "traffic": { "congestion_pct", "source" },
  "derived": { "comfort": {…}, "heat": {…}, "workout": {…}, "school_commute": {…}, "commute": {…}, "frost": {…},
               "visibility": {…}, "flight_risk": {…}, "packing": {…}, "planting": {…} }     // shapes per 02 data
}
```
`condition_text` is localized; `condition_code` is the WMO code (0,1,2,3,45,48,51,53,55,56,57,61,63,65,66,67,71,73,75,77,80,81,82,85,86,95,96,99).

## WebSocket `/ws/alerts`
Client connects with `token`, `lat`, `lon`. Server → client messages:
```jsonc
{"type":"hello","server_time":"…","scenario":"live"}
{"type":"ping"}                                   // every 30 s; client replies {"type":"pong"}
{"type":"warning_issued","warning":Warning,"affects_you":true}
{"type":"warning_cleared","id":"…"}
{"type":"scenario_changed","scenario":"heatwave"}
{"type":"now_override","now":"…"|null}
```
Client → server: `{"type":"pong"}`, `{"type":"location","lat":..,"lon":..}` (when user changes
location). On `warning_issued` with `affects_you` or on `scenario_changed`/`now_override`, the
app re-fetches `/home` and animates the diff.

## Engagement events (`POST /events`)
`type` = card type, `action` ∈ `impression|tap|expand|dismiss|pin|unpin|hide|unhide`, `ts` ISO,
`meta` optional `{location_id, position}`. Batch ≤ 100. `pin/unpin/hide/unhide` also update
card-prefs server-side so the app does not need a second call.
