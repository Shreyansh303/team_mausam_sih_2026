# Screenshots

Every image in this folder is the Flutter web build of the app driven against a locally running
backend (live Open-Meteo data for New Delhi and Panaji, `DEMO_MODE=1`), captured from headless
Chrome at a 390×844 @2 mobile viewport, so each file is a 780×1688 portrait PNG; the offline shots
were taken with the backend stopped. They are the images embedded in the root
[README](../../README.md) (§10) and cited row by row in the end-to-end QA walk in
[docs/QA_REPORT.md](../../docs/QA_REPORT.md), whose Screenshot column gives paths as
`assets/screenshots/<file>`.

63 files. `01`–`40` are the current app, captured in one end-to-end QA walk; `41`–`63` are older
shots kept from the app's build-out.

## Recommended first look

| File | What it shows |
|---|---|
| `05-home-parent.png` | The Parent home screen — one of the eight `NN-home-<persona>.png` shots that make up the "same morning, eight home screens" grid in the root README: one backend, one morning, only the personas change (seven at New Delhi, Beach & sea at Panaji). |
| `14-time-override-morning.png` | Parent + Commuter with the demo clock at 07:30: School commute and Commute conditions ranked 1 and 2, and the hero reads the dawn forecast hour, not the live afternoon observation. |
| `21-live-warning-before.png` | Delhi feed before a warning is pushed — no banner, nothing pinned. |
| `22-live-warning-rerank.png` | Seconds later: an orange "Thunderstorm warning — Delhi" banner arrived over the WebSocket and the commute card is pinned to the top, with the re-rank SnackBar. |
| `30-hindi-home.png` | The same home with `lang=hi` — app chrome, card copy and reason chips localised, no raw i18n keys. |
| `28-offline-cached.png` | Backend stopped, cache warm: the full feed renders, the freshness chip reads "Updated just now · cached", and one strip says "Could not refresh. Showing saved data." |
| `20-coastal-tides-estimated.png` | The Tides card for Panaji with its single "Estimated" chip and the backend's own disclaimer that it is a simplified harmonic model, not an official tide table. |
| `23-why-sheet-pollen.png` | Long-press → "Why this?" sheet for the Pollen card: the card's reasons, its score, and what the ranker has learned from taps and dismissals. |
| `35-scenario-heatwave.png` | The `heatwave` scenario: red banner, pinned "Weather warnings (Red · Heatwave)" with `scenario` shown as the source, pinned "Heat alert 49° · Danger". |

## The current app

### Onboarding

| File | What it shows |
|---|---|
| `01-onboarding-language.png` | First launch, language picker: English, हिन्दी, मराठी, தமிழ், বাংলা. The router redirects to onboarding until it completes. |
| `02-onboarding-personas.png` | Persona picker: all 8 personas, 1–3 selectable, the first pick becomes the primary persona (weight 1.0, others 0.7). |
| `03-onboarding-location.png` | Location step: GPS, free-text search and a popular-cities list; New Delhi resolves to 28.61/77.21, Asia/Kolkata. |
| `04-onboarding-first-home.png` | First home screen against the live backend; the green dot on the freshness chip means `/ws/alerts` is connected. |

### One morning, eight home screens

| File | What it shows |
|---|---|
| `05-home-parent.png` | Parent, New Delhi: the School run card leads ("Overall: Caution") with the afternoon-pickup and next-morning-drop windows and their verdicts. |
| `06-home-commuter.png` | Commuter, New Delhi: "Your commute" leads, carrying the "Estimated" chip (traffic is modelled), with evening and next-morning windows at "Low impact", delay, rain and visibility. |
| `07-home-health.png` | Health, New Delhi: AQI, pollen, UV and humidity at the top of the feed. |
| `08-home-fitness.png` | Fitness, New Delhi: Best workout window, Sun times, Wind and Heat alert rise into the main feed. |
| `09-home-traveler.png` | Traveller, New Delhi: the 7-day forecast leads the feed. |
| `10-home-beach.png` | Beach & sea, Panaji: the UV index card leads (6.1 · High, peak 8.1 around 13:00, safe unprotected exposure about 11 minutes). |
| `11-home-agriculture.png` | Farming, New Delhi: the Soil moisture gauge leads (40%, Wet; root zone, soil temperature, days since rain; "Soil is wet — skip irrigation"). |
| `12-home-event-planner.png` | Event planner, New Delhi: the 14-day outlook leads, with rain chance and temperature-range bars per day. |
| `13-home-view-as-fitness.png` | "View as persona" from the demo sheet: the whole feed swaps to Fitness through the request-scoped `?personas=` override, without touching the saved profile. |

