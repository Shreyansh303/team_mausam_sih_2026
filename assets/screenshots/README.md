# Screenshots

Every image in this folder is the Flutter web build of the app driven against a locally running
backend (live Open-Meteo data for New Delhi and Panaji, `DEMO_MODE=1`), captured from headless
Chrome at a 390×844 @2 mobile viewport, so each file is a 780×1688 portrait PNG; the offline shots
were taken with the backend stopped. They are the images embedded in the root
[README](../../README.md) (§10) and cited row by row in the end-to-end QA walk in
[docs/QA_REPORT.md](../../docs/QA_REPORT.md), whose Screenshot column gives paths as
`assets/screenshots/<file>`.

63 files: 40 from the QA walk (`c1_*`) and 23 from earlier build milestones (`b1_`, `b2a_`,
`b2b_`, `b3_`).

## Recommended first look

| File | What it shows |
|---|---|
| `c1_step03_persona_parent.png` | The Parent home screen — one of the eight `c1_step03_persona_*.png` shots that make up the "same morning, eight home screens" grid in the root README: one backend, one morning, only the personas change (seven at New Delhi, Beach & sea at Panaji). |
| `c1_step02_morning_0730_parent_commuter.png` | Parent + Commuter with the demo clock at 07:30: School commute and Commute conditions ranked 1 and 2, and the hero reads the dawn forecast hour, not the live afternoon observation. |
| `c1_step05_ws_before.png` | Delhi feed before a warning is pushed — no banner, nothing pinned. |
| `c1_step05_ws_rerank.png` | Seconds later: an orange "Thunderstorm warning — Delhi" banner arrived over the WebSocket and the commute card is pinned to the top, with the re-rank SnackBar. |
| `c1_step08_hindi_home.png` | The same home with `lang=hi` — app chrome, card copy and reason chips localised, no raw i18n keys. |
| `c1_step07_offline_cached.png` | Backend stopped, cache warm: the full feed renders, the freshness chip reads "Updated just now · cached", and one strip says "Could not refresh. Showing saved data." |
| `c1_step04_coastal_tides_estimated.png` | The Tides card for Panaji with its single "Estimated" chip and the backend's own disclaimer that it is a simplified harmonic model, not an official tide table. |
| `c1_step06_why_sheet_pollen.png` | Long-press → "Why this?" sheet for the Pollen card: the card's reasons, its score, and what the ranker has learned from taps and dismissals. |
| `c1_step11_scenario_heatwave.png` | The `heatwave` scenario: red banner, pinned "Weather warnings (Red · Heatwave)" with `scenario` shown as the source, pinned "Heat alert 49° · Danger". |

## End-to-end QA walk (`c1_*`)

The step numbers are the judge demo script in `docs/00_VISION.md`, as walked in
`docs/QA_REPORT.md`; the "Step" column is the report's row id. Step 10 of the script is the close
and has no screenshot; the scenario shots are numbered `step11`.

### Onboarding

| File | Step | What it shows |
|---|---|---|
| `c1_step01_onboard_language.png` | 1a | First launch, language picker: English, हिन्दी, मराठी, தமிழ், বাংলা. The router redirects to onboarding until it completes. |
| `c1_step01_onboard_personas.png` | 1b | Persona picker: all 8 personas, 1–3 selectable, the first pick becomes the primary persona (weight 1.0, others 0.7). |
| `c1_step01_onboard_location.png` | 1c | Location step: GPS, free-text search and a popular-cities list; New Delhi resolves to 28.61/77.21, Asia/Kolkata. |
| `c1_step01_onboard_home.png` | 1d | First home screen against the live backend; the green dot on the freshness chip means `/ws/alerts` is connected. |

### Morning home

| File | Step | What it shows |
|---|---|---|
| `c1_step02_morning_0730_parent_commuter.png` | 2a, 2b | Parent + Commuter, demo clock 07:30: `school_commute` (0.95) and `commute_conditions` (0.532) at ranks 1 and 2, `daypart = dawn`; the hero reads 27 °C / feels like 31 °C from the forecast hour matching the override. |
| `c1_step02_morning_0730_scrolled.png` | 2c | The same feed scrolled down: every card carries its reason chips ("Because you follow Parenting", "The school run needs care (an advisory)"); the nowcast card is present. |
| `c1_step02_night_2200_parent_commuter.png` | 2d | Demo clock 22:00: School commute has left the top 3 (now health advisory, hourly forecast, daily forecast) — the spec's time-of-day test holding against the running service. |

