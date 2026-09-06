# 02 · Card catalog (normative)

Every bullet of the problem statement maps to at least one card. Card `type` ids below are
exact strings used in the API, engine, DB, events and Flutter renderer registry.

## Card anatomy (see 04 for JSON)
`type`, `title`, `subtitle`, `size` (hero|large|medium|small), `urgency` 0..1, `severity`
(info|advisory|watch|warning|severe), `pinned`, `score`, `reasons[]`, `insight{headline, detail, icon}`,
`data{...}` (typed per card, below), `actions[]`, `personas[]`, `source`, `updated_at`.

Severity from urgency: `<0.3 info · <0.5 advisory · <0.7 watch · <0.85 warning · else severe`.

## Dayparts and seasons used by time/season multipliers
- Dayparts (local hour): `night` 0–5 · `dawn` 5–8 · `morning` 8–11 · `midday` 11–15 · `afternoon` 15–18 · `evening` 18–21 · `late` 21–24
- IMD seasons (month): `winter` Jan–Feb · `pre_monsoon` Mar–May · `monsoon` Jun–Sep · `post_monsoon` Oct–Dec
- Multipliers default to 1.0; only exceptions are listed per card. Weekend = Sat/Sun.

## Affinity matrix (0..1). `base` applies to every user with weight 1.0.
| type | base | health | fitness | beach | traveler | parent | agriculture | commuter | event_planner | gate |
|---|---|---|---|---|---|---|---|---|---|---|
| current_conditions | hero, always first after pinned | | | | | | | | | |
| warnings | 0.6 | 0.6 | 0.6 | 0.7 | 0.7 | 1.0 | 0.7 | 0.7 | 0.6 | ≥1 active warning |
| nowcast | 0.5 | 0.4 | 0.5 | 0.5 | 0.4 | 0.6 | 0.5 | 0.7 | 0.4 | |
| hourly_forecast | 0.5 | 0.3 | 0.5 | 0.4 | 0.4 | 0.5 | 0.4 | 0.6 | 0.5 | |
| daily_forecast | 0.5 | 0.3 | 0.4 | 0.4 | 0.6 | 0.5 | 0.5 | 0.3 | 0.6 | |
| radar | 0.3 | 0.2 | 0.3 | 0.4 | 0.3 | 0.4 | 0.4 | 0.5 | 0.3 | |
| aqi | 0.2 | 1.0 | 0.6 | 0.2 | 0.2 | 0.5 | 0.1 | 0.4 | 0.2 | |
| pollen | 0.0 | 0.9 | 0.2 | 0 | 0 | 0.2 | 0.2 | 0 | 0 | |
| uv_index | 0.2 | 0.8 | 0.7 | 0.8 | 0.2 | 0.3 | 0.3 | 0.1 | 0.3 | |
| humidity | 0.1 | 0.8 | 0.3 | 0.2 | 0.1 | 0.1 | 0.3 | 0.1 | 0.3 | |
| health_advisory | 0 | 1.0 | 0.3 | 0 | 0 | 0.3 | 0 | 0 | 0 | |
| best_workout_window | 0 | 0.4 | 1.0 | 0.2 | 0 | 0 | 0 | 0 | 0 | |
| sun_times | 0.2 | 0.1 | 0.8 | 0.5 | 0.2 | 0.1 | 0.4 | 0.1 | 0.3 | |
| wind | 0.1 | 0.1 | 0.7 | 0.7 | 0.2 | 0.1 | 0.4 | 0.2 | 0.3 | |
| heat_alert | 0.3 | 0.5 | 0.9 | 0.4 | 0.3 | 0.6 | 0.5 | 0.3 | 0.4 | feels_like ≥ 35 or heatwave warning |
| sea_conditions | 0 | 0 | 0.1 | 1.0 | 0.2 | 0.1 | 0 | 0 | 0.1 | coastal |
| tides | 0 | 0 | 0 | 1.0 | 0.1 | 0 | 0 | 0 | 0 | coastal |
| water_temp | 0 | 0 | 0.1 | 0.7 | 0 | 0 | 0 | 0 | 0 | coastal |
| saved_places | 0.3 | 0.1 | 0.1 | 0.1 | 1.0 | 0.2 | 0.1 | 0.2 | 0.2 | ≥1 saved place |
| travel_alerts | 0 | 0 | 0 | 0 | 1.0 | 0.1 | 0 | 0.2 | 0.1 | ≥1 saved place |
| packing_suggestions | 0 | 0 | 0 | 0.2 | 0.9 | 0.1 | 0 | 0 | 0 | ≥1 saved place |
| school_commute | 0 | 0 | 0 | 0 | 0 | 1.0 | 0 | 0.2 | 0 | |
| rain_alert | 0.3 | 0.2 | 0.4 | 0.3 | 0.3 | 0.9 | 0.5 | 0.8 | 0.5 | precip prob ≥ 40% within 12 h or rain warning |
| soil_moisture | 0 | 0 | 0 | 0 | 0 | 0 | 1.0 | 0 | 0 | |
| rainfall_outlook | 0 | 0 | 0 | 0 | 0 | 0.1 | 1.0 | 0 | 0.4 | |
| frost_alert | 0 | 0.1 | 0.1 | 0 | 0 | 0.2 | 1.0 | 0.1 | 0.1 | frost risk ≥ low or cold-wave warning |
| planting_guidance | 0 | 0 | 0 | 0 | 0 | 0 | 0.8 | 0 | 0 | |
| commute_conditions | 0 | 0 | 0 | 0 | 0.1 | 0.4 | 0 | 1.0 | 0 | |
| visibility | 0.1 | 0 | 0.1 | 0.1 | 0.5 | 0.2 | 0.1 | 0.9 | 0.1 | |
| storm_fog_alert | 0.2 | 0.1 | 0.2 | 0.3 | 0.6 | 0.5 | 0.3 | 1.0 | 0.3 | hazard detected or warning |
| extended_forecast | 0 | 0 | 0 | 0.1 | 0.5 | 0.1 | 0.4 | 0 | 1.0 | |
| rain_probability | 0.1 | 0 | 0.1 | 0.2 | 0.2 | 0.3 | 0.2 | 0.2 | 1.0 | |
| comfort_index | 0 | 0.4 | 0.3 | 0.3 | 0.2 | 0.2 | 0 | 0 | 1.0 | |