### Time of day

| File | What it shows |
|---|---|
| `14-time-override-morning.png` | Parent + Commuter, demo clock 07:30: `school_commute` (0.95) and `commute_conditions` (0.532) at ranks 1 and 2, `daypart = dawn`; the hero reads 27 °C / feels like 31 °C from the forecast hour matching the override. |
| `15-time-override-morning-scrolled.png` | The same feed scrolled down: every card carries its reason chips ("Because you follow Parenting", "The school run needs care (an advisory)"); the nowcast card is present. |
| `16-time-override-night.png` | Demo clock 22:00: School commute has left the top 3 (now health advisory, hourly forecast, daily forecast) — the spec's time-of-day test holding against the running service. |

### Coastal

| File | What it shows |
|---|---|
| `17-coastal-location-search.png` | Location search finds Panaji, Goa; the switch is instant. |
| `18-coastal-home.png` | Panaji home: Sea conditions, Tides (estimated) and Water temperature appear — the same three are absent for Delhi (coastal gating). |
| `19-coastal-sea-conditions.png` | Sea conditions card: wave height, period and direction, swell, sea-surface temperature and the sea-state band. |
| `20-coastal-tides-estimated.png` | Tides card: one "Estimated" chip plus the backend disclaimer ("Estimated from a simplified harmonic model — not an official tide table…"). Nothing modelled is presented as an observation. |

### Live warning push

| File | What it shows |
|---|---|
| `21-live-warning-before.png` | Before the push: no banner, `pinned: []`, `warning_count: 0`. |
| `22-live-warning-rerank.png` | After `POST /admin/warnings` (orange thunderstorm, Delhi): the banner arrives from the socket frame before `/home` returns, and the feed re-ranks. |

### Learning, the why-sheet, pin and hide

| File | What it shows |
|---|---|
| `23-why-sheet-pollen.png` | Long-press Pollen → "Why this?": the card's reasons, its score, and the learned taps/dismissals for that card type. |
| `24-why-sheet-humidity.png` | The same sheet for Humidity, a second card type. |
| `25-humidity-demoted.png` | The "More for you" section expanded, with the dismissed Humidity card now sitting in it. The report's measured score series for this mechanism was taken on Pollen (live Delhi data): rank 3 / 0.470 → rank 8 / 0.2677, into `more_cards` after three dismissals. |
| `26-pin-to-top.png` | Pin: the card moves into the pinned block on the next `/home`; unpin restores it. |
| `27-hide-and-restore.png` | Hide: the card leaves the feed and its type appears in `hidden_types`; restore brings it back. |

### Offline

| File | What it shows |
|---|---|
| `28-offline-cached.png` | Backend stopped, cache warm: full feed from the on-device cache, chip "Updated just now · cached", WebSocket dot gone, one "Could not refresh. Showing saved data. · Retry" strip. |
| `29-offline-sample-data.png` | Backend stopped and cache cleared: the bundled fixture fallback. Chip reads "Updated 34 h ago · Sample data" and the strip names the unreachable host. Nothing pretends to be live. |

### Hindi

| File | What it shows |
|---|---|
| `30-hindi-home.png` | `lang=hi` home: the app chrome is fully Hindi ("डेमो नियंत्रण", "सेटिंग्स", "रडार / स्थान / डेमो", "लाइव अपडेट जुड़े हैं", card menu items). |
| `31-hindi-cards.png` | `lang=hi` cards: titles, subtitles, headlines, advice bullets and reason chips in Hindi (91 of 96 card strings contain Devanagari, zero raw keys); the alert-card band reads "अत्यधिक सावधानी" after the mixed-language fix. |

