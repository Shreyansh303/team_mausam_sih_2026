# Demo Video

A demo video is optional for the SIH submission but strongly recommended. Ours is a demo of the
prototype: one laptop, one phone (or a Chrome tab), and a backend running locally.

## Demo video link

<https://www.youtube.com/watch?v=dAnlxq_2jj8>

The link is public — it needs no sign-in and no access request.

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