### Persona switch

| File | Step | What it shows |
|---|---|---|
| `c1_step03_persona_fitness.png` | 3a | Fitness: Best workout window, Sun times, Wind and Heat alert rise into the main feed. |
| `c1_step03_persona_health.png` | 3b | Health: AQI, pollen, UV and humidity at the top of the feed. |
| `c1_step03_persona_parent.png` | 3c | Parent, New Delhi: the School run card leads ("Overall: Caution") with the afternoon-pickup and next-morning-drop windows and their verdicts. |
| `c1_step03_persona_commuter.png` | 3d | Commuter, New Delhi: "Your commute" leads, carrying the "Estimated" chip (traffic is modelled), with evening and next-morning windows at "Low impact", delay, rain and visibility. |
| `c1_step03_persona_traveler.png` | 3e | Traveller, New Delhi: the 7-day forecast leads the feed. |
| `c1_step03_persona_beach.png` | 3f | Beach & sea, Panaji: the UV index card leads (6.1 · High, peak 8.1 around 13:00, safe unprotected exposure about 11 minutes). |
| `c1_step03_persona_agriculture.png` | 3g | Farming, New Delhi: the Soil moisture gauge leads (40%, Wet; root zone, soil temperature, days since rain; "Soil is wet — skip irrigation"). |
| `c1_step03_persona_event_planner.png` | 3h | Event planner, New Delhi: the 14-day outlook leads, with rain chance and temperature-range bars per day. |
| `c1_step03_roleview_fitness.png` | 3i | "View as persona" from the demo sheet: the whole feed swaps to Fitness through the request-scoped `?personas=` override, without touching the saved profile. |

### Coastal

| File | Step | What it shows |
|---|---|---|
| `c1_step04_location_search_panaji.png` | 4a | Location search finds Panaji, Goa; the switch is instant. |
| `c1_step04_coastal_panaji_home.png` | 4b | Panaji home: Sea conditions, Tides (estimated) and Water temperature appear — the same three are absent for Delhi (coastal gating). |
| `c1_step04_coastal_sea.png` | 4c | Sea conditions card: wave height, period and direction, swell, sea-surface temperature and the sea-state band. |
| `c1_step04_coastal_tides_estimated.png` | 4d | Tides card: one "Estimated" chip plus the backend disclaimer ("Estimated from a simplified harmonic model — not an official tide table…"). Nothing modelled is presented as an observation. |

### Live warning push

| File | Step | What it shows |
|---|---|---|
| `c1_step05_ws_before.png` | 5a | Before the push: no banner, `pinned: []`, `warning_count: 0`. |
| `c1_step05_ws_rerank.png` | 5b | After `POST /admin/warnings` (orange thunderstorm, Delhi): the banner arrives from the socket frame before `/home` returns, and the feed re-ranks. |

### Learning and the why-sheet

| File | Step | What it shows |
|---|---|---|
| `c1_step06_why_sheet_pollen.png` | 6a | Long-press Pollen → "Why this?": the card's reasons, its score, and the learned taps/dismissals for that card type. |
| `c1_step06_why_sheet_humidity.png` | 6b | The same sheet for Humidity, a second card type. |
| `c1_step06_humidity_demoted_to_more.png` | 6c | The "More for you" section expanded, with the dismissed Humidity card now sitting in it. The report's measured score series for this mechanism was taken on Pollen (live Delhi data): rank 3 / 0.470 → rank 8 / 0.2677, into `more_cards` after three dismissals. |
| `c1_step06_pin_to_top.png` | 6f | Pin: the card moves into the pinned block on the next `/home`; unpin restores it. |
| `c1_step06_hide_and_restore.png` | 6g | Hide: the card leaves the feed and its type appears in `hidden_types`; restore brings it back. |

### Offline

| File | Step | What it shows |
|---|---|---|
| `c1_step07_offline_cached.png` | 7a | Backend stopped, cache warm: full feed from the on-device cache, chip "Updated just now · cached", WebSocket dot gone, one "Could not refresh. Showing saved data. · Retry" strip. |
| `c1_step07_offline_sample_data.png` | 7b | Backend stopped and cache cleared: the bundled fixture fallback. Chip reads "Updated 34 h ago · Sample data" and the strip names the unreachable host. Nothing pretends to be live. |

