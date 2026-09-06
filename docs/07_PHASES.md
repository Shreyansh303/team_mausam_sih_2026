# 07 · Phases (work packages for implementation agents)

Order: **A1 ∥ B0 → A2 ∥ B1 → A3 ∥ B2 → B3 → C1 → C2 → stretch**. A* = backend (`backend/`),
B* = Flutter (`app/`, `scripts/`), C* = integration (both). Each phase = one agent run. Every
phase: read `CLAUDE.md`, this file's section, and the docs it names; tick `docs/PROGRESS.md`;
commit your paths; final report per CLAUDE.md §10.

---
## A1 · Backend foundation + data layer  (owner: `backend/`)
Read: 01, 04 (Snapshot, LocationResult, Warning), 05 (all), 02 (data shapes for derived).
Deliver:
1. Project skeleton per 05 layout; `python -m venv .venv` at `backend/.venv` using `C:\Python313\python.exe`; deps installed; `.env.example`; `Dockerfile`.
2. `config.py`, `core/*` (cache, timeutil, geo, errors, i18n loader with `en.json` seed).
3. Providers: open_meteo (forecast/air/marine/geocode), bigdatacloud, rainviewer, imd (whitelist-aware), scenarios loader. Optional cpcb/tomtom stubs behind keys.
4. Data files: `cities.json` (≥150 Indian cities with district/state/coastal/elevation/tz; include all state capitals, major coastal towns Goa/Panaji, Puri, Kovalam, Gokarna, Diu, Digha, Port Blair; hill stations Shimla, Manali, Ooty, Darjeeling, Leh), `coastal_points.json` (≥80), `planting_calendar.json` (7 zones × 12 months × 2–4 crops), `imd_ids.json` (best-effort), `scenarios/*.json` (all 10 from 05).
5. Services: snapshot assembly + every derived module with formulas from 02/05.
6. Routers: `/health`, `/locations/*`, `/weather/snapshot`, `/weather/radar`.
7. `scripts/record_fixtures.py` (hits real APIs for Delhi, Goa(Panaji), Shimla, Mumbai, London; writes `tests/fixtures/`) — run it once, commit JSON.
8. Tests offline via respx: providers, aqi, derived, snapshot for Delhi (inland) and Panaji (coastal), scenario overlay.
Verify: `.venv/Scripts/python -m pytest -q` green; `uvicorn` starts; `GET /weather/snapshot?lat=15.49&lon=73.83` returns marine+tides; `?lat=28.61&lon=77.21` has `marine: null`; `?scenario=dense_fog` shows visibility 0.2.
Commit: `phase(A1): backend data layer`.

## A2 · Engine, cards, /home, auth/profile, events, i18n  (owner: `backend/`)
Read: 02, 03, 04, 05. Requires A1.
Deliver: DB models + SQLite init; JWT guest/OTP; `/me*`, `/me/places`; engine (catalog with the
affinity matrix and multipliers/gates/urgency per 02, context, scoring, explain, learning); 33
builders; `/home` (all params incl. `personas`, `now_override`, `scenario`, `event_date`, `lite`,
saved-place snapshots concurrent); `/events` with prefs side-effects; i18n `en`+`hi` complete (`mr`,
`ta`, `bn` partial ok); `scripts/gen_fixtures.py` → `docs/fixtures/home_<persona>.json` for the 8
personas + `home_severe.json` (thunderstorm scenario, parent) + `home_coastal.json` (beach, Panaji).
Tests: 03 §tests (all 9) + API flow tests from 05.
Verify: pytest green; manual `GET /home?lat=28.61&lon=77.21&personas=parent,commuter&now_override=2026-09-08T07:30:00+05:30` shows school_commute in top 3; `lang=hi` returns Hindi titles.
Commit: `phase(A2): engine + home`.

## A3 · Live alerts, admin console, deploy, CI  (owner: `backend/`, `infra/`, `.github/workflows/backend.yml`)
Read: 04 (admin, WS), 05 (admin console, WS manager). Requires A2.
Deliver: `/admin/*` + console HTML; WS manager + `/ws/alerts`; global scenario/now-override state;
admin warnings persisted with expiry and merged into `/home`; `infra/docker-compose.yml`,
`infra/render.yaml`; GitHub Actions backend test workflow; backend README section (run, env,
IMD whitelisting steps, deploy to Render); perf logging; regenerate fixtures.
Tests: admin warning → `/home` pinned + banner; WS client receives `warning_issued` with
`affects_you`; expired warnings vanish; `lite` trimming.
Verify: pytest green; console loads at `/admin/console`; push preset "Orange thunderstorm — Delhi"
and see `/home` for Delhi pinned. Commit: `phase(A3): live alerts + admin + deploy`.

