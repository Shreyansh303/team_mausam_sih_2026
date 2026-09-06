# 00 · Vision, personas, and what wins

## Problem statement (verbatim, SIH 2026 · ID 26076 · MoES / India Meteorological Department)
**Development of personalized homepage for 'Mausam' mobile application**
- Health-conscious users: Highlight Air Quality Index (AQI), pollen count, UV index, and humidity levels to help users manage allergies, asthma, or skin sensitivity.
- Outdoor fitness enthusiasts: Show sunrise/sunset times, 'best running hours,' wind speed, and heat alerts to optimize workout planning.
- Beachgoers & surfers: Display sea conditions, tide timings, wave height, and water temperature for safe and enjoyable beach activities.
- Travelers: Provide quick access to saved destinations, severe weather alerts for flights, and packing suggestions (e.g., 'Carry a raincoat in London').
- Parents & families: Emphasize school commute conditions, rain alerts, and severe weather warnings to plan daily routines.
- Agriculture & gardeners: Show soil moisture, rainfall predictions, frost alerts, and seasonal planting guidance.
- Commuters: Integrate weather with traffic updates, visibility conditions, and alerts for storms or fog that affect travel.
- Event planners: Offer extended forecasts, probability of rain, and 'comfort index' for outdoor gatherings or weddings.

Category: Software · Theme: Smart Automation · Team: **Team Mausam**

## The eight personas (ids used everywhere in code)
| id | Persona | Must-have signals (from PS) |
|---|---|---|
| `health` | Health-conscious | AQI, pollen, UV, humidity |
| `fitness` | Outdoor fitness | sunrise/sunset, best running hours, wind, heat alerts |
| `beach` | Beachgoers & surfers | sea conditions, tides, wave height, water temperature |
| `traveler` | Travelers | saved destinations, flight-affecting severe weather, packing suggestions |
| `parent` | Parents & families | school commute, rain alerts, severe warnings |
| `agriculture` | Agriculture & gardeners | soil moisture, rainfall prediction, frost alerts, planting guidance |
| `commuter` | Commuters | weather + traffic, visibility, storm/fog alerts |
| `event_planner` | Event planners | extended forecast, rain probability, comfort index |

Users may select **1–3 personas** (first selected = primary). Everyone also gets the implicit
`base` persona (current conditions, hourly/daily forecast, IMD warnings, nowcast, radar).

## Product principles
1. **Every card answers "so what?"** — a metric plus a one-line insight and an action
   ("Best run: 6:00–7:30, AQI 48" not just "AQI 48").
2. **Urgency beats preference.** A red/orange IMD warning for the user's district pins to the top
   for every persona, with an animated re-rank when it arrives live.
3. **Explainable.** Long-press any card → "Why am I seeing this?" (persona, condition, time,
   location, learning). Users can pin, dismiss, or hide; the engine adapts visibly.
4. **Context-aware, not just role-aware.** Time of day, weekday/weekend, IMD season, coastal vs
   inland, elevation, active warnings all change the ranking.
5. **Works on a ₹6,000 phone in a village.** Offline cache, small payloads, low-bandwidth mode,
   regional languages, large-text and screen-reader friendly.
6. **Honest data.** Real observations/forecasts where available (IMD APIs when whitelisted,
   Open-Meteo otherwise); modelled values (tides, pollen, traffic) are labelled "Estimated".
7. **Server-driven.** The backend decides card order, content and copy; IMD could add a card
   without an app release.

## What will impress judges (and how we show it)
- Complete coverage: **all 8 personas × every bullet** in the PS maps to a card (see 02).
- A real ranking engine with formulas, tests, and an explanation surface (see 03).
- Live re-ranking demo: admin console pushes an orange thunderstorm warning → phone reorders.
- Learning demo: dismiss a card twice → it demotes; pin → it rises.
- Location intelligence: switch Delhi → Goa and marine/tide cards appear automatically.
- Offline demo: airplane mode → cached home with "Updated 12 min ago".
- Hindi (and other) UI + localized insights.
- IMD integration path: real IMD endpoint clients with whitelisting documented; CPCB AQI scale.

## Judge demo script (≈5 minutes)
1. Onboard: language → pick **Parent + Commuter** → location Delhi (GPS or search).
2. Home at "7:30 AM" (time override in demo menu): School commute + Commute conditions on top
   with reasons; hero shows now; nowcast; rain alert if any.
3. Tap the persona chip **Fitness** → Best workout window, Sun times, Wind, Heat alert move up.
4. Change location to **Goa** → Sea conditions, Tides (estimated), Water temp appear.
5. Open the **admin console** on a laptop → push "Orange · Thunderstorm with gusty winds" for
   Delhi → the phone shows the banner and the warning card animates to the top.
6. Long-press **Pollen** → "Why this?" → tap "Show less" twice → it drops to "More for you".
7. Toggle airplane mode → home still renders from cache with the freshness chip.
8. Switch to **हिन्दी** → chrome + insights localized.
9. **Traveler**: saved places Mumbai + London → packing suggestions ("Carry a raincoat in London").
10. Close with architecture slide: FastAPI engine, provider fallback chain, server-driven cards.