### Hindi

| File | Step | What it shows |
|---|---|---|
| `c1_step08_hindi_home.png` | 8a | `lang=hi` home: the app chrome is fully Hindi ("डेमो नियंत्रण", "सेटिंग्स", "रडार / स्थान / डेमो", "लाइव अपडेट जुड़े हैं", card menu items). |
| `c1_step08_hindi_cards.png` | 8b, 8d | `lang=hi` cards: titles, subtitles, headlines, advice bullets and reason chips in Hindi (91 of 96 card strings contain Devanagari, zero raw keys); the alert-card band reads "अत्यधिक सावधानी" after the mixed-language fix. |

### Traveller and saved places

| File | Step | What it shows |
|---|---|---|
| `c1_step09_places_page.png` | 9a | Saved places page with Mumbai and London added through the app's own search (kind `travel`); maximum 8 places. |
| `c1_step09_traveler_home.png` | 9b | Traveller home: the saved-places card shows both places with their local times (Mumbai IST, London BST), temperatures and rain chance; "1 travel alert — Mumbai". |
| `c1_step09_packing_suggestions.png` | 9c | "What to pack · 5 items", grouped per place, each item with its reason — e.g. London → Raincoat / umbrella ("Rain chance up to 53% in 3 days"). |

### Scenario overlays

| File | Step | What it shows |
|---|---|---|
| `c1_step11_scenario_heatwave.png` | Scenarios | `heatwave` via the demo-sheet chip: red banner, pinned "Weather warnings (Red · Heatwave)" with `scenario` as the source, pinned "Heat alert 49° · Danger" with "Warning in force", re-rank SnackBar. |
| `c1_step11_scenario_dense_fog.png` | Scenarios | `dense_fog`: orange banner, pinned commute card at "Severe impact", visibility 0.3 km, timeline in chronological order with a "Tomorrow" prefix. |

### Extras

| File | Step | What it shows |
|---|---|---|
| `c1_extra_demo_sheet.png` | 2e, Remaining screens | Demo controls sheet: 10 scenario chips (one per shipped scenario file), 4 clock presets plus a picker (both stamped with today's date), view-as-persona, simulate offline, low-bandwidth mode, live-alert dot, admin-console link, reset. |
| `c1_extra_low_bandwidth.png` | L5 | `lite=1`: the quick-actions row shows a "Lite" badge in place of Demo; radar tiles on the card are suppressed. |
| `c1_extra_low_bandwidth_map.png` | L6 | Map page under `lite=1`: "Low-bandwidth mode: radar tiles are off." The base map still draws, so warning circles stay readable. |
| `c1_extra_settings.png` | Remaining screens | Settings: 5 languages, metric/imperial, 8 personas, home location, school and commute windows, backend URL, low bandwidth, larger text, reset learning, about. |

## Earlier milestone shots (`b1_`, `b2a_`, `b2b_`, `b3_`)

Taken during the app's build-out, before the QA walk. The UI they show is older (no quick-action
row and no WebSocket dot in `b1_`/`b2a_`), and where a `c1_*` shot covers the same screen the
`c1_*` one is current.