### Traveller and saved places

| File | What it shows |
|---|---|
| `32-saved-places.png` | Saved places page with Mumbai and London added through the app's own search (kind `travel`); maximum 8 places. |
| `33-traveler-home.png` | Traveller home: the saved-places card shows both places with their local times (Mumbai IST, London BST), temperatures and rain chance; "1 travel alert — Mumbai". |
| `34-packing-suggestions.png` | "What to pack · 5 items", grouped per place, each item with its reason — e.g. London → Raincoat / umbrella ("Rain chance up to 53% in 3 days"). |

### Scenario overlays

| File | What it shows |
|---|---|
| `35-scenario-heatwave.png` | `heatwave` via the demo-sheet chip: red banner, pinned "Weather warnings (Red · Heatwave)" with `scenario` as the source, pinned "Heat alert 49° · Danger" with "Warning in force", re-rank SnackBar. |
| `36-scenario-dense-fog.png` | `dense_fog`: orange banner, pinned commute card at "Severe impact", visibility 0.3 km, timeline in chronological order with a "Tomorrow" prefix. |

### Low bandwidth, settings and demo controls

| File | What it shows |
|---|---|
| `37-low-bandwidth-home.png` | `lite=1`: the quick-actions row shows a "Lite" badge in place of Demo; radar tiles on the card are suppressed. |
| `38-low-bandwidth-map.png` | Map page under `lite=1`: "Low-bandwidth mode: radar tiles are off." The base map still draws, so warning circles stay readable. |
| `39-settings.png` | Settings: 5 languages, metric/imperial, 8 personas, home location, school and commute windows, backend URL, low bandwidth, larger text, reset learning, about. |
| `40-demo-controls.png` | Demo controls sheet: 10 scenario chips (one per shipped scenario file), 4 clock presets plus a picker (both stamped with today's date), view-as-persona, simulate offline, low-bandwidth mode, live-alert dot, admin-console link, reset. |

## Earlier development shots

Taken during the app's build-out, before the QA walk. The UI they show is older (no quick-action
row and no WebSocket dot in `41`–`48`), and where a `01`–`40` shot covers the same screen that one
is current.

