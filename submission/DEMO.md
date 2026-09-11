# Demo Video

A demo video is optional for the SIH submission but strongly recommended. Ours is a demo of the
prototype: one laptop, one phone (or a Chrome tab), and a backend running locally.

## Demo video link

<https://www.youtube.com/watch?v=dAnlxq_2jj8>

The link is public — it needs no sign-in and no access request.

## The demo script it follows

The recording walks the five-minute demo script the project is built around, reproduced below. The
script itself is [`../docs/00_VISION.md`](../docs/00_VISION.md) §Judge demo script, and
[`../docs/QA_REPORT.md`](../docs/QA_REPORT.md) walks the same ten steps with a screenshot of each.
There is no hardware component.

1. **Onboard** — choose the language, pick **Parent + Commuter**, set the location to **Delhi**
   (GPS or search).
2. **Morning home** — set the demo clock to **07:30**: *School commute* and *Commute conditions*
   rank first, each with its reasons; the hero shows current conditions, with the nowcast and any
   rain alert below.
3. **Persona switch** — tap the **Fitness** chip: best workout window, sun times, wind and heat
   alert move up; then **Health**: AQI, pollen, UV, humidity.
4. **Coastal switch** — change the location to **Goa**: Sea conditions, Tides (marked
   **Estimated**) and Water temperature appear; they are gated on the location being coastal.
5. **Live warning** — from the admin console on the laptop, push
   **Orange · Thunderstorm with gusty winds** for Delhi: the phone shows the banner and the
   warning card animates to the top of the feed.
6. **Explainability and learning** — long-press **Pollen** → *Why am I seeing this?* →
   *Show less* two or three times → the card drops into "More for you"; **Pin** lifts a card to
   the top on the next refresh.
7. **Offline** — switch on airplane mode: the home still renders from cache with the freshness
   chip ("Updated N min ago").
8. **Hindi** — switch the language to हिन्दी: the app chrome *and* the card insights are localized.
9. **Traveller** — saved places **Mumbai + London** → packing suggestions
   ("Carry a raincoat in London").
10. **Close on the architecture** — FastAPI engine, the provider fallback chain
    (IMD → Open-Meteo → estimated), server-driven cards.

## Evidence without the video

- [`../docs/QA_REPORT.md`](../docs/QA_REPORT.md) — an end-to-end walk of all ten steps above,
  driven through the real Flutter web build against a live local backend on live weather data.
  **Verdict: PASS**, ten steps of ten, with 40 screenshots (`assets/screenshots/01`–`40`), one
  per step and variant.
- [`../assets/screenshots/README.md`](../assets/screenshots/README.md) — the index of every
  screenshot in [`../assets/screenshots/`](../assets/screenshots/) (63 files), including the
  eight per-persona home screens, the before/after of the live warning push, Hindi, offline and
  low-bandwidth mode.

## Recording notes

- **Backend running locally** — `uvicorn app.main:app --port 8000` from `backend/` with the
  default `DEMO_MODE=1`; no API key is needed. Setup for every platform is in
  [`../docs/RUNNING.md`](../docs/RUNNING.md); the backend's own notes are in
  [`../backend/README.md`](../backend/README.md).
- **Admin console open on the laptop** at `http://localhost:8000/admin/console` (default admin
  key `mausam-admin`). Step 5 uses the *Orange thunderstorm — Delhi* preset and **Push warning**;
  the row's *Delete* button (or the warning's TTL) reverts it.
- **App in Chrome or on an Android phone.** For the web build point *Settings → Backend URL* at
  `http://localhost:8000`; for a phone on the same Wi-Fi use `http://<laptop-LAN-IP>:8000`, never
  `localhost`.
- **Keep the demo clock on today's date.** The backend moves the *reading* to a demo hour only
  when it has a forecast row for that hour (the 48-hour window). With a stale date the ranking
  still changes but the hero keeps the live observation, so the clock looks as if it does nothing.
  The app's demo sheet builds its 07:30 / 22:00 presets on today for exactly this reason.
- If the backend is a Render free-tier deployment instead of a local one, hit `/health` a minute
  before recording — the instance sleeps after about 15 minutes idle and takes about 30 s to wake.