Coverage check: health→aqi,pollen,uv_index,humidity,health_advisory · fitness→sun_times,
best_workout_window,wind,heat_alert · beach→sea_conditions,tides,water_temp · traveler→
saved_places,travel_alerts,packing_suggestions · parent→school_commute,rain_alert,warnings ·
agriculture→soil_moisture,rainfall_outlook,frost_alert,planting_guidance · commuter→
commute_conditions,visibility,storm_fog_alert · event_planner→extended_forecast,
rain_probability,comfort_index. All eight bullets covered.

## Shared objects
`Warning`: `{id, severity: yellow|orange|red, hazard: heavy_rain|very_heavy_rain|thunderstorm|
lightning|squall|hail|heatwave|cold_wave|fog|dust_storm|cyclone|strong_wind|snow|flood|other,
title, description, issued_at, valid_from, valid_to, district, state, source: imd|admin|scenario,
color_hex}` · colours: yellow `#F5C518`, orange `#F28C28`, red `#D32F2F`, green (all clear) `#2E7D32`.
`HourPoint`: `{time (ISO local), ...fields}`. All temps °C, wind km/h, precip mm, visibility km,
pressure hPa, wave m, times ISO-8601 with offset (`2026-09-07T07:30:00+05:30`).

## Per-card specification
Format: **type** (size · renderer) — `data` keys — insight rule — urgency rule — multipliers.

1. **current_conditions** (hero · `hero`) — `temp_c, feels_like_c, condition_code, condition_text, icon, humidity_pct, wind_kph, wind_dir, uv_index, visibility_km, pressure_hpa, tmax_c, tmin_c, is_day, aqi, aqi_category, sunrise, sunset, all_clear, updated_at`.
   Insight: one line composed from the two most notable values (e.g. "Feels like 41°, humid; AQI Poor"). Urgency 0. Always first after pinned.