## B0 · Flutter toolchain + scaffold  (owner: `app/`, `scripts/`, root `.gitignore`)
Read: 06 §Toolchain, CLAUDE.md §8. No dependency on A*.
Deliver: `scripts/setup_flutter_windows.ps1` (idempotent, user-space, D:\sdk), `scripts/flutter_env.ps1`
and `.sh`; run it; `flutter create app --project-name mausam_app --org com.teammausam --platforms android,ios,web`;
set Android config per 06; `.gitignore` for Flutter/Android/Python/sdk; `docs/SETUP_WINDOWS.md`
with exact manual steps + troubleshooting (Developer Mode not required for Android/web; long paths).
Verify: `flutter doctor -v` (Flutter, Android toolchain, Chrome OK; Android Studio/VS may be missing —
fine), `flutter build web`, `flutter build apk --debug` (APK path in report). Commit: `phase(B0): flutter toolchain + scaffold`.

## B1 · App foundation, onboarding, home skeleton  (owner: `app/`)
Read: 04, 06. Requires B0. Backend may not be ready → build against `docs/fixtures/*.json` if present,
else author `app/assets/fixtures/home_sample.json` strictly from 04/02 (parent+commuter, Delhi, one orange warning).
Deliver: packages, theme, router, Riverpod, models, api client, cache, repositories (with fixture
fallback), onboarding (3 pages), home page with card shell, persona chips, banner, freshness chip,
offline banner, hero + warnings + hourly + daily + metric + generic renderers, why sheet (UI), settings
(backend URL, language), l10n scaffolding (en, hi), Android config.
Verify: `flutter analyze` no errors, `flutter test` green (models + renderers on fixture), `flutter build web`;
serve `build/web` (`python -m http.server 8080`) and screenshot the home via the browser tool to
`docs/screenshots/b1_home.png`. Commit: `phase(B1): app foundation`.

## B2 · Full card system, map, places, live alerts, events, polish  (owner: `app/`)
Read: 02, 04, 06. Requires B1; use `docs/fixtures/home_*.json` (A2) if present.
Deliver: all renderers + detail pages; animations (re-rank, banner arrival); events pipeline
(impression/tap/expand/dismiss/pin/hide) + why-sheet actions; places page; map page (radar frames +
warnings); settings complete; demo sheet; WS client; low-bandwidth; accessibility; l10n en/hi
complete (+ mr/ta/bn best-effort); app icon/splash.
Verify: analyze/test/build web; renderer test covers every card type in every fixture; screenshots
per persona to `docs/screenshots/`. Commit: `phase(B2): full card system`.

## B3 · Integration with live backend + APK + CI  (owner: `app/`, `.github/workflows/flutter.yml`)
Requires A3 + B2. Run backend locally; fix any contract mismatches (update 04 if the backend is right
and the app wrong, or vice-versa — record in PROGRESS Deviations); WS reorder demo works in the web
build; `flutter build apk --release` (debug signing ok) → `app/build/app/outputs/flutter-apk/`; GitHub
Actions workflow building the APK artifact; README app section (run on device, set backend URL).
Commit: `phase(B3): integration + apk`.

## C1 · End-to-end QA against the judge demo script  (owner: both)
Run backend + web build; drive the browser through every step of 00 §Demo script for every persona,
plus Hindi, offline, admin push, dismiss learning, coastal switch, time override. Fix bugs in either
tree. Record results in `docs/QA_REPORT.md` with screenshots. Commit: `phase(C1): e2e qa`.

## C2 · Docs + pitch  (owner: `docs/`, `README.md`)
README (quickstart, architecture diagram, screenshots, demo script, IMD integration path, roadmap);
`docs/08_PITCH.md` (SIH idea-presentation content: problem, solution, uniqueness, tech, feasibility,
impact, future scope); generate `docs/TeamMausam_SIH2026_PS26076.pptx` (SIH 6-slide style) if the
pptx skill is available. Commit: `phase(C2): docs + pitch`.

## Stretch (only after C2)
S1 ML ranker v2 (03) · S2 Android home-screen widget · S3 FCM push (doc + optional code) · S4 more languages.