| File | What it shows |
|---|---|
| `41-early-home.png` | The first working home screen: New Delhi, Parent + Commuter, "Right now" hero, School run and Heat alert, rendered from the live backend. |
| `42-early-home-offline.png` | The same build with the backend unreachable: "Sample data" chip, "Could not refresh" strip naming the host, and the bundled fixture's orange thunderstorm scenario with pinned commute and school-run cards. |
| `43-early-beach-nowcast.png` | Panaji, Beach & sea persona: hero, "Next 3 hours" nowcast (rain likely by 18:00) and Rain alert. |
| `44-early-beach-nowcast-scrolled.png` | Same screen scrolled: nowcast, Rain alert (peak chance, expected mm) and the Sea conditions card (Slight · 1.2 m, period, sea temperature, swell, current). |
| `45-early-fitness-heat-alert.png` | New Delhi, Fitness persona: hero and the Heat alert card (Extreme Caution, peak around 13:00, advice bullets). |
| `46-early-fitness-heat-alert-scrolled.png` | Same screen scrolled: Heat alert, "Best time to work out" windows scored /100, and Air quality. |
| `47-early-health-advisory.png` | New Delhi, Health persona: hero and the Health advisory card (4 advisories: air quality, humidity, heat, +1). |
| `48-early-health-advisory-scrolled.png` | Same screen scrolled: Health advisory and the Air quality card with the CPCB 0–500 gauge (209, Poor), dominant pollutant and PM2.5 / PM10 / O₃. |
| `49-early-agriculture-soil.png` | Farming persona home with the quick-action row (Radar / Places / Demo) and the Soil moisture gauge (40%, Wet — "skip irrigation"). |
| `50-early-beach-sea-conditions.png` | Panaji, Beach & sea persona: Sea conditions with "Safe for swimming", surf rating and the 24-h wave-height sparkline. |
| `51-early-commuter.png` | Commuter persona: "Your commute" card with the "Estimated" chip, morning and evening windows, delay, rain and visibility. |
| `52-early-event-planner.png` | Event planner persona: the 14-day outlook with rain chance and temperature range bars. |
| `53-early-fitness-air-quality.png` | Fitness persona home with the Air quality gauge (130, Moderate). |
| `54-early-health-home.png` | Health persona home with the Health advisory card. |
| `55-early-parent-school-run.png` | Parent persona: School run card with the morning-drop / afternoon-pickup timeline and per-window verdicts. |
| `56-early-traveler-forecast.png` | Traveller persona home with the 7-day forecast. |
| `57-early-places-empty.png` | Saved places page, empty state: kind chips (Home / Work / School / Travel / Other) and city search, before any place is added. |
| `58-early-map-radar.png` | The "Radar & warnings" page: OpenStreetMap base map centred on New Delhi, RainViewer frame "8 Sep, 16:50 · observed" (13/13), play/scrub bar and attribution. The QA report cites this shot for the map page. |
| `59-early-demo-controls.png` | An older demo controls sheet. Note: it still shows a "Cold Wave" scenario chip that was removed during the QA walk; `40-demo-controls.png` is the current sheet. |
| `60-early-warning-before.png` | Parent home before a warning is pushed: no banner, WebSocket dot green. |
| `61-early-warning-rerank.png` | After the push: orange "Thunderstorm warning — Delhi" banner, "Your commute" pinned at Severe with "Pinned because it is urgent", and the SnackBar "A warning moved to the top of your feed. · View". |
| `62-early-hindi-home.png` | An early Hindi home (Parent persona): chrome and card titles in Hindi while one detail line is still English. Superseded by `63-early-hindi-warning.png` and `30`/`31`. |
| `63-early-hindi-warning.png` | Hindi home under a pushed warning: banner "नारंगी चेतावनी: गरज के साथ बारिश और बिजली", pinned commute card fully localised including the "पिन किया गया" and "अनुमानित" (Estimated) chips. |

## Naming convention

`NN-subject.png` — a two-digit ordinal and a descriptive slug, lower-case ASCII with hyphens.

- `NN` — the ordinal that orders this index. Files are grouped by what they show: onboarding,
  the eight persona home screens, time of day, coastal, the live warning push, learning and the
  why-sheet, offline, Hindi, saved places, scenario overlays, and the remaining screens. Earlier
  development shots keep the tail of the range and carry an `early-` prefix.
- `subject` — what is on screen: the persona, the page, or the state being shown
  (`live-warning-before` / `live-warning-rerank`, `offline-cached`, `coastal-tides-estimated`).
- `-scrolled` — the same screen scrolled further down, paired with the unscrolled file.

For a new shot, take the next free ordinal in its group (renumber the group if it has run out) and
use the same viewport (390×844 @2 → 780×1688 PNG) and the same web build against a local backend.
When a screen is re-shot after a fix, replace the file in place rather than adding a numbered
duplicate, and update the row here and in `docs/QA_REPORT.md`. Check a new shot for a backend URL,
token or personal data before adding it — the existing ones show guest sessions and public
weather data only.

## Using them in documents

Paths are relative to the document that embeds them. From the repository root (`README.md`):

```markdown
![Parent home](assets/screenshots/05-home-parent.png)
```

From a file in `docs/`:

```markdown
![Parent home](../assets/screenshots/05-home-parent.png)
```

A three-column grid, as used in the root README:

```markdown
| Parent | Commuter | Health |
|---|---|---|
| ![Parent](assets/screenshots/05-home-parent.png) | ![Commuter](assets/screenshots/06-home-commuter.png) | ![Health](assets/screenshots/07-home-health.png) |
```

The images are 780 px wide; GitHub scales table cells, so three portrait shots per row is the
practical limit before the text becomes unreadable.