2. **warnings** (large · `warnings`) — `warnings: Warning[], district, highest_severity`. Insight: headline = highest warning title. Urgency: yellow 0.5 · orange 0.8 · red 1.0. Pinned when ≥ orange.
3. **nowcast** (medium · `nowcast`) — `issued_at, valid_till, text, severity (none|moderate|severe), hazards[], source`. Built from IMD nowcast when available, else derived from next-3h hourly (rain prob/thunder codes). Urgency: moderate 0.5 · severe 0.75. Multipliers: `late`/`night` ×0.7.
4. **hourly_forecast** (large · `hourly`) — `hours[24]: {time, temp_c, precip_prob_pct, precip_mm, condition_code, icon, wind_kph, is_day}`. Urgency 0.
5. **daily_forecast** (large · `daily`) — `days[7]: {date, tmax_c, tmin_c, precip_prob_max_pct, precip_sum_mm, condition_code, icon}`. Urgency 0. `evening` ×1.2 (planning tomorrow).
6. **radar** (medium · `radar`) — `host, frames[]: {time, path}, tile_template, center{lat,lon}, zoom, rain_within_2h_prob_pct`. Urgency: `rain_within_2h_prob_pct ≥ 60` → 0.4.
7. **aqi** (medium · `gauge`) — `aqi, category (Good|Satisfactory|Moderate|Poor|Very Poor|Severe), dominant_pollutant, pm2_5, pm10, o3, no2, so2, co, hourly[24]: {time, aqi}, advice, scale: "CPCB"`. Insight: CPCB health advisory text for category; for `fitness` persona add "avoid outdoor exercise" when Poor+. Urgency: Moderate 0.3 · Poor 0.55 · Very Poor 0.75 · Severe 0.95. Multipliers: `dawn`,`evening` ×1.2; `winter`,`post_monsoon` ×1.2.
8. **pollen** (small · `metric`) — `index (0–4), level (Low|Moderate|High|Very High|Extreme), dominant (tree|grass|weed), by_type{tree,grass,weed}, advice, source ("open-meteo"|"estimated")`. Urgency: High 0.4 · Very High+ 0.6. `pre_monsoon` ×1.3, `monsoon` ×0.6. UI shows "Estimated" chip when source=estimated.
9. **uv_index** (small · `metric`) — `uv_now, uv_max_today, uv_max_time, category (Low|Moderate|High|Very High|Extreme), safe_exposure_min, hourly[]: {time, uv}`. WHO bands 0–2/3–5/6–7/8–10/11+. Urgency: ≥8 → 0.5, ≥11 → 0.7. `morning`,`midday` ×1.3; `night`,`late` ×0.3.
10. **humidity** (small · `metric`) — `humidity_pct, dew_point_c, category (Dry|Comfortable|Humid|Oppressive), trend (rising|steady|falling), advice`. Bands by dew point: <10 Dry, 10–16 Comfortable, 16–21 Humid, >21 Oppressive; humidity_pct < 25 → Dry. Urgency: ≥85% or ≤20% → 0.3. `monsoon` ×1.2.
11. **health_advisory** (medium · `advice_list`) — `items[]: {icon, title, detail, level (info|advisory|warning)}` composed from aqi (mask), uv (sunscreen), humidity (asthma/skin), heat (hydrate), pollen (allergy). Urgency = max of contributing card urgencies. Only built when ≥1 item non-info.
12. **best_workout_window** (medium · `timeline`) — `windows[≤3]: {start, end, score 0–100, temp_c, aqi, uv, humidity_pct, label}, best, hourly_scores[24]: {time, score}, no_good_window_reason`. Score/hour = 100 − penalties: temp >30 (−3/°C), <8 (−3/°C), humidity >75 (−1/%), AQI >100 (−0.3/pt), UV >7 (−8/pt), rain prob >40 (−1/%), wind >30 (−1/kph), dark (−25). Windows = runs ≥ 60 min with score ≥ 55; label "Great" ≥80, "Good" ≥65, "Fair" ≥55. Urgency: 0.2 if best exists, 0.4 if none (advisory). `dawn`,`evening` ×1.4; `late` ×0.5.
13. **sun_times** (small · `metric`) — `sunrise, sunset, daylight_minutes, golden_hour_morning{start,end}, golden_hour_evening{start,end}, civil_twilight_end`. Urgency 0. `dawn`,`evening` ×1.2.
14. **wind** (small · `metric`) — `speed_kph, gust_kph, direction_deg, direction_text, beaufort, beaufort_text, hourly[24]: {time, speed_kph}, advice`. Urgency: ≥40 → 0.4, ≥60 → 0.7, strong-wind warning → 0.8.
15. **heat_alert** (medium · `alert`) — `feels_like_c, temp_c, heat_index_c, level (caution|extreme_caution|danger|extreme_danger), peak_time, warning, advice[]`. Level by heat index: 27–32 caution, 32–41 extreme_caution, 41–54 danger, >54 extreme_danger. Urgency: caution 0.4 · extreme_caution 0.6 · danger 0.8 · extreme_danger 0.95 · red heatwave warning 1.0. `midday`,`afternoon` ×1.3; `pre_monsoon` ×1.3.
16. **sea_conditions** (large · `sea`) — `sea_state (Calm|Smooth|Slight|Moderate|Rough|Very Rough|High), wave_height_m, wave_period_s, wave_direction_deg, swell_height_m, current_kph, sst_c, safe_for_swimming, surf_rating 0–5, advisory, hourly[24]: {time, wave_height_m}`. Douglas scale by wave height: <0.1 Calm, <0.5 Smooth, <1.25 Slight, <2.5 Moderate, <4 Rough, <6 Very Rough, else High. safe_for_swimming = wave <1.5 and current <3 kph and no cyclone/strong-wind warning. Surf: 1.0–2.5 m + period ≥ 8 s → 4–5 stars. Urgency: Rough 0.6 · Very Rough+ 0.9 · cyclone warning 1.0.
17. **tides** (medium · `tides`) — `events[≤4]: {time, type (high|low), height_m}, next, now_height_m, trend (rising|falling), source: "estimated", disclaimer`. Urgency 0. Always labelled Estimated (see 05 for model).
18. **water_temp** (small · `metric`) — `sst_c, category (Cold <20|Cool 20–24|Pleasant 24–29|Warm >29), wetsuit_advice`. Urgency 0.
19. **saved_places** (large · `places`) — `places[]: {id, name, lat, lon, country, local_time, temp_c, condition_code, icon, tmax_c, tmin_c, precip_prob_pct, highest_severity}`. Urgency: max severity across places: orange 0.6 · red 0.8.
20. **travel_alerts** (medium · `advice_list`) — `alerts[]: {place_id, place_name, risk (low|medium|high), hazards[] (fog|thunderstorm|strong_wind|cyclone|heavy_rain|snow|dust_storm), detail, warnings[]}`. Flight-risk rule: visibility <1 km or thunderstorm code or gust ≥60 kph or cyclone/red warning → high; visibility <3 km or gust ≥45 or orange warning or rain prob ≥70 → medium. Urgency: medium 0.4 · high 0.8. Card omitted if all low.
21. **packing_suggestions** (medium · `advice_list`) — `places[]: {place_id, place_name, days, items[]: {item, icon, reason}}`. Rules over next `days` (default 3): rain prob ≥40 any day → "Raincoat/umbrella"; tmin <12 → "Warm layers"; tmin <5 → "Heavy jacket"; UV max ≥8 → "Sunscreen & hat"; humidity ≥80 → "Light cotton"; wind ≥40 → "Windbreaker"; AQI ≥ Poor → "N95 mask"; snow code → "Boots"; feels_like ≥38 → "Extra water/ORS". Urgency 0.1.
22. **school_commute** (medium · `timeline`) — `windows[2]: {label (morning_drop|afternoon_pickup), start, end, verdict (good|caution|poor|avoid), temp_c, precip_prob_pct, visibility_km, aqi, reasons[]}, overall_verdict, advice, is_school_day`. Windows 07:00–09:00 and 13:00–16:00 local, next occurrence. Verdict: avoid if red/orange warning or thunderstorm or visibility <0.5; poor if rain prob ≥70 or visibility <1 or feels_like ≥42 or AQI Severe; caution if rain prob ≥40 or AQI Very Poor or feels_like ≥38 or visibility <2; else good. Urgency: caution 0.4 · poor 0.6 · avoid 0.85. Multipliers: weekday `dawn`,`morning` ×1.5, `midday`,`afternoon` ×1.3; weekend ×0.4.
23. **rain_alert** (medium · `alert`) — `next_rain_start, next_rain_end, peak_prob_pct, peak_time, expected_mm, intensity (light|moderate|heavy|very_heavy), hourly[12]: {time, precip_prob_pct, precip_mm}, warning`. Intensity by max hourly mm: <2.5 light, <7.6 moderate, <15 heavy, else very_heavy (IMD hourly bands approximated). Urgency: prob ≥70 within 3 h → 0.6; heavy+ or rain warning → 0.8. `monsoon` ×1.3.
24. **soil_moisture** (medium · `gauge`) — `surface_m3m3 (0–1 cm), root_zone_m3m3 (9–27 cm), status (very_dry <0.10|dry <0.18|adequate <0.30|wet <0.40|saturated), soil_temp_c, days_since_rain, advice`. Urgency: very_dry 0.4 · saturated 0.3. `dawn` ×1.2 (farmers plan early).
25. **rainfall_outlook** (medium · `bar_chart`) — `next_24h_mm, next_72h_mm, next_7d_mm, daily[7]: {date, mm, prob_pct}, rain_days, advice`. Urgency: next_72h ≥ 50 mm → 0.5, ≥ 115 mm → 0.7 (IMD "very heavy" daily band).
26. **frost_alert** (medium · `alert`) — `risk (none|low|moderate|high), tmin_c, expected_night, wind_kph, cloud_pct, warning, advice[]`. Risk: tmin ≤ 0 high; ≤ 2 → high if wind <10 & cloud <30 else moderate; ≤ 4 → moderate if wind <10 & cloud <30 else low; ≤ 6 → low; cold-wave warning → ≥ moderate. Urgency: low 0.3 · moderate 0.55 · high 0.85. `winter` ×1.3; `evening` ×1.3.
27. **planting_guidance** (medium · `advice_list`) — `season (kharif|rabi|zaid), zone, month, crops[≤4]: {name, stage (sow|grow|irrigate|harvest|protect), action}, tips[]`. From `data/planting_calendar.json` keyed by zone (north|south|east|west|central|northeast|hills) × month, enriched with soil moisture & rainfall outlook (e.g. "Delay irrigation: 35 mm expected in 3 days"). Urgency 0.
28. **commute_conditions** (medium · `timeline`) — `windows[2]: {label (morning|evening), start, end, impact (low|moderate|high|severe), delay_min, rain_prob_pct, visibility_km, temp_c, reasons[]}, traffic{congestion_pct, source}, advice`. Windows 08:00–10:00, 17:00–20:00 local. Impact: severe if red/orange storm/fog warning or visibility <0.5; high if rain prob ≥70 or visibility <1 or thunderstorm; moderate if rain prob ≥40 or visibility <2 or wind ≥40; else low. delay_min = base(peak 12, off-peak 5) × multiplier(rain 1.3, heavy 1.6, fog 1.5, storm 1.8). Urgency: moderate 0.4 · high 0.7 · severe 0.9. Weekday `dawn`,`morning`,`afternoon`,`evening` ×1.4; weekend ×0.5.
29. **visibility** (small · `metric`) — `visibility_km, category (Excellent ≥10|Good ≥4|Moderate ≥2|Poor ≥1|Very Poor ≥0.5|Dense fog), fog_expected_hours[]: {time, visibility_km}, advice`. Urgency: <2 → 0.5, <0.5 → 0.8. `winter` ×1.3; `dawn` ×1.3.
30. **storm_fog_alert** (medium · `alert`) — `hazard (thunderstorm|fog|squall|dust_storm|hail), level (watch|warning|severe), window{start,end}, detail, warning, advice[]`. Built when a warning of those hazards exists, or hourly codes show thunderstorm (WMO 95–99) / fog (45,48) within 12 h, or gusts ≥ 60. Urgency: watch 0.5 · warning 0.7 · severe 0.9.
31. **extended_forecast** (large · `daily`) — `days[14]: {date, tmax_c, tmin_c, precip_prob_max_pct, precip_sum_mm, condition_code, icon}, confidence_note`. Urgency 0. Weekend ×1.2.
32. **rain_probability** (medium · `bar_chart`) — `focus_date, focus_label, by_day[7]: {date, prob_pct, mm}, hourly_focus[24]: {time, prob_pct}, verdict (dry <20|possible <50|likely <75|wet), advice`. focus_date = next Saturday unless `?event_date=` given. Urgency 0.
33. **comfort_index** (medium · `gauge`) — `index 0–100, category (Uncomfortable <40|Fair <60|Comfortable <80|Ideal), feels_like_c, humidity_pct, wind_kph, uv, best_hours_today[≤2]: {start,end,index}, daily[7]: {date, index}, advice`. Index = 100 − |feels_like − 24| × 3 − max(0, humidity − 60) × 0.8 − max(0, 30 − humidity) × 0.5 − max(0, wind − 20) × 0.8 − max(0, uv − 6) × 3 − precip_prob × 0.3, clamped 0..100. Urgency 0. `evening` ×1.2.

## Icons
`icon` is a stable string from this set (app maps to Material/custom glyphs): `sun, moon, cloud,
partly_cloudy, rain, heavy_rain, thunderstorm, fog, haze, wind, snow, hail, dust, cyclone,
aqi, mask, uv, humidity, pollen, run, sunrise, sunset, heat, wave, tide, water, plane, suitcase,
school, umbrella, soil, sprout, frost, traffic, eye, storm, calendar, comfort, warning, radar, pin`.
`condition_code` = WMO weather code (Open-Meteo); app maps code+is_day → icon.