| File | What it shows |
|---|---|
| `b1_home.png` | The first working home screen: New Delhi, Parent + Commuter, "Right now" hero, School run and Heat alert, rendered from the live backend. |
| `b1_home_offline.png` | The same build with the backend unreachable: "Sample data" chip, "Could not refresh" strip naming the host, and the bundled fixture's orange thunderstorm scenario with pinned commute and school-run cards. |
| `b2a_beach.png` | Panaji, Beach & sea persona: hero, "Next 3 hours" nowcast (rain likely by 18:00) and Rain alert. |
| `b2a_beach_scrolled.png` | Same screen scrolled: nowcast, Rain alert (peak chance, expected mm) and the Sea conditions card (Slight · 1.2 m, period, sea temperature, swell, current). |
| `b2a_fitness.png` | New Delhi, Fitness persona: hero and the Heat alert card (Extreme Caution, peak around 13:00, advice bullets). |
| `b2a_fitness_scrolled.png` | Same screen scrolled: Heat alert, "Best time to work out" windows scored /100, and Air quality. |
| `b2a_health.png` | New Delhi, Health persona: hero and the Health advisory card (4 advisories: air quality, humidity, heat, +1). |
| `b2a_health_scrolled.png` | Same screen scrolled: Health advisory and the Air quality card with the CPCB 0–500 gauge (209, Poor), dominant pollutant and PM2.5 / PM10 / O₃. |
| `b2b_agriculture.png` | Farming persona home with the quick-action row (Radar / Places / Demo) and the Soil moisture gauge (40%, Wet — "skip irrigation"). |
| `b2b_beach.png` | Panaji, Beach & sea persona: Sea conditions with "Safe for swimming", surf rating and the 24-h wave-height sparkline. |
| `b2b_commuter.png` | Commuter persona: "Your commute" card with the "Estimated" chip, morning and evening windows, delay, rain and visibility. |
| `b2b_demo_sheet.png` | Demo controls sheet at that milestone. Note: it still shows a "Cold Wave" scenario chip that was removed during the QA walk; `c1_extra_demo_sheet.png` is the current sheet. |
| `b2b_event_planner.png` | Event planner persona: the 14-day outlook with rain chance and temperature range bars. |
| `b2b_fitness.png` | Fitness persona home with the Air quality gauge (130, Moderate). |
| `b2b_health.png` | Health persona home with the Health advisory card. |
| `b2b_hindi.png` | An early Hindi home (Parent persona): chrome and card titles in Hindi while one detail line is still English. Superseded by `b3_hindi_localized.png` and the `c1_step08_*` shots. |
| `b2b_map.png` | The "Radar & warnings" page: OpenStreetMap base map centred on New Delhi, RainViewer frame "8 Sep, 16:50 · observed" (13/13), play/scrub bar and attribution. The QA report cites this shot for the map page. |
| `b2b_parent.png` | Parent persona: School run card with the morning-drop / afternoon-pickup timeline and per-window verdicts. |
| `b2b_places.png` | Saved places page, empty state: kind chips (Home / Work / School / Travel / Other) and city search, before any place is added. |
| `b2b_traveler.png` | Traveller persona home with the 7-day forecast. |
| `b2b_ws_before.png` | Parent home before a warning is pushed: no banner, WebSocket dot green. |
| `b2b_ws_rerank.png` | After the push: orange "Thunderstorm warning — Delhi" banner, "Your commute" pinned at Severe with "Pinned because it is urgent", and the SnackBar "A warning moved to the top of your feed. · View". |
| `b3_hindi_localized.png` | Hindi home under a pushed warning: banner "नारंगी चेतावनी: गरज के साथ बारिश और बिजली", pinned commute card fully localised including the "पिन किया गया" and "अनुमानित" (Estimated) chips. |

## Naming convention

`<milestone>_<step>_<subject>.png`, lower-case ASCII with underscores.

- `<milestone>` — the build milestone the shot was taken in: `b1`, `b2a`, `b2b`, `b3` (build-out)
  or `c1` (the QA walk). For a new shot use the next milestone label or an ISO date
  (`2026-09-10_…`).
- `<step>` — the demo-script step the shot evidences (`step01` … `step11`), or `extra` for a
  screen outside the script. The earlier `b*` shots omit this part and use the persona or page as
  the subject (`b2b_parent`, `b2b_map`).
- `<subject>` — what is on screen: persona, page, or the state being shown
  (`ws_before` / `ws_rerank`, `offline_cached`, `tides_estimated`).
- `_scrolled` — the same screen scrolled further down, paired with the unscrolled file.

For new shots: same viewport (390×844 @2 → 780×1688 PNG), same web build against a local backend;
when a screen is re-shot after a fix, replace the file in place rather than adding a numbered
duplicate, and update the row here and in `docs/QA_REPORT.md`. Check a new shot for a backend URL,
token or personal data before adding it — the existing ones show guest sessions and public
weather data only.

## Using them in documents

Paths are relative to the document that embeds them. From the repository root (`README.md`):

```markdown
![Parent home](assets/screenshots/c1_step03_persona_parent.png)
```

From a file in `docs/`:

```markdown
![Parent home](../assets/screenshots/c1_step03_persona_parent.png)
```

A three-column grid, as used in the root README:

```markdown
| Parent | Commuter | Health |
|---|---|---|
| ![Parent](assets/screenshots/c1_step03_persona_parent.png) | ![Commuter](assets/screenshots/c1_step03_persona_commuter.png) | ![Health](assets/screenshots/c1_step03_persona_health.png) |
```

The images are 780 px wide; GitHub scales table cells, so three portrait shots per row is the
practical limit before the text becomes unreadable.
