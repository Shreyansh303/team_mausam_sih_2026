# PROGRESS (living checklist — agents tick items; orchestrator resumes from here)

Legend: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (say why in Notes)

## Resume instructions (for a fresh orchestrator session)
1. Read `CLAUDE.md`, this file, `docs/07_PHASES.md`.
2. `git status` / `git log --oneline` to see the last checkpoint.
3. Spawn the next phase whose box is not `[x]`, following the order in 07. A1 ∥ B0 may run in parallel; so may A2 ∥ B1 and A3 ∥ B2.
4. Implementation agents run on the Opus model. The orchestrator only plans, reviews reports, and commits.

## Recovery after an interrupted agent (usage limit, crash)
An interrupted agent loses its conversation, not its files. To resume a phase that is `[~]` or has
unticked items but files present:
1. `git status` — uncommitted files are partial work from the interrupted run; keep them, do not
   assume they are complete.
2. Trust the tree and the tests over this checklist: run the phase's verification commands
   (pytest / flutter analyze+test+build) and read the existing files before writing anything.
3. Finish only what is missing; tick items here as you verify them; commit + push per milestone.
4. Spawn prompt for the resuming agent: "Resume phase <id>: read CLAUDE.md, docs/07_PHASES.md §<id>,
   docs/PROGRESS.md; inspect the tree; run the verification; complete the remaining items."

## Phase status
- [x] A1 backend data layer
- [x] A2 engine + home + auth + events + i18n
- [x] A3 live alerts + admin + deploy + CI
- [x] B0 flutter toolchain + scaffold
- [x] B1 app foundation + onboarding + home skeleton
- [x] B2a ten pending renderers + detail pages (one commit each)
- [x] B2b animations · events · why-sheet actions · places · map · settings · demo sheet · WS client · low-bandwidth · a11y · l10n · icon/splash
- [x] B3 integration + APK + CI (+ the backend i18n gaps B2b logged)
- [x] C1 e2e QA
- [x] C2 docs + pitch
- [ ] S* stretch
- [x] H0 fresh-machine bootstrap (new owner; see docs/HANDOFF.md §4) — done on the macOS machine
  2026-09-08 (see "Notes for next phase → H0 — this Mac"); was never needed on the original Windows machine.
  Toolchain + every gate green (pytest 300, analyze clean, 64 tests, web, and a real
  `app-debug.apk`). **One carry-over for whoever owns `app/` next:** the APK build needs
  `compileSdk = 37` in `app/android/app/build.gradle.kts` (plugin `permission_handler_android`
  14.1.0 demands API 37). H0 verified that one-line fix, then reverted it — it belongs to B2b/B3,
  not to a machine bootstrap. Details in the H0 notes, gotcha 3.

## A1 checklist
- [x] skeleton + venv + deps + .env.example + Dockerfile
- [x] config/core (cache, timeutil, geo, i18n loader)
- [x] providers: open_meteo forecast/air/marine/geocode · bigdatacloud · rainviewer · imd · scenarios (+ optional cpcb/tomtom behind keys)
- [x] data files: cities.json 212 · coastal_points.json 102 · planting_calendar.json (7×12×2–4) · imd_ids.json (35 stations) · scenarios (10) · i18n/en.json (236 keys)
- [x] services: snapshot + aqi_cpcb + comfort/heat/dew + workout + school_commute + commute/traffic + frost + packing + planting + tides + pollen + marine + visibility + flight_risk + nowcast + warnings
- [x] routers: health, locations, weather/snapshot, weather/radar (+ /weather/scenarios)
- [x] recorded fixtures + offline tests green (210 passed)

## A2 checklist
- [x] DB models + sqlite init · JWT guest/OTP (demo OTP `123456`, guest merge via `X-Guest-Token`)
  · `/me`, `/me/profile`, `/me/card-prefs`, `/me/reset-learning`, `/me/places` (max 8)
- [x] engine: catalog (full 02 matrix, gates, time/season multipliers, urgency) · context ·
  scoring (03 formulas verbatim) · explain (7 reason families, localized) · learning
- [x] 33 builders · `/home` (lat/lon, place_id, lang, personas, now_override, scenario,
  event_date, lite; saved-place snapshots concurrent, capped at 5) · `/events` (batch ≤ 100,
  pin/unpin/hide/unhide also write card-prefs)
- [x] i18n en + hi complete (471 keys each) · mr/ta/bn partial (54 keys, per-key fallback)
- [x] docs/fixtures/home_<persona>.json ×8 + home_severe.json + home_coastal.json
- [x] tests: 03 §tests ×9 + API flows + i18n parity — **283 passed** (210 A1 + 73 A2)

## A3 checklist
- [x] `models/admin_warning.py` + `services/admin_warnings.py` (TTL expiry, no delete needed) ·
  `/admin/{state,scenario,now-override,warnings,warnings/{id},reset-user,console}` behind
  `X-Admin-Key` · admin warnings merged into `/home` via `get_snapshot(admin_warnings=…)` ·
  global scenario + now-override honoured when the request does not override them
- [x] `api/ws.py`: in-memory manager + `/ws/alerts?token=&lat=&lon=` with all six 04 message
  types, 30 s ping, client `location` updates, dead connections dropped; broadcasts fired from
  the admin router only
- [x] `app/static/admin/index.html` at `/admin/console` — base+key in localStorage, scenario
  buttons with active highlight, demo clock, push form (`/locations/popular` or lat/lon) with the
  five 05 presets, active-warnings table with delete, client count auto-refreshing every 5 s,
  reset-user, live WS feed
- [x] infra/docker-compose.yml · infra/render.yaml · backend/Dockerfile reviewed (PORT, healthcheck)
  · .github/workflows/backend.yml (Python 3.13, pip cache, offline pytest)
- [x] backend README section (run, env table, console + demo flow, WS, IMD whitelisting, deploy,
  pointing the app at the URL)
- [x] perf: `/home` timing line at INFO (`home lat=… lon=… personas=… … 12ms`); `lite` verified
- [x] tests: admin→home pinned + banner + warning_count · expiry · ws hello/`warning_issued`
  affects_you near+far · scenario/now-override broadcasts · lite trimming · wrong admin key —
  **300 passed** (283 + 17)

## B0 checklist
- [x] scripts/setup_flutter_windows.ps1 + flutter_env.ps1/.sh
- [x] Flutter 3.47.2 + Temurin JDK 17 + Android SDK 36 installed under D:\sdk; `flutter doctor -v`
  shows Flutter / Android toolchain / Chrome OK (only PATH warnings + incomplete VS Build Tools,
  both irrelevant here)
- [x] `flutter create` scaffold with Android config · .gitignore · docs/SETUP_WINDOWS.md
- [x] `flutter build web` and `flutter build apk --debug` succeed →
  `app/build/app/outputs/flutter-apk/app-debug.apk` (150 MB debug, all ABIs, 339 s first run)

## B1 checklist
- [x] packages (18 runtime deps, versions in "Notes for next phase → B2") · `core/theme.dart`
  (M3 light+dark, IMD severity colours) · `core/router.dart` (go_router, hard onboarding redirect)
  · Riverpod 3 · models (`HomeResponse/HomeCard/Warning/User/Location`, coercing `json.dart`)
  · `data/api_client.dart` (dio, `/api/v1`, bearer) · `data/cache/json_file_cache.dart`
  · repos: auth · home (network → cache → **bundled fixture**) · locations · events · settings
- [x] onboarding (language, personas 1–3, location: GPS + search + popular) · settings page
  (backend URL, language, low bandwidth, cache clear)
- [x] home: shell + `CustomScrollView`, persona chips, warning banner, freshness chip, offline /
  sample-data banners, hero + warnings + hourly + daily + metric + generic renderers, why sheet UI
- [x] l10n en/hi scaffolding (`flutter gen-l10n` from `l10n.yaml`, no build_runner) ·
  `flutter analyze` clean · `flutter test` **44 passed** · `flutter build web` ·
  screenshots `docs/screenshots/b1_home.png` (live backend) + `b1_home_offline.png` (fixture)

## B2 checklist
### B2a (renderers)
- [x] nowcast · [x] radar · [x] gauge · [x] advice_list · [x] timeline · [x] alert · [x] sea · [x] tides · [x] places · [x] bar_chart
- [x] detail page per renderer (`lib/features/home/detail/card_detail_page.dart` + one
  `<renderer>_detail.dart` for gauge/timeline/alert/advice_list/bar_chart/sea/tides/places/radar;
  the card shell now pushes a full-screen page instead of the B1 bottom sheet) ·
  [x] fixtures_test green (64 tests) · [x] screenshots `docs/screenshots/b2a_{health,fitness,beach}.png`
  + `_scrolled` variants, all against the live backend
### B2b
- [x] all renderers + detail pages (B2a)
- [x] `compileSdk = 37` (H0's carry-over, first commit of the phase)
- [x] WS client `data/ws/alerts_socket.dart` (pong on every ping, `location` frame on a move,
  1008 = re-auth and no retry, exponential backoff, unknown types ignored) + `features/home/
  live_alerts.dart` (re-fetch on `warning_issued && affects_you`, `scenario_changed`,
  `now_override`)
- [x] events pipeline: `EventsRepo` batches ≤ 100, flushes every 10 s / on background / before a
  re-rank, keeps the `engagement` counters from the response · `features/home/card_actions.dart`
  is the single path for impression/tap/expand/dismiss/pin/unpin/hide/unhide/share ·
  `data/repositories/profile_repo.dart` (`/me/card-prefs`, `/me/reset-learning`)
- [x] why-sheet actions send the event, flush and re-fetch `/home`; the sheet also shows what the
  ranker learned (taps / dismissals) for that card type
- [x] animations: re-rank highlight flash on promoted cards + "A warning moved to the top of your
  feed" SnackBar with a **View** action, banner arrival slide/fade (`flutter_animate`)
- [x] places page `/places` over `/me/places` (search, kind, delete, max 8)
- [x] map page `/map` (OSM base, RainViewer past+nowcast frames, play/scrub slider, warning
  circles + markers, user marker); `RadarRenderer`'s "Open map" now pushes `/map`
- [x] settings complete: language (5), units (metric/imperial), personas, home location picker,
  school + commute windows, backend URL, low-bandwidth, larger text, reset learning, about,
  links to places / map / demo sheet
- [x] demo sheet: scenario chips, demo clock presets + picker, persona view, simulate offline,
  low-bandwidth, live-alert status dot, "Open admin console", reset
- [x] low-bandwidth: `?lite=1`, radar tiles suppressed on the card **and** the map page, `Lite`
  badge in the feed footer and the quick-actions row
- [x] a11y: 48 dp targets, semantics labels on cards/quick actions/banner, banner foreground
  chosen from background luminance, text-scale setting — `test/accessibility_test.dart` runs the
  Android + iOS tap-target, labelled-target and **text-contrast** guidelines
- [x] l10n en/hi complete (**282 keys**, parity enforced by `test/l10n_test.dart`), mr/ta/bn
  best-effort (69 keys each, per-key fallback to English) · every renderer/widget English literal
  moved into the ARBs, data-value enums resolved through `lib/l10n/labels.dart`
- [x] app icon + splash (generated sun-behind-cloud mark on IMD blue; adaptive icon, launch
  background, web icons/manifest/boot splash) — no IMD logo (CLAUDE.md §9)
- [x] the double offline/sample banner is collapsed into one `_FeedStatus` strip
- [x] screenshots: `docs/screenshots/b2b_<persona>.png` ×8 + `b2b_ws_before/rerank.png` +
  `b2b_map/places/demo_sheet/hindi.png`, all against the live backend
- [x] gates: `flutter analyze` clean · `flutter test` **90 passed** · `flutter build web`

## B3 checklist
- [x] live backend integration: the web build driven against a local uvicorn (headless Chrome over
  CDP) — **zero console errors, zero failed requests**, and every endpoint the app uses answered
  200 (`/auth/guest`, `/home`, `/events`, `/weather/radar`, `/me/places`, `/ws/alerts`).
  **No contract mismatches found**: a live `/home` and `docs/fixtures/home_severe.json` have
  identical key sets at every level (top level, `Card`, `context`, `freshness`, `engine`,
  `banner`), so `docs/04` needed no edit.
- [x] backend i18n gaps B2b logged, all three fixed + tests (see the B3 commits and Deviations),
  plus everything else the sweep turned up:
  AQI pollutant key/value · `hazard.rain`/`hazard.haze` · Hindi advice, window reasons, crop
  actions, planting tips, packing items, flight-risk detail, nowcast text, scenario warning copy
  and date labels, and the warnings + packing items a traveller's saved places carry.
  `pytest -q` **327 passed**; `docs/fixtures/*.json` regenerated and
  `app/assets/fixtures/home_sample.json` refreshed from `home_severe.json` (B1 deviation).
- [x] WS re-rank re-verified in the web build against the live backend: push → orange banner →
  re-fetch → `commute_conditions` pinned "Severe" → SnackBar "A warning moved to the top of your
  feed · View". Screenshot pair `docs/screenshots/b2b_ws_before.png` → `b2b_ws_rerank.png` still
  matches what the current build does.
- [x] release APK: `flutter build apk --release` → `app/build/app/outputs/flutter-apk/app-release.apk`,
  **62 496 756 B (62.5 MB)**, Gradle task **113.8 s**, wall clock 1 min 55 s (warm, after
  `flutter clean`). `flutter build apk --debug` also re-verified ✓ (~168 MB, Gradle 62.7 s) and its
  output deleted again — the volume was down to 433 MB free with both APKs plus 2.4 GB of Gradle
  intermediates on disk. Debug signing (`app/android/app/build.gradle.kts` keeps
  `signingConfig = signingConfigs.getByName("debug")` for release).
- [x] `.github/workflows/flutter.yml` — push/PR on `app/**`: job `apk` (checkout · temurin JDK 17 ·
  `subosito/flutter-action@v2` pinned to **3.47.2** stable with cache · pub get · analyze · test ·
  `build apk --release` · upload `app-release-apk`) and job `web` (`build web`, uploaded too).
  YAML validated locally, and the **first run went green on GitHub on its own**:
  <https://github.com/Shreyansh303/team_mausam_sih_2026/actions/runs/34258504848> — both jobs
  success, artifacts `app-release-apk` (28.6 MB zipped) and `web-build` (14.6 MB). The
  `compileSdk = 37` worry from H0 gotcha 2 did **not** reproduce on `ubuntu-latest`; the APK step
  took ~25 min cold (Gradle + platform download), the web job ~3 min. The backend workflow is
  green on the same commits.
- [x] README "Run it yourself → 2. App" rewritten for a first-time Flutter user (a)–(f) +
  `scripts/setup_android_emulator.{ps1,sh}` / `run_emulator.{ps1,sh}` + flutter CI badge +
  screenshot grid rebuilt on the b2b/b3 shots.

## C1 / C2
- [x] QA_REPORT.md with every demo step verified — `docs/QA_REPORT.md`, **all 10 steps PASS**
  against a live backend + the real web build, plus all 10 scenarios, `lite=1`, offline (cache and
  bundled), Hindi, dismiss-learning, places/map/settings/demo sheet, and a static release-APK check.
  **40 screenshots** at `docs/screenshots/c1_*.png`. Nine defects found and fixed, one commit and
  one regression test each (see Deviations and QA_REPORT §Defects).
- [x] **README final pass** — every number in it re-verified against the tree on 2026-09-09 and the
  four stale ones fixed: i18n string counts (597/282 → **604/353**, greps in the C2 notes), backend
  tests (327 → **348**), app tests (90 → **103**), and a **third hardcoded `2026-09-08`** demo-clock
  date that C1's sweep missed, in the "Run it yourself → 1. Backend" smoke-test curl (now
  `$(date +%F)`, with the reason spelled out). Also: `/home` latency and payload replaced with
  measured numbers, the phase table finished (C1/C2 ✅, S1–S4 row added), the gates paragraph moved
  to 2026-09-09 and made explicit that nothing was ever run on a handset, the 8-persona screenshot
  grid repointed from the pre-C1 `b2b_*` shots to the post-fix `c1_step03_persona_*` set (plus
  `c1_step05_ws_*`, `c1_step08_hindi_home`, `c1_step07_offline_cached`), and `08_PITCH.md`,
  `QA_REPORT.md` and the `.pptx` added to the docs map. Everything else was already correct —
  33 cards, 15 renderers, 8 personas, 10 scenarios, 212 cities, 35 IMD station ids, the engine
  constants (0.15 blend · 0.4–1.6 clamp · pin at 0.8 · top 8), all re-checked, all right.
- [x] **`docs/08_PITCH.md`** — SIH idea-presentation content: problem (00_VISION quoted verbatim),
  solution, uniqueness (7 differentiators), technical approach (stack · request path · the full
  formula · probed data sources), feasibility (a table of measured numbers, each with where it was
  measured, plus risks/mitigations and an explicit "honest scope boundaries" list), impact (the 8
  personas and the line that lands on each of their screens), future scope (S3 → S1 → S4 → S2, in
  that priority order) and a sources table. No invented metrics, no invented team roster.
- [x] **`docs/TeamMausam_SIH2026_PS26076.pptx`** — 6 slides (title/problem · proposed solution ·
  technical approach · feasibility & viability · impact & benefits · demo + what's next), 7 of the
  C1 screenshots embedded, speaker notes on every slide, 1.4 MB. Built with `pptxgenjs`; how to
  rebuild it is in the C2 notes.

## Deviations from spec (record here)
- **A1** Routers are mounted twice: at `/api/v1` (the 04 base) **and** at the root, so the bare
  verification URLs in 07 (`GET /weather/snapshot?...`) work with curl. No contract change.
- **A1** `core/db.py` and `core/security.py` (listed in 05 §Layout) are **not** written yet — they
  belong to A2's DB/JWT work and were left out to avoid a collision.
- **A1** `Snapshot.derived` carries nine extra blocks beyond the ten named in 04
  (`sun, uv, wind, rain, soil, rainfall_outlook, storm_fog, sea, humidity`) so A2's builders can
  read card `data` straight out of the snapshot. Additive only.
- **A1** `imd_ids.json` has station ids for 35 cities but every `district_id` is `null` — IMD does
  not publish them and every endpoint 401s until the host is whitelisted. `providers/imd.py` skips
  the call when the id is missing.
- **A1** `/locations/popular` returns up to 120 curated cities (04 asks for ≥ 40); 106 are flagged
  `popular` in `cities.json`.
- **A2** `docs/02` §22 school_commute gained `late`,`night` ×0.5 (weekday) — the doc was updated in
  the same commit. Without it the card scores 0.5 all night and 03 §Tests 5 ("at 22:00 it is not in
  the top 3") is unsatisfiable. Every other multiplier is exactly as written in 02.
- **A2** 03 §Tests 7 asks for "≥ 3 of a persona's own cards in the top 8 under `clear_pleasant`".
  That scenario deliberately removes every hazard, so the hazard-gated cards in a coverage list
  (`warnings`, `rain_alert`, `storm_fog_alert`, `frost_alert`, `heat_alert`) do not exist at all —
  parent has 1 ungated card of 3 and commuter 2 of 3. `test_engine.py::test_7…` instead asserts
  that **every ungated** coverage card reaches the top 8 (identical for the six personas with ≥ 3,
  stronger for the other two). Loosening the gates was rejected: a rain alert with no rain is a lie.
- **A2** `Snapshot.fetched_at` now carries the **location's** offset (04 says every time does) and
  equals `now_override` when a demo clock is set. Previously it was `datetime.now(UTC)`, which made
  `Card.updated_at` / `freshness.weather` UTC and `docs/fixtures/*.json` differ on every run.
- **A2** `users.language` is **nullable**; it is `null` until the user picks a language. 04 §User
  still shows a string — `GET /me` coerces `null` → `"en"`. This is what makes the 04 language
  order work: `?lang=` → the user's saved choice → `Accept-Language` → `en`. With a stored `"en"`
  default the profile always shadowed `Accept-Language`.
- **A2** `core/timeutil.parse_any` repairs an offset whose `+` arrived as a space
  (`?now_override=2026-09-08T07:30:00+05:30` URL-decodes to `... 05:30` in curl and browsers).
- **A2** `core/db.init_db()` drops and recreates any table whose live columns no longer match the
  models (name set or nullability) and logs a warning. There is no migration tool; a `mausam.db`
  written by an older build otherwise 500s on the first insert. Demo/guest data only.
- **A2** Additive, no contract change: `Card.data` for `tides` carries a resolved `disclaimer`
  string (04/02 name the key; A1's `Snapshot.tides` exposes `disclaimer_key`), and `GET /home/now`
  (hidden from the schema) reports the effective demo clock for the A3 console.
- **B0** `minSdk` is **24** (Android 7.0), not the 23 originally written in 06 §Android config.
  Flutter 3.47's `MinSdkVersionMigration` rewrites any hardcoded 16–23 back to
  `flutter.minSdkVersion` on every build, so 23 cannot survive. `docs/06_MOBILE_SPEC.md` was
  updated in place with the explanation.
- **B1** `app/assets/fixtures/home_sample.json` is a **byte-for-byte copy of
  `docs/fixtures/home_severe.json`**, not the hand-written payload 07 §B1 allows as a fallback.
  Real engine output beats a transcription of the contract, and 07 says to build against
  `docs/fixtures/` when they exist. Consequence: the offline demo is parent / New Delhi /
  `scenario=thunderstorm` (orange banner, 4 pinned cards), not parent+commuter. Refresh it with
  `cp docs/fixtures/home_severe.json app/assets/fixtures/home_sample.json` whenever A3 regenerates
  the fixtures.
- **B1** `Card.score` is **not** in 0..1. docs/03 §Scoring is `0.5*rel*ctx + 0.5*urg + eng` plus the
  pin/urgency boosts, and `home_severe.json`'s pinned `school_commute` scores **1.175**. 04 only
  ever shows an example value, so this is not a contract break — but the app must treat `score` as
  an opaque ranking number (it is displayed as text in the why sheet, never as a 0–1 bar).
- **B1** `hourly_forecast.data.hours` is **not always 24** (02 card 4 says 24): the engine emits
  what is left of its 48 h window from `now` — 17 entries at 07:30 — and 12 under `?lite=1`.
  Renderers must read the list length, never assume it.
- **B1** No animation package beyond `flutter_animate` 4.5.2. 06 §Animation offers
  `animated_reorderable_list` / `great_list_view` for the re-rank animation "if it builds on the
  installed Flutter"; neither was added in B1 because the re-rank animation itself is B2 work, and
  a keyed list + `flutter_animate` entrance is the documented fallback. B2 decides.
- **A3** After an admin write the router drops **only the `snapshot` cache bucket**
  (`cache.invalidate("snapshot")`), not `cache.clear_all()` as the A2 note suggested. An admin
  write cannot change what Open-Meteo returned, and clearing the provider buckets too made the
  very next `/home` refetch every upstream — **2.7 s measured**, against the < 400 ms warm target
  in 01. With the narrower invalidation the same request is **27 ms** and still sees the new
  warning. (`clear_all()` remains on shutdown and in the test fixture.)
- **A3** `AdminWarning` stores its three times as **ISO strings** plus one epoch float
  (`expires_at_ts`), not `DateTime` columns: SQLite drops the offset from `DateTime(timezone=True)`,
  so the "still live" filter would compare a naive to an aware datetime and raise. Portable to
  Postgres unchanged.
- **A3** Admin warnings are stamped with the **effective demo clock** (`demo_state.now_override`
  when set, else real IST), not `datetime.now(UTC)`. Otherwise a warning pushed while the console's
  demo clock sits at 2026-09-08T07:30 is already "expired" against the snapshot's reference time
  and never reaches `/home`.
- **A3** `/ws/alerts` accepts a **missing** `token` while `DEMO_MODE=1` (the console and `wscat`
  connect without one); an *invalid* token is always closed with code 1008. `docs/04` §WebSocket
  was updated in the same commit, together with the admin-auth clarifications (`/admin/console`
  needs no header; scenario/now-override return the `/admin/state` object; a warning must be
  targeted by lat+lon, district or state; a `now` without an offset is read as IST).
- **A3** No new WS message types were added — the six in 04 are exactly what the server sends.
  A `location` frame is answered with silence by design (the next `warning_issued` carries the
  recomputed `affects_you`), so B2 must not wait for an ack.
- **A3** `docs/fixtures/*.json` were regenerated and **reverted**: the only diff was the random
  `usr_`/`plc_`/`wrn_` ids, so the committed files still match the current backend byte for byte.

- **B2a** B1's `features/home/widgets/card_detail_sheet.dart` (a modal stand-in) is **deleted**;
  tapping a card now pushes `features/home/detail/card_detail_page.dart`, which is what
  docs/06 §Layout always specified. No contract or spec change.
- **B2a** `RendererRegistry.pending` is now an **empty set** rather than being removed:
  `test/fixtures_test.dart` asserts against `implemented ∪ pending`, and a later phase that adds a
  renderer kind still needs somewhere to declare it before the widget exists.
- **B2a** The `tides` card draws an **interpolated** curve. docs/02 card 17 publishes only
  `events[≤4]` turning points, and docs/06 asks for "a 24-h tide curve", so `TideCurve.of` samples
  a half-cosine between consecutive extremes every 20 minutes — the shape a single harmonic gives,
  which is the same family of model the backend used. The markers sit on the **published** points,
  and the card shows the "Estimated" pill plus the backend's `disclaimer` (CLAUDE.md §6).
- **B2a** `RadarRenderer.tileProviderFactory` is a static test hook: `test/fixtures_test.dart`
  sets it to a provider that returns a 1×1 transparent PNG so the radar card is exercised for real
  without touching the network. Production leaves it `null` (flutter_map's own network provider).
- **B2a** New renderer strings are English literals, matching B1's existing renderers; the ARB
  pass is B2b's (see Notes). Card *content* is localized by the backend via `?lang=`.

- **B2b** `compileSdk = 37` is now pinned in `app/android/app/build.gradle.kts` (H0's carry-over,
  gotcha 3): `permission_handler_android` 14.1.0 fails the AAR-metadata check against 36. AGP
  warns "maximum recommended compile SDK … is 36" and builds anyway.
- **B2b** Two **display-only statics** exist so renderers keep working in widget tests that build
  them outside a `ProviderScope`: `Fmt.imperial` (units) and `RadarRenderer.tilesEnabled`
  (low-bandwidth). `SettingsNotifier._applyDisplayFlags` is the only writer, called from
  `hydrate()` and `update()`. The alternative — threading units and lite through fifteen renderer
  constructors — buys nothing the settings notifier does not already guarantee.
- **B2b** The API always answers in metric (docs/04 preamble), so `units: imperial` is a **display**
  conversion in `Fmt.temp` / `Fmt.kph` / `MetricRenderer` only; the value sent to
  `PUT /me/profile` still records the user's choice.
- **B2b** `Card.data` enum values (`sea_state`, `risk`, `impact`, `intensity`, `status`,
  `category`, window labels, hazards, seasons) are **not** localized by the backend — only
  titles/subtitles/insights/reasons are. `lib/l10n/labels.dart` maps them to ARB strings with a
  `Fmt.humanize` fallback, so a value a later backend adds still reads as words. Consequence:
  `GaugeSpec.of`, `AlertSpec.of`, `BarChartSpec.of`, `TimelineWindow.parse` and
  `AdviceGroup.parse` now take an `L`. No contract change.
- **B2b** `levelLabel` keeps `medium` and `moderate` distinct (docs/02 uses both), and
  `qualityLabel` also resolves the `good|caution|poor|avoid` ladder of cards 22/28.
  `test/fixtures_test.dart` expects "Morning drop", not `Fmt.humanize`'s "Morning Drop".
- **B2b** Changing a saved place's `kind` is **DELETE + POST**: docs/04 has no update route for
  `/me/places`, and inventing one would have been a contract change.
- **B2b** The demo sheet's scenario list is the hardcoded docs/05 set, not a call to A1's
  `/weather/scenarios` (which is not in docs/04). It is one static list in
  `features/demo/demo_sheet.dart`; if A* adds a scenario, add it there too.
- **B2b** The warning banner's foreground colour is derived from the background's luminance:
  white on IMD yellow (#F5C518) and orange (#F28C28) fails WCAG AA, and
  `test/accessibility_test.dart` runs `textContrastGuideline` over the whole home screen.
- **B2b** B1's two stacked banners are now one `_FeedStatus` strip with a fixed priority —
  bundled sample → offline → stale cache — so the wording always matches what is on screen.
- **B2b** `TimeWindow` existed twice (`data/models/user.dart` and a new one in the settings
  repo); the model's copy won and gained `copyWith` + the docs/04 defaults.
- **B2b** `mr`, `ta` and `bn` carry **69 keys each** (the chrome a judge sees) and fall back to
  English per key — `flutter gen-l10n` prints "273 untranslated message(s)" for each, which is
  the documented best-effort state 07 §B2 asks for, not a build error.

- **B3** **No app↔backend contract mismatch was found**, so `docs/04_API_CONTRACT.md` is unchanged.
  Checked by driving the real web build against a local uvicorn (console + network captured: zero
  errors, zero failed requests) and by diffing the key sets of a live `/home` against
  `docs/fixtures/home_severe.json` — identical at the top level and inside `Card`, `context`,
  `freshness`, `engine` and `banner`. The only English→English payload change in the whole phase
  is the AQI insight line, which was a bug.
- **B3** Derived-metric services no longer compose user-facing English sentences. Anything a card
  shows is now either resolved in the builder or emitted as a **deferred translation** —
  `i18n.token(key, **params)` → `{"key": …, "params": {…}}` — which the builder turns into a string
  with `i18n.resolve()` once `ctx.lang` is known. Reason: the snapshot is cached per
  (lat, lon, scenario) and **not** per language, so a service cannot localize at all. Changed
  shapes, all *inside* `Snapshot.derived` (untyped by design, A1 deviation 3) and therefore not a
  04 contract change: `school_commute`/`commute` `windows[].reasons`, `planting.tips`,
  `packing.items[]` (`item` → `item_key`, `reason` → a token) and `flight_risk.detail_tokens`.
  The published card `data` keeps exactly the docs/02 shape (plain strings).
- **B3** `Snapshot.nowcast.text_token` is a new optional field on the schema — the same pattern as
  A1's `Tides.disclaimer_key`, additive, and visible only on `/weather/snapshot`. `text` still
  carries the English rendering, so `tests/test_derived.py` and any existing consumer are unaffected.
- **B3** Scenario warning copy is **not** stored as keys in `app/data/scenarios/*.json`; the builder
  resolves `scenario.warning.<hazard>.{title,description}` when `warning.source == "scenario"` and
  falls back to the JSON's own English text when the key is missing. That keeps the 04 `Warning`
  model free of `title_key`/`description_key` fields. It relies on each scenario's warning having a
  distinct hazard (true today: cyclone · fog · cold_wave · heatwave · heavy_rain ·
  very_heavy_rain · thunderstorm). A second warning with the same hazard in another scenario would
  need a per-scenario key instead. Scenario *nowcast* text does carry an explicit `text_key` in the
  JSON, because those are not hazard-unique.
- **B3** Admin-pushed and IMD warnings are **not** localized — they are free text typed by a human
  (or issued by IMD), and inventing a key for them would be a lie. Only the canned scenario copy
  resolves through the catalog. Same for place names.
- **B3** `daylabel()` in `engine/builders/base.py` changed signature (`daylabel(lang, value,
  *, with_dow=False)`) and now resolves `dow.*` / `month.*` through the catalog instead of
  `strftime`. It had no callers before this phase; `rain_probability` is the first.
- **B3** The release APK is signed with the **debug** key (`app/android/app/build.gradle.kts` keeps
  Flutter's generated `signingConfig = signingConfigs.getByName("debug")` for the release build).
  07 §B3 allows this. A Play-store build would need a real keystore + `key.properties`.
- **B3** `docs/fixtures/*.json` were regenerated (the AQI line is a genuine fix) and
  `app/assets/fixtures/home_sample.json` re-copied from `home_severe.json` per the B1 deviation.
  The `usr_`/`plc_`/`wrn_` ids changed with them, as A3 noted they always do.

- **C1** `Snapshot.current` is read off the **forecast hour matching `now_override`** when a demo
  clock is set (`services/snapshot.normalize_forecast(..., ref_now=)`, same for `normalize_air`).
  docs/00 step 2 puts the home at 07:30, but `/home` kept Open-Meteo's live `current` block, so the
  hero drew a moon over a "dawn" feed and every derived metric disagreed with `context.now`.
  **Without a demo clock nothing changes** — live data stays the real observation (CLAUDE.md §6).
- **C1** `GET /health` reports **IST**, not UTC. 04 §Base says every timestamp carries a location
  offset; `/health` has no location, so it uses the same `Asia/Kolkata` clock the WebSocket
  `hello.server_time` does rather than drifting to UTC. No contract change (04 only names the field).
- **C1** `engine/builders/base.num()` quantizes the **exact binary double**
  (`Decimal(float(v))`, `ROUND_HALF_UP`) so card copy reads exactly as the app renders the same
  value with Dart's `.round()` / `toStringAsFixed(n)`. Two symptoms, one cause: a hero saying
  "Feels like 31°" over a sentence saying "feels like 30°C" for one 30.5 (Python's banker's
  `f"{30.5:.0f}"`), and — after the first attempt at this fix quantized `Decimal(str(v))` instead
  — a UV card whose value read "6.0" under a headline saying "6.1", because 6.05 is really
  6.04999… and only the shortest-repr path rounds it up. Verified against `dart run`: 30.5 → 31,
  2.35 → 2.4, 1.25 → 1.3, 0.05 → 0.1, **6.05 → 6.0**. `docs/fixtures/*.json` and
  `app/assets/fixtures/home_sample.json` were regenerated.
- **C1** **Chip/copy ownership, recorded in `docs/06` §Renderers in the same commit.** Two cards
  said the same thing twice: `tides` drew an "Estimated" pill that the card shell *and* the detail
  header already draw from `card.estimated`, and `timeline` drew `data.advice`, which the engine
  reuses verbatim as `insight.detail`. Both renderers now defer to the host when the host is
  already showing it. No contract change — the payload is unchanged.
- **C1** The `timeline` renderer **sorts its windows by start time** and prefixes any window that
  falls on a later day with that day ("Tomorrow 07:00 – 09:00"); the bar's end-of-axis label does
  the same. docs/02 card 22 publishes each window's *next occurrence*, so after 09:00 `morning_drop`
  is tomorrow while `afternoon_pickup` is today — the bar drew them in true chronological order
  while the rows followed payload order, so one card said "afternoon then morning" on the bar and
  "morning then afternoon" in the list, over an axis reading 12:30 → 09:30. Renderer-only; the
  payload and `docs/04` are unchanged, and `docs/06` §Renderers was updated in the same commit.
- **C1** **The demo clock only moves the reading when a forecast hour actually matches it.**
  `normalize_forecast` used to snap an out-of-range `now_override` to the nearest hour it had —
  midnight of the first forecast day — and publish it under the requested timestamp, so a "07:30"
  demo drew a moon with UV 0 over a sunrise-lit feed. Out of range the **live observation stands**,
  `current.time` reports the live time, and the hourly row behind `uv_index`/`visibility_km` moves
  back with it (CLAUDE.md §6). `fetched_at`/`context.now` still carry the requested clock, so the
  *ranking* is unaffected — only the reading. `normalize_air` already worked this way.
- **C1** `DemoSheet.clockPresets` is **computed from today's date** (`clockHours` × `presetFor`),
  not four hardcoded ISO literals. The literals carried 2026-09-08, so from 2026-09-09 onwards
  every preset fell outside the forecast window and the deviation above silently took over. The
  demo sheet's chip labels are unchanged (`07:30 · 13:00 · 18:30 · 22:00`).
- **C1** `DemoSheet.scenarios` lost **`cold_wave`**: docs/05 §Scenarios names ten and there is no
  `backend/app/data/scenarios/cold_wave.json`. An unknown scenario is answered with live data, so
  the chip highlighted and nothing on screen changed — a dead control in the middle of the demo.
  The doc comment claiming the list is fetched from `/weather/scenarios` was also wrong (there is
  no such call, and docs/04 does not publish that route); `test/demo_sheet_test.dart` now pins the
  list to the scenario files the backend ships.
- **C1** `FreshnessChip` ages the payload against the **effective demo clock** (the demo sheet's
  override, an admin `now_override` frame off `/ws/alerts`, else the live payload's own
  `context.now`) rather than the device clock. The backend stamps `freshness` with `now_override`,
  so a judge moving the clock to 07:30 otherwise saw "Updated 16 h ago" on fresh data. A **cached or
  bundled** payload has no usable clock of its own and still ages against the device, which is the
  "Updated 12 min ago" docs/06 asks for.
- **C1** **No catalog string fakes a plural with parentheses any more.** Six count-bearing lines
  read `"{count} saved place(s)"`, `"{days} rainy day(s)…"`, `"{count} health advisory(ies)…"` and
  so on — an unfinished-looking string on a demo screen. Each is now an explicit `.one` / `.other`
  pair in en **and** hi (Hindi does not inflect these, so both forms carry the same sentence), and
  `test_no_catalog_string_fakes_a_plural_with_parentheses` scans the whole catalog so a new key
  cannot bring the pattern back. `docs/fixtures/*.json` and `app/assets/fixtures/home_sample.json`
  were regenerated. Affected: `saved_places.headline`, `saved_places.detail_warning`,
  `daily_forecast.detail`, `health_advisory.headline`, `rainfall_outlook.detail` (and
  `travel_alerts.headline`, below).
- **C1** `insight.travel_alerts.headline` is split into `.one` / `.other` (en + hi). The single key
  rendered "1 travel alert(s) — Mumbai", which reads like an unfinished placeholder on the demo
  screen. Additive to the catalogs; the card `data` shape is unchanged.
- **C1** **Two alert ladders spoke English inside a Hindi card.** `AlertSpec.of` reads every
  alert card's band with `levelLabel`, but that helper only knew the
  `none|low|medium|moderate|high|severe` ladder. docs/02 card 15 `heat_alert.level` is the NWS
  heat-index ladder (`caution|extreme_caution|danger|extreme_danger`) and card 25
  `storm_fog_alert.level` is `watch|warning` — both fell through to `Fmt.humanize`, which is
  English by construction. Under `?lang=hi` the heat card therefore drew "Extreme Caution"
  directly under a backend-localized subtitle reading "अत्यधिक सावधानी", and the fog card read
  "कोहरा warning". Six ARB keys added in en + hi (mirroring the backend's own
  `heat.level.*` / `storm.level.*` strings, which were already complete), six arms added to
  `levelLabel`, and `test/l10n_test.dart` now asserts that every band docs/02 publishes renders
  as Devanagari under `hi` — a fall-through cannot come back silently. App-side only: this is a
  `Card.data` enum, which docs/04 §preamble leaves unlocalized on purpose (B2b deviation), so
  the payload and the contract are unchanged.
- **C1** **The demo sheet's "Pick a time" chip still hardcoded `2026-09-08`.** The earlier C1 fix
  computed `clockPresets` from today's date but left the custom-time `ActionChip` stamping the
  literal, so from 2026-09-09 onwards a judge who picked a time by hand hit exactly the bug the
  presets had been rescued from: the day is outside the forecast window, the backend leaves the
  reading on live data (the deviation above), and the clock looks like a dead control. It now
  builds its override with the same `presetFor`. `test/demo_sheet_test.dart` pins `presetFor`'s
  output to today **and** greps `demo_sheet.dart` for any `'20xx-xx-xxT` literal, so the next
  hardcoded date fails the gate instead of the demo.
- **C1** `DemoSheet.scenarioLabel` (was the private `_humanize`) keeps a one-entry acronym map so
  the `severe_aqi` chip reads **"Severe AQI"**, not "Severe Aqi", next to a card the same app
  titles "AQI". `Fmt.humanize` was deliberately left alone — it is the fallback for *backend*
  enums, and `test/l10n_test.dart` pins its "Volcanic Ash" behaviour.

- **C2** The README's 8-persona screenshot grid now uses the **`c1_step03_persona_*`** shots, not
  the `b2b_*` ones it had. The `b2b_*` persona shots pre-date C1's D2, D8 and D9 fixes, so they can
  show the duplicate "Estimated" pill, the out-of-order timeline and the rounding mismatch that
  those commits removed — a README grid advertising bugs the repo no longer has. Same reason for
  `c1_step05_ws_*` (was `b2b_ws_*`), `c1_step08_hindi_home.png` (was `b3_hindi_localized.png`,
  pre-D4) and `c1_step07_offline_cached.png` (was `b1_home_offline.png`, the B1 shell). The map
  cell keeps `b2b_map.png` — QA_REPORT records the map page as untouched by C1.
- **C2** A **third** hardcoded `2026-09-08` demo-clock date was found in the README, in the
  "Run it yourself → 1. Backend" smoke-test curl. C1 fixed the two in the demo-script section
  (commit `091579e`) and this one sat in a different section, so its sweep missed it. It is now
  `$(date +%F)` like the others, with a sentence saying why. Nothing in `app/` or `backend/` —
  the app-side literals were already fixed in C1 (D5) and `test/demo_sheet_test.dart` greps for
  them; **no equivalent guard exists for the README**, so a future date literal there is on the
  next reviewer to catch.
- **C2** The README's `/home` performance line said "~10 ms on a laptop". Re-measured on this Mac:
  a **warm** `/home` is **2 ms** server-side and the **first** request for a (lat, lon, scenario)
  is **~15 ms** while the snapshot cache is cold — which is also why QA_REPORT's 2 ms and its
  17.7 ms after an admin push (cache invalidated) are both right. Note for anyone re-measuring:
  a request carrying `now_override` misses the snapshot cache every time, so timing loops that
  include a demo clock will read ~14 ms, never 2 ms.
- **C2** No spec doc (00–07) was edited. Every drifted claim was in `README.md`. One
  four-word edit was made to `docs/QA_REPORT.md` §Known limitations 10, which said the README's
  string counts were "left for C2's README pass" — it now says **fixed in C2**, so the evidence
  file does not read as an open defect after the defect is closed. Nothing else in QA_REPORT
  changed. The `.pptx` is a **generated artefact** committed as a binary — regenerate it rather
  than hand-editing the XML (recipe in the C2 notes).

## Notes for next phase

### Stretch (S1–S4) — what C2 hands you (2026-09-09)

**The prototype is finished and evidenced.** A1–C2 are all `[x]`. `docs/QA_REPORT.md` is the
evidence file (verdict **PASS**, all ten demo steps), `docs/08_PITCH.md` is the pitch content with
every number traced to where it was measured, and `docs/TeamMausam_SIH2026_PS26076.pptx` is the
6-slide deck. Nothing is blocked. What follows is optional work.

**Gates on this Mac, this commit** (re-run by C2, not copied forward):
`cd backend && .venv/bin/python -m pytest -q` → **348 passed** (15.8 s) ·
`cd app && ~/development/flutter/bin/flutter analyze` → **No issues found!** (3.5 s) ·
`flutter test` → **103 passed** (36 s) · `flutter build web` → **✓ Built build/web** (62 s).
Disk at the end of C2: **~13 GB free**. The B3 release APK is still at
`app/build/app/outputs/flutter-apk/app-release.apk` — **never run `flutter clean`**, it deletes it.

#### Priority order, and why

1. **S3 · FCM push.** The one that actually matters for a deployment: the WebSocket only reaches an
   app that is open, so today a warning cannot wake a closed handset. The server-side broadcast is
   already a single point (the admin router calls the WS manager), and the payload is already
   defined (`warning_issued` with `affects_you`, docs/04). This is a transport swap plus a Firebase
   project, not an architecture change. Keep the WebSocket — it is what makes demo step 5 visible.
2. **S1 · ML ranker v2.** Fully specified in docs/03 §"Learning (v2)": logistic regression on the
   events already being logged, `score += 0.2·(p_tap − 0.5)`, behind `ENGINE_ML=1`. Two things to
   preserve when you build it: v1 must stay the fallback (the engine's determinism tests depend on
   it), and the blend must stay bounded, or a learned term could outrank a warning — the whole
   safety argument in the pitch rests on that bound.
3. **S4 · More languages.** `mr` / `ta` / `bn` carry 69 app and 54 backend keys each with per-key
   fallback. The pipeline, the parity test (`app/test/l10n_test.dart`, `backend/tests/test_i18n.py`)
   and the fallback all exist, so this is translation work. Current totals, verified in C2:
   **604** backend keys (en, hi) and **353** app messages (en, hi); the partials carry **54**
   backend keys and **69** app messages each. Re-count them with:

   ```bash
   # backend catalogs are flat dicts; app ARBs mix messages with "@"-prefixed metadata
   python3 -c 'import json,glob;[print(f, len(json.load(open(f)))) for f in sorted(glob.glob("backend/app/data/i18n/*.json"))]'
   python3 -c 'import json,glob;[print(f, len([k for k in json.load(open(f)) if not k.startswith("@")])) for f in sorted(glob.glob("app/lib/l10n/*.arb"))]'
   ```

   Do **not** count ARB keys with a bare `grep -c '"'` — it counts the `@`-metadata blocks too and
   over-reports the partial locales by one.
4. **S2 · Android home-screen widget.** Needs `hero` plus the top pinned card, which is what
   `/home?lite=1` already returns. Platform-channel work on the Android side only.

#### Smaller items already identified (do these before the stretch phases if a demo is near)

- **Device smoke test.** The APK has never been installed. If a phone appears: install
  `app-release.apk`, check first launch, the location-permission prompt, GPS onboarding and
  background event flushing — the only paths the web build cannot exercise. Until then the honest
  phrasing everywhere (README, pitch, deck) is "verified in the web build plus a static APK check".
- **Release keystore.** `app/android/app/build.gradle.kts` still signs release with the debug key.
- Seed `hiddenCardsProvider` from `ProfileRepo.cardPrefs()` in `main` so pins/hides survive a
  reinstall (one call; QA_REPORT §Known limitations 3).
- File the **IMD whitelisting request** (README §IMD integration path has the exact contents) and
  fill the `district_id` values in `backend/app/data/imd_ids.json` when the list comes back.

#### How the deck was built (to regenerate or edit it)

The `.pptx` is generated, not hand-authored. Rebuild rather than editing the packed XML.

- **Generator:** a ~470-line `pptxgenjs` script in the agent scratchpad (same convention C1 used
  for its CDP screenshot driver — `scripts/` was outside C2's scope). `npm install pptxgenjs` into
  a throwaway directory; nothing was added to the repo's toolchains.
- **Content source:** `docs/08_PITCH.md`, section for section. Slides are
  title/problem · proposed solution · technical approach · feasibility & viability · impact &
  benefits · demo + what's next. Speaker notes on all six.
- **Images:** seven `docs/screenshots/c1_*.png` (aspect 780×1688 = 0.4621, so
  `width = height × 0.4621`).
- **Gotchas that cost time.** (a) `pres.layout = "LAYOUT_WIDE"` **before** adding slides, or the
  canvas is 10″ wide and off-canvas shapes are silently dropped. (b) Hex colours without `#` and
  without alpha, or the file will not open. (c) `bullet: true` renders its glyph far outside a
  `margin: 0` text box — a literal `"·  "` prefix with no bullet option is what looks right.
  (d) pptxgenjs text boxes are **vertically centred** by default; pass `valign: "top"` on any box
  taller than its text or you get a gap under the heading.
- **Verification without LibreOffice** (this Mac has no `soffice`/`pdftoppm`): build one
  single-slide `.pptx` per slide, then `qlmanage -t -s 1400 -o <dir> slide-N.pptx` renders each via
  macOS Quick Look. That is how every slide here was eyeballed. Note Quick Look substitutes fonts
  (it drew Calibri as a serif), so trust it for layout and overflow, not for typeface.
- **Validation:** the pptx skill's `scripts/office/validate.py` → "All validations PASSED!".

### C2 — what C1 hands you (2026-09-09)

**Read `docs/QA_REPORT.md` first.** It is the evidence file for everything below: a row per demo
step with the doc quoted, what was observed, pass/fail, the screenshot and the fix commit.

**Gates on this Mac, this commit.** `pytest -q` **348 passed** (12.2 s) · `flutter analyze` clean ·
`flutter test` **103 passed** · `flutter build web` ✓. The release APK from B3 is still on disk at
`app/build/app/outputs/flutter-apk/app-release.apk` and was **not** rebuilt (the volume is at
~8.4 GB free — do not run `flutter build apk` or `flutter clean` without checking `df -h /` first,
and never `flutter clean`, which deletes that APK).

#### What the pitch can claim, with evidence

Every one of these was **measured on this machine on 2026-09-09**, not estimated. Numbers first,
because a judge will ask.

| Claim | Number | Where it is evidenced |
|---|---|---|
| Backend tests, fully offline | **348 passed** | `pytest -q` |
| App tests · static analysis | **103 passed** · analyze clean | `flutter test` / `flutter analyze` |
| Card types · renderers | **33** · **15** | `app/engine/catalog.py`, docs/02 |
| Personas | **8** (1–3 selectable) | QA_REPORT step 3 — all eight photographed |
| Scenarios, all verified to render | **10** | QA_REPORT §Scenario overlays |
| Languages offered · complete | **5** · **2** (en, hi: 604 backend + 353 app strings each) | QA_REPORT step 8 |
| Cities in the offline gazetteer | **212** (106 popular) | `backend/app/data/cities.json` |
| Warm `/home` | **2 ms** server-side, **4.6 ms** median round trip, **3.6 ms** under `lite=1` | QA_REPORT §Headline numbers |
| `/home` right after a live warning push | **17.7 ms** | QA_REPORT step 5e |
| Release APK | **62 496 756 B**, 3 ABIs, minSdk 24 / targetSdk 36 | QA_REPORT §Release APK |
| Learning: dismisses needed to demote a card out of the feed | **3** (rank 3 → 8, score 0.470 → 0.268) | QA_REPORT step 6c |
| QA screenshots this phase | **40** | `docs/screenshots/c1_*.png` |

**Two claims worth leading with, because they are unusual and they are true here:**
1. **Server-driven ranking.** The app never computes a score. `pinned / hero / cards / more_cards`
   arrives ranked from `/home`, so IMD could add, reorder or retire a card **without an app
   release**. Nothing in the Flutter tree hardcodes a card order.
2. **Honest data, enforced.** Tides, pollen and traffic are modelled and say so — `"source":
   "estimated"`, an **Estimated** chip, and on tides a disclaimer naming INCOIS and the Survey of
   India. IMD was returning `401` for the entire QA run and the app never once pretended otherwise.

#### Best screenshots to feature

| Slot | File | Why |
|---|---|---|
| **Hero / opening slide** | `c1_step02_morning_0730_parent_commuter.png` | The whole thesis in one frame: 07:30, School run first, reasons visible, hero showing a dawn reading |
| **The one-line demo of personalization** | `c1_step03_persona_parent.png` + `c1_step03_persona_fitness.png` + `c1_step03_persona_health.png` | Same backend, same location, same minute — three completely different feeds |
| **Live re-rank (the money shot)** | `c1_step05_ws_before.png` → `c1_step05_ws_rerank.png` | Before/after pair, orange banner, pinned commute card, "A warning moved to the top of your feed · View" |
| **Severity at full strength** | `c1_step11_scenario_heatwave.png` | Red banner + two pinned cards + the re-rank SnackBar, and `scenario` shown honestly as the source |
| **Explainability** | `c1_step06_why_sheet_pollen.png` → `c1_step06_humidity_demoted_to_more.png` | "Why am I seeing this?" and the card actually moving afterwards |
| **Honest data** | `c1_step04_coastal_tides_estimated.png` | Estimated chip + the INCOIS disclaimer, on a genuinely pretty card |
| **Coastal gating** | `c1_step04_coastal_panaji_home.png` | Sea/tides/water-temp appear only because the location is coastal |
| **Multilingual** | `c1_step08_hindi_home.png` + `c1_step08_hindi_cards.png` | Chrome *and* card copy, advice bullets and reason chips in Hindi |
| **Works without a network** | `c1_step07_offline_cached.png` | "Updated just now · cached" + "Could not refresh. Showing saved data." |
| **Built for Indian bandwidth** | `c1_extra_low_bandwidth_map.png` | The map saying "Low-bandwidth mode: radar tiles are off." |
| **Traveller story** | `c1_step09_packing_suggestions.png` | "London · Raincoat / umbrella · Rain chance up to 53% in 3 days" — the demo script's own line, delivered |

`b2b_demo_sheet.png` and `b2b_places.png` are **stale** — the README grid was already repointed at
`c1_extra_demo_sheet.png` and `c1_step09_places_page.png`. Do not reuse the `b2b_*` pair in the deck.

#### Things C2 should fix or decide

- **README string counts have drifted.** It says "597 backend strings each, plus 282 app-chrome
  strings"; the real numbers are **604** and **353**. C1 deliberately left this alone (its README
  scope was demo steps that proved wrong). Fix it in the README pass.
- **No device smoke test exists.** The APK was verified statically only (package id, label, SDKs,
  ABIs, permissions, signature) — there is no phone and no emulator image on this Mac, and only
  ~8.4 GB free. If a phone turns up before the pitch, install it once and check first launch, the
  location-permission prompt and GPS onboarding; those are the only paths the web build cannot
  exercise. Say "verified in the web build + static APK check" rather than "tested on device".
- **The APK is debug-signed** (07 §B3 allows it). If the deck claims "installable", that is true;
  if it claims "release-ready", it is not — a Play build needs a keystore.
- **`mr`/`ta`/`bn` are best-effort.** Say "5 languages, 2 complete" — the partial three fall back
  per key and a judge switching to Tamil will see mostly English. Do not claim five complete.
- **The demo needs a network.** Open-Meteo and RainViewer are keyless but live. Rehearse the
  offline path (step 7) as a *feature*, and know that the bundled sample is parent / New Delhi /
  `thunderstorm`, not whatever was last on screen.

#### Rehearsal notes for whoever runs the live demo

- Start the backend first, point the app at **`http://127.0.0.1:8000`** (never `localhost`), and
  wait for the **green dot** on the freshness chip — that is `/ws/alerts` connected and it is what
  makes step 5 work.
- **Delete any pushed warning before moving on.** A live warning pins cards and changes every later
  screen; `GET /admin/state` lists the ids, `DELETE /admin/warnings/{id}` clears them.
- The demo clock's presets and its "Pick a time" picker are both built on **today**, so 07:30 works
  on any date now. A hand-written `now_override` still has to be inside the 48-h forecast window or
  the ranking moves while the reading stays live (deliberate — see Deviations).
- Step 6 takes **three** "Show less" taps to push a card into "More for you", not two. Both the
  README and this file now say so; do not promise two on stage.
- The traveller step needs **two saved places added first** (Places page → Travel → Mumbai, London).
  A fresh guest has none, and `saved_places` / `packing_suggestions` / `travel_alerts` simply are
  not there until it does.

### C1 — what B3 hands you (2026-09-08)

**Everything is green on this Mac.** `pytest -q` **327 passed** · `flutter analyze` clean ·
`flutter test` **90 passed** · `flutter build web` ✓ · `flutter build apk --release` ✓ ·
`flutter build apk --debug` ✓. **Both GitHub workflows are green too** (`backend` and the new
`flutter`, first run, APK + web artifacts uploaded). No app↔backend contract mismatch exists —
see Deviations.

**Artefacts C1 can use straight away**

| what | where |
|---|---|
| release APK (debug-signed, all ABIs, 62.5 MB) | `app/build/app/outputs/flutter-apk/app-release.apk` — **already built, still on disk**; `app/build/` is git-ignored |
| APK from CI | Actions → **flutter** → the run for your commit → artifact `app-release-apk` |
| web bundle | rebuild with `flutter build web` (42 MB, ~2 min); the CI `web` job also uploads one |
| bundled offline payload | `app/assets/fixtures/home_sample.json` = `docs/fixtures/home_severe.json` |

**The exact commands, copy-paste (macOS; an agent shell has no `~/.zshrc`)**

```bash
# 0. environment
export JAVA_HOME="$HOME/development/jdk-17"
export ANDROID_HOME="$HOME/development/android"; export ANDROID_SDK_ROOT="$ANDROID_HOME"
FL=~/development/flutter/bin/flutter

# 1. backend (run_in_background; NEVER in the foreground — it never exits)
cd backend && .venv/bin/python -m uvicorn app.main:app --port 8000
curl -s http://127.0.0.1:8000/api/v1/health          # {"status":"ok",...,"scenario":"live"}
pkill -f "uvicorn app.main:app"                      # stop it

# 2. gates
cd backend && .venv/bin/python -m pytest -q          # 326 passed, ~7 s
cd app && $FL analyze && $FL test                    # clean, 90 passed
cd app && $FL build web                              # ~2 min
cd app && $FL build apk --release                    # ~2 min warm; run_in_background + dangerouslyDisableSandbox

# 3. serve the web build for a browser/CDP demo (use 127.0.0.1, never localhost)
cd app/build/web && python3 -m http.server 8080 --bind 127.0.0.1
```

**The WS re-rank demo, re-verified in B3 against the current build.** Backend on 8000, the app
pointed at `http://127.0.0.1:8000` (the freshness chip grows a green dot when `/ws/alerts` is up),
then:

```bash
# push (or use the console at http://127.0.0.1:8000/admin/console, key `mausam-admin`)
curl -s -X POST http://127.0.0.1:8000/api/v1/admin/warnings \
  -H 'Content-Type: application/json' -H 'X-Admin-Key: mausam-admin' \
  -d '{"severity":"orange","hazard":"thunderstorm","title":"Thunderstorm warning — Delhi",
       "description":"Thunderstorm with lightning and gusty winds (50-60 km/h) likely over Delhi.",
       "district":"New Delhi","state":"Delhi","lat":28.61,"lon":77.21,
       "radius_km":75,"ttl_minutes":120}'
# clean up afterwards — a live warning changes every later screenshot
curl -s -H 'X-Admin-Key: mausam-admin' http://127.0.0.1:8000/api/v1/admin/state   # lists ids
curl -s -X DELETE -H 'X-Admin-Key: mausam-admin' \
  http://127.0.0.1:8000/api/v1/admin/warnings/<id>
```
Within ~1 s: orange banner → `/home` re-fetch → `commute_conditions` (and `warnings`) pinned with
"Severe impact" → SnackBar *"A warning moved to the top of your feed · View"*. Global scenario and
demo clock over the same admin API: `POST /admin/scenario {"name":"thunderstorm"}` (the body key is
**`name`**, not `scenario`) and `POST /admin/now-override {"now": …}` / `{"now": null}`.

**Screenshot driver.** B2b's CDP recipe still works verbatim (Chrome 152, Node 26 at
`/opt/homebrew/bin/node`, no npm install). B3 re-used it and added nothing to the repo — the
driver lives in the agent scratchpad. Two things worth copying if you rebuild it: seed
`localStorage` between **three** navigations (seed → load → load, waiting ~4 s and ~9 s), and put
`Emulation.setDeviceMetricsOverride` + `setEmulatedMedia(prefers-color-scheme: light)` +
`Page.captureScreenshot` in **one** CDP session, because the overrides die with the socket.
The quick-actions row (Radar · Places · Demo) sits at CSS y ≈ 522 with x ≈ 73 / 195 / 317 —
**but only when nothing is pinned above the hero**; delete any pushed warning first or the click
lands on a card instead (that happened in B3).

**Known gaps / things C1 should decide about**
- **`flutter build apk --release` needs disk.** Building it left the volume at **433 MB free**
  (2.4 GB of Gradle intermediates + a 176 MB debug APK + a 62 MB release APK). B3 deleted
  `app/build/app/intermediates`, the debug APK, `outputs/apk/debug`, `outputs/mapping` and
  `outputs/native-debug-symbols` afterwards and got back to ~3.2 GB free. **Run `flutter clean`
  first and delete the intermediates after** — or the next build fails on ENOSPC, not on code.
- **CI is green but slow.** The `apk` job needs ~25 min cold (Gradle + the `android-37` platform
  download); the `web` job ~3 min. H0's `android-37` vs `android-37.0` gotcha did not reproduce on
  `ubuntu-latest`. If a future runner image ever hits `Failed to find target with hash string
  'android-37'`, add an explicit `sdkmanager "platforms;android-37"` step before the build.
- `traveler` still has no saved places on a fresh guest, so `saved_places` / `packing_suggestions` /
  `travel_alerts` are absent until you add two places (Places page, or `POST /me/places`). Do that
  before recording the traveller part of the demo — the packing item list is now localized too.
- The app still never calls `GET /me/card-prefs` on start-up (B2b note): hides/pins survive within
  a session because `/home` carries them back, not across a reinstall.
- `mr`/`ta`/`bn` remain best-effort (69 app keys, 54 backend keys) and fall back to English per key.
  `flutter build` prints "277 untranslated message(s)" for each — expected, not an error.
- Nothing in the repo depends on IMD being reachable; `providers/imd.py` 401s and falls through.

### B3 — what B2b hands you (2026-09-08)

**Gates as run on this Mac, in `app/`** (absolute flutter path — an agent shell has no `~/.zshrc`):
```bash
FL=~/development/flutter/bin/flutter
cd app && $FL analyze          # "No issues found!"  (~4 s warm)
cd app && $FL test             # 90 passed           (~20 s)
cd app && $FL build web        # ✓ Built build/web   (~2 min, 42 MB)
```
`flutter build apk` was **not** run in B2b (only ~3.4 GB free on this volume). `compileSdk = 37`
is committed, so the APK gate should pass with the two machine-level Gradle fixes H0 already
applied (wrapper zip pre-seeded, `platforms/android-37` alias). Run `flutter clean` first if the
disk is tight — `app/build` holds ~0.4 GB and a debug APK another 168 MB.

**New tests** (all in `app/test/`): `alerts_socket_test.dart` (9 — ping/pong, the six docs/04
frames, unknown types, `location` instead of a reconnect, 1008 = no retry, backoff, disconnect),
`events_repo_test.dart` (7 — batch shape, ≤ 100, timer flush, dropped batch offline, queue cap,
engagement counters), `l10n_test.dart` (7 — en/hi key + placeholder parity, mr/ta/bn validity,
`AppConfig.supportedLanguages` vs the delegate, every locale builds, label helpers),
`accessibility_test.dart` (3 — tap targets, labelled targets, **text contrast**, semantics labels,
1.5× text scale). `test/support.dart` holds the two things every widget test that mounts the home
needs: `BlankTileProvider` (keeps `flutter_map` off the network **and** off `path_provider`) and
`silentAlertsSocket()` (no real WebSocket, no pending reconnect timer). **Use both in any new
widget test that pumps `HomePage`** — without them you get a `MissingPluginException` from the
tile cache and a `SocketException` after the test ends.

**The WS demo, end to end** (this is the one to rehearse for judges):
1. `cd backend && .venv/bin/python -m uvicorn app.main:app --port 8000` (run_in_background).
2. Open the app (web build or APK) with the backend URL set to **`http://127.0.0.1:8000`** —
   never `localhost`, headless Chrome resolves it to `::1` and uvicorn binds IPv4 only.
3. The freshness chip grows a **green dot** once `/ws/alerts` is connected; the demo sheet shows
   "Live alerts: connected" with the same dot.
4. Push the warning — the admin console at `/admin/console` (key `mausam-admin`, preset
   *Orange thunderstorm — Delhi*), or straight over curl:
   ```bash
   curl -s -X POST http://127.0.0.1:8000/api/v1/admin/warnings \
     -H 'Content-Type: application/json' -H 'X-Admin-Key: mausam-admin' \
     -d '{"severity":"orange","hazard":"thunderstorm","title":"Thunderstorm warning — Delhi",
          "description":"Thunderstorm with lightning and gusty winds likely over Delhi.",
          "district":"New Delhi","state":"Delhi","lat":28.61,"lon":77.21,
          "radius_km":75,"ttl_minutes":120}'
   ```
5. Within a second the app shows the orange banner (from the socket frame, before `/home` comes
   back), re-fetches, flashes the promoted cards and raises the SnackBar "A warning moved to the
   top of your feed · View". `docs/screenshots/b2b_ws_before.png` → `b2b_ws_rerank.png` is exactly
   that pair.
6. Clean up: `curl -X DELETE -H 'X-Admin-Key: mausam-admin' .../api/v1/admin/warnings/<id>`.

**Screenshot recipe, as it actually worked here** (extends B1/B2a; driver script lives in the
agent scratchpad because `scripts/` is out of B2's scope — re-create it from these steps):
1. `flutter build web`; `cd app/build/web && python3 -m http.server 8080 --bind 127.0.0.1` and the
   backend on 8000, both in the background.
2. `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu
   --no-first-run --remote-debugging-port=9222 --user-data-dir=<scratch>/cdp-profile about:blank`
   — Chrome 152 on this Mac.
3. **Node 26 is installed** (`/opt/homebrew/bin/node`) and has a global `WebSocket` + `fetch`, so
   the CDP driver is ~150 lines with **no npm install**. Per shot: `PUT
   http://127.0.0.1:9222/json/new?about:blank` → connect to `webSocketDebuggerUrl` →
   `Page.enable`, `Runtime.enable`, `Emulation.setDeviceMetricsOverride`
   (390×844 @2, `mobile: true`), `Emulation.setEmulatedMedia`
   (`prefers-color-scheme: light`, otherwise headless renders the dark theme).
4. Seed `shared_preferences` **between two loads**: navigate once, `Runtime.evaluate` the
   `localStorage.setItem('flutter.…')` block, then navigate **twice more** (the first load after
   seeding races the guest token and 401s into "Sample data"), waiting ~4 s and ~9 s. Keys:
   `flutter.onboarded='true'`, `flutter.language='"en"'`,
   `flutter.backend_url='"http://127.0.0.1:8000"'`, `flutter.personas='["parent"]'`,
   `flutter.home_location='"{…}"'` (a JSON **string** containing JSON), `flutter.units='"metric"'`.
5. `Page.captureScreenshot` → PNG. Taps use `Input.dispatchMouseEvent`
   (`mousePressed` + `mouseReleased`) in **CSS** pixels: the quick-actions row sits at y ≈ 522,
   with Radar x ≈ 73, Places x ≈ 195, Demo x ≈ 317 — that is how `b2b_map/places/demo_sheet.png`
   were taken. Scrolling is `type: 'mouseWheel'`.
6. Emulation overrides die with the WebSocket session, so metrics + media + screenshot must
   happen in one run — one CDP session per screenshot is the simplest way to keep that true.

**Routes and files added by B2b** — `/places` (`features/places/places_page.dart`), `/map`
(`features/map/map_page.dart`), the demo sheet (`features/demo/demo_sheet.dart`, opened from the
AppBar flask icon, the quick-actions row and Settings), plus
`data/ws/alerts_socket.dart`, `data/repositories/{places,radar,profile}_repo.dart`,
`features/home/{live_alerts,card_actions}.dart`, `features/home/widgets/quick_actions.dart`,
`lib/l10n/labels.dart`.

**Known gaps B3 should pick up**
- **Backend i18n, visible under `?lang=hi`** (not an app bug, and invisible in the fixtures):
  card *advice/reason* strings still come back in English — e.g. "Calm and clear through the
  window" in the Hindi screenshot — and B2a already logged the nowcast subtitle rendering as the
  raw key `hazard.rain` plus the AQI insight's missing pollutant value. All three are backend
  i18n fixes.
- `traveler` has no saved places on a fresh guest, so `saved_places` / `packing_suggestions` /
  `travel_alerts` do not appear in `b2b_traveler.png`. Add two places from the Places page (or
  seed them over `/me/places`) before recording the traveller part of the demo.
- The app never calls `GET /me/card-prefs` on start-up: pins/hides are applied server-side by
  `POST /events` and arrive back inside `/home`, so the local overlay is only for the current
  session. If a future phase wants hidden cards to survive a reinstall, seed
  `hiddenCardsProvider` from `ProfileRepo.cardPrefs()` in `main`.
- Onboarding and home still survive a dead backend (bundled fixture + cache); the WS client just
  keeps retrying with backoff. `flutter test` covers the dead-backend home path.

### H0 — this Mac (2026-09-08)

The project moved from the original Windows box to a **MacBook Air (Apple M1, arm64)**. Everything
below is verified on this machine; the Windows-only parts of `CLAUDE.md` §8 and
`docs/SETUP_WINDOWS.md` (`D:\sdk`, `setx`, `TEMP=D:\sdk\tmp`, `taskkill`,
`scripts/setup_flutter_windows.ps1`, `scripts/flutter_env.*`) **do not apply here** — none of them
were run, and the Gradle "Unable to establish loopback connection" bug does not reproduce on macOS.

**Gate results (every one re-run end-to-end on 2026-09-08 after the interrupted first attempt)**

| gate | result |
|---|---|
| `backend/.venv/bin/python -m pytest -q` | **300 passed**, 1 warning, 10.38 s |
| uvicorn + `curl /api/v1/health` | `{"status":"ok","version":"0.1.0",…,"scenario":"live"}` |
| `flutter doctor -v` | Flutter ✓ · Android toolchain (SDK 36.0.0, licences accepted) ✓ · Chrome ✓ · Network ✓ · **Xcode `[!]`** (simulator runtimes + CocoaPods — allowed, see below) |
| `flutter pub get` / `flutter analyze` | deps resolved · **"No issues found!" (18.1 s)** |
| `flutter test` | **64 passed** |
| `flutter build web` | **✓ Built build/web** — 1 min 43 s |
| `flutter build apk --debug` | **✓ Built build/app/outputs/flutter-apk/app-debug.apk** — 168 MB — **but only after three fixes; the third one is not committed**, see "Three Gradle/Android gotchas" below |

**Machine**

| | |
|---|---|
| OS | macOS 26.6.2 (build 25G83), Darwin 25.6.0, `darwin-arm64`, locale en-GB |
| CPU | Apple M1 |
| Shell | zsh (`~/.zshrc`; a backup of the pre-H0 file is at `~/.zshrc.bak.h0`) |
| Homebrew | `/opt/homebrew` — present but **not used** for the toolchain (no casks, no sudo, no pkg installers) |
| Repo | `/Users/anushka/Downloads/team_mausam_sih_2026` |

**Absolute tool paths** (an agent shell does not source `~/.zshrc` — always use these)

| tool | path | version |
|---|---|---|
| system python | `/Users/anushka/.pyenv/shims/python3` (pyenv) | 3.13.2 |
| **venv python** | `backend/.venv/bin/python` | 3.13.2 |
| **flutter** | `/Users/anushka/development/flutter/bin/flutter` | 3.47.2 stable, engine `a804b26164`, rev `d3b14c8769` |
| dart | `/Users/anushka/development/flutter/bin/dart` | 3.13.2 (DevTools 2.60.0) |
| **JDK 17** | `/Users/anushka/development/jdk-17` (`JAVA_HOME`) | Temurin 17.0.20.1+1 (Adoptium tar.gz) |
| **Android SDK** | `/Users/anushka/development/android` (`ANDROID_HOME`, `ANDROID_SDK_ROOT`) | platform-tools · platforms `android-35`+`android-36`+`android-37.0`+`android-37` (the last is the alias from gotcha 2) · build-tools `35.0.0`+`36.0.0` · `cmake/3.22.1` · all licences accepted |
| sdkmanager | `/Users/anushka/development/android/cmdline-tools/latest/bin/sdkmanager` | cmdline-tools **21.0** (see gotcha below) |
| adb | `/Users/anushka/development/android/platform-tools/adb` | |
| Chrome | `/Applications/Google Chrome.app` | 152.0.7977.82 (already installed — no cask needed) |
| Xcode | `/Applications/Xcode.app` | 26.6 (17F113) — installed but **incomplete**, see below |

`~/.zshrc` got one block (`# --- Team Mausam SIH 2026 toolchain (added by phase H0) ---`) exporting
`JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT` and prepending
`flutter/bin`, `$JAVA_HOME/bin`, `cmdline-tools/latest/bin`, `platform-tools` to `PATH`. A **human**
terminal picks that up after `source ~/.zshrc`; an **agent** shell does not, so agents must keep
using the absolute paths above (or re-export inline — the pattern used throughout H0 is
`export JAVA_HOME="$HOME/development/jdk-17"; export ANDROID_HOME="$HOME/development/android"; export PATH="$HOME/development/flutter/bin:$JAVA_HOME/bin:$PATH"`).

**Gotcha that cost the most time: the Android command-line tools split in two.**
The current `cmdline-tools;latest` (rev **16111833**, version 23.0, and the arch-split 22.0 before
it) **no longer ships the classic `sdkmanager`** — it ships a new `android` CLI, and `sdkmanager` is
only a deprecation shim over `android sdk`. That shim **hangs forever** on
`sdkmanager --install <pkgs>` from a non-interactive shell (the wrapper `/bin/sh` sits there and
never spawns a JVM), and `sdkmanager --version` prints three warning lines before the number, which
`flutter doctor` is not written for. Fix, and what is installed now: the **last classic release,
cmdline-tools 21.0** (`https://dl.google.com/android/repository/commandlinetools-mac-15641748_latest.zip`)
is unzipped as `~/development/android/cmdline-tools/latest`; the new 23.0 is parked next to it as
`~/development/android/cmdline-tools/23.0` and is unused. With 21.0 in place,
`yes | sdkmanager --sdk_root=$ANDROID_HOME <pkgs>` and `yes | sdkmanager --sdk_root=$ANDROID_HOME --licenses`
both work and `flutter doctor` reports "All Android licenses accepted." **Do not "upgrade"
`cmdline-tools/latest` to 23.0** — it will break `flutter doctor` and every scripted SDK install.

**Three Gradle/Android gotchas found while running the APK gate (2026-09-08, all verified)**

1. **The Gradle wrapper cannot download its own distribution here.** `gradlew` fetches
   `https://services.gradle.org/distributions/gradle-9.3.1-all.zip`, which 307s to GitHub and then
   to `release-assets.githubusercontent.com`. That name resolves to four IPs and **one of them
   (185.199.109.133) refuses TCP 443 on this network**; the JVM tries only the first address it is
   handed and dies with `java.net.ConnectException: Connection refused` inside
   `org.gradle.wrapper.Download`. `curl` survives it (happy-eyeballs retries the other IPs), so
   this is *not* the agent sandbox — it fails identically with `dangerouslyDisableSandbox: true`,
   and a plain `java` one-liner reproduces it. **Fix (already applied, keep it):** the zip was
   downloaded with curl straight into the wrapper's cache slot —
   ```bash
   cd ~/.gradle/wrapper/dists/gradle-9.3.1-all/9ot9r568e8zfvvd4mn8rbu1j0 \
     && curl -fL --retry 5 --retry-all-errors -o gradle-9.3.1-all.zip \
        https://services.gradle.org/distributions/gradle-9.3.1-all.zip
   ```
   sha256 `17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43` (matches
   `…/gradle-9.3.1-all.zip.sha256`). `Install.createDist` skips the download when the zip is
   already there. Redo this if `~/.gradle` is ever wiped or the wrapper version changes.
2. **`platforms;android-37` does not exist any more — only `platforms;android-37.0`.** A plugin
   (see 3) makes AGP ask for target hash `android-37`; AGP auto-installed
   `platforms/android-37.0` (`AndroidVersion.ApiLevel=37.0`, `<api-level>37.0</api-level>`, SDK XML
   v4), which the older parser cannot match, so the build died with
   `Failed to find target with hash string 'android-37'`. **Fix (already applied):**
   `platforms/android-37` is an APFS clone of `android-37.0` with `source.properties`
   (`AndroidVersion.ApiLevel=37`) and `package.xml` (`path="platforms;android-37"`,
   `<api-level>37</api-level>`) patched to the legacy naming. Both dirs are kept.
   The successful build also auto-installed `~/development/android/cmake/3.22.1`.
3. **`app/android` still pins `compileSdk = flutter.compileSdkVersion` (36) but
   `permission_handler_android` 14.1.0 requires 37**, so `assembleDebug` fails the AAR-metadata
   check: "Dependency ':permission_handler_android' requires … version 37 or later … :app is
   currently compiled against android-36". **This is a project fix, not a machine fix, so H0 did
   not commit it.** Verified working one-liner for whoever owns `app/` next (B2b or B3): in
   `app/android/app/build.gradle.kts` change `compileSdk = flutter.compileSdkVersion` to
   `compileSdk = 37`. With that line and nothing else, `flutter build apk --debug` succeeds
   (`✓ Built build/app/outputs/flutter-apk/app-debug.apk`, 176 254 607 B ≈ 168 MB, Gradle task
   174.3 s). AGP 9.1.0 prints "maximum recommended compile SDK … is 36" as a warning only. H0
   reverted the edit, so `git status` is clean and the APK gate will fail again until someone
   commits it. `flutter analyze`, `flutter test` and `flutter build web` are unaffected.
   Why it never bit anyone before: the only recorded APK build (B0 checklist, Windows, 150 MB)
   predates B1, which is where `permission_handler` entered `pubspec.yaml` — B1/B2a verified
   `analyze` + `test` + `build web`, never `build apk`. `pubspec.lock` was **not** touched here.

**Other machine facts worth knowing**
- `android-36` + `build-tools;36.0.0` are the ones that actually matter: `app/android` pins
  **AGP 9.1.0, Kotlin 2.4.0, Gradle 9.3.1** and `compileSdk = flutter.compileSdkVersion` (36 on
  Flutter 3.47). 35 is installed too, but a 35-only SDK will not build this app.
- `/usr/bin/java` is the Apple stub and errors with "Unable to locate a Java Runtime" — never rely
  on it; always point at `~/development/jdk-17`.
- `app/android/local.properties` is gitignored and absent; `flutter build apk` regenerates it.
- **Disk is tight**: the volume was at 91 % before H0 and is at **96 % after the APK gate
  (≈7.5 GB free of 228 GB)**. The toolchain costs ≈3.9 GB (Flutter) + ≈1.3 GB (Android SDK, now
  ≈1.5 GB with `android-37`/`android-37.0`) + ≈0.3 GB (JDK); `~/.gradle` grew to **≈2.8 GB** on the
  first APK build (235 MB wrapper zip + caches) and `app/build` holds another ≈0.4 GB, of which the
  debug APK alone is 168 MB. `flutter clean` reclaims `app/build`. All installer archives were
  deleted after extraction (`~/development/dl/` now holds only small logs). Watch free space before adding an
  emulator system image (`system-images;android-36;...` is another ~1.5 GB) — none is installed, so
  there is **no AVD**; `flutter devices` offers only `macos` and `chrome`.
- **Xcode 26.6 is installed but `flutter doctor` still flags it** — "Unable to get list of installed
  Simulator runtimes" and "CocoaPods not installed". This is the one `[!]` category and is
  **expected/allowed** by `docs/HANDOFF.md` §3: judges get the Android APK. If a later phase wants
  an iOS run, install the simulator runtime from Xcode and `brew install cocoapods` (or
  `sudo gem install cocoapods`) — neither was done in H0.
- Chrome was already installed, so no `brew install --cask google-chrome` was needed and **no
  password was ever requested**. Nothing in H0 used sudo.

**Git**
- `.git/hooks/post-commit` is installed exactly as `docs/HANDOFF.md` §2 specifies (auto-`git push
  origin main` after every commit on `main`), mode `755`.
- `git config user.name` = `Anushka Gupta`, `user.email` =
  `90548501+CrossAnushka@users.noreply.github.com`; remote `origin` =
  `https://github.com/Shreyansh303/team_mausam_sih_2026.git`. HTTPS push authenticates through the
  existing macOS credential helper — no token had to be entered. `gh` is **not** installed.

**Quick commands — macOS translation of `CLAUDE.md` §Quick commands**
```bash
# backend (venv python is bin/python, NOT Scripts/python)
cd backend && .venv/bin/python -m pytest -q                                  # 300 passed, ~10 s
cd backend && .venv/bin/python -m uvicorn app.main:app --reload --port 8000  # run_in_background!
curl -s http://127.0.0.1:8000/api/v1/health                                  # {"status":"ok",...}
pkill -f "uvicorn app.main:app"                                              # instead of taskkill

# app — absolute flutter path, because an agent shell has no ~/.zshrc
export JAVA_HOME="$HOME/development/jdk-17"; export ANDROID_HOME="$HOME/development/android"
FL=~/development/flutter/bin/flutter
cd app && $FL pub get && $FL analyze && $FL test          # analyze clean, 64 tests
cd app && $FL build web                                   # 1 min 43 s (compile 100.6 s)
cd app && $FL build apk --debug                           # NO TEMP recipe needed on macOS
#   → app/build/app/outputs/flutter-apk/app-debug.apk  (debug, all 3 ABIs, 168 MB)
#   warm run 2 min 59 s (Gradle task 174 s). The FIRST run also pulls ~2.7 GB into ~/.gradle
#   (~7 min) — and needs the two Gradle fixes + the compileSdk fix in the Gradle notes below.
#   Run APK builds with the Bash tool's run_in_background AND dangerouslyDisableSandbox: true.
# serve the web build (see the B2a screenshot recipe below — use 127.0.0.1, never localhost)
cd app/build/web && python3 -m http.server 8080 --bind 127.0.0.1   # run_in_background!

# Android SDK maintenance
yes | ~/development/android/cmdline-tools/latest/bin/sdkmanager \
      --sdk_root="$HOME/development/android" --licenses
```

### B2b — what B2a hands you (2026-09-07)

**All 15 renderer kinds are implemented.** `RendererRegistry.pending` is now an **empty set** and
`implemented` holds every kind docs/02 names. `generic` is still the `default:` arm, so an unknown
kind from a later backend degrades instead of throwing. One file per kind under
`lib/features/home/renderers/`, plus two new shared files:
- `parts.dart` — `StatCell`, `Pill`, `AdviceBullets`, `RendererEmpty`, `KeyValue`. Use these
  rather than inventing a fourth way to draw a chip.
- `charts.dart` — `SeriesLineChart` / `SeriesBarChart` (fl_chart 1.2.0 wrappers over
  `List<SeriesPoint>`), `SeriesMarker`. Both are display-only: `LineTouchData(enabled: false)` and
  `BarTouchData(enabled: false)`, because a card body must never eat the shell's tap gesture.
  fl_chart 1.2.0 notes: `TileLayer` has no `backgroundColor`; `getTitlesWidget` returns a plain
  `Text` (no `SideTitleWidget`, whose `axisSide` argument was replaced upstream).

**Detail pages.** `lib/features/home/detail/card_detail_page.dart` is a full-screen `Scaffold`
pushed by the card shell on tap (`CardDetailPage.show`); B1's `card_detail_sheet.dart` is deleted.
`CardDetailPage.detailBodyFor` switches on `card.renderer` and falls back to the card body, so
every one of the 33 types opens. Convention for a new detail body: a file
`detail/<renderer>_detail.dart` exporting one widget, and the renderer itself takes an
`expanded`/`large` flag rather than being duplicated (gauge, timeline, alert, advice_list,
bar_chart, sea, tides use exactly that; places and radar have their own layouts).

**Still to do in B2b** (unchanged from 07 §B2 minus the renderers): animations, events pipeline,
why-sheet actions, places page, map page, settings, demo sheet, WS client, low-bandwidth, a11y,
l10n, icon/splash. Two smaller ones that touch B2a's files:
- Renderer strings are **English literals** (`'Open map'`, `'Safe for swimming'`, `'Next 24 h'`,
  `'Estimated'`, `'All clear'` …), following B1's existing renderers. B2b's l10n pass should move
  them into the ARBs. The card *content* is already localized by the backend.
- `RadarRenderer`'s "Open map" opens the card's detail page (a bigger `flutter_map` with a frame
  slider). When B2b adds the real `/map` route, point it there instead.

**Data-shape surprises worth knowing**
- `packing_suggestions.places[].items` is **`[]` in `home_traveler.json`** — the group heading has
  to render without rows, otherwise the card shows nothing at all. Same trap for any card whose
  list is empty but whose grouping is the information.
- `docs/02` card 12 `best_workout_window.windows[].label` is a **quality** ("Great"), while cards
  22/28 use `label` as the **window name** ("morning_drop"). `TimelineWindow.parse` switches on
  `card.type` for exactly this reason.
- `tides` publishes **four turning points, not a curve** (docs/02 card 17). `TideCurve.of`
  interpolates a half-cosine between consecutive extremes at 20-minute steps — recorded under
  Deviations, and the card carries its own "Estimated" pill plus the backend `disclaimer`.
- `Fmt.humanize` capitalises **every** word: `morning_drop` → "Morning Drop", not "Morning drop".
- In widget tests, `find.text` does not see `Text.rich` spans — pass `findRichText: true` (and
  remember it matches the **whole** concatenated string, so `textContaining` is usually what you
  want).
- **Two backend i18n gaps show up on live data** (not app bugs, and not visible in the fixtures):
  the nowcast card's subtitle renders as the raw key `hazard.rain`, and the AQI insight detail as
  `pollutant.O3 is the dominant pollutant at — µg/m³` (missing key + missing value). Worth a fix
  on the backend side during B3 integration.

**Screenshots — how `docs/screenshots/b2a_*.png` were made** (extends B1's CDP recipe; the driver
script lives in the agent scratchpad, not the repo, because `scripts/` was out of B2a's scope):
1. `flutter build web`; serve `app/build/web` with `python -m http.server 8080 --bind 127.0.0.1`;
   run the backend on 8000. **Use `http://127.0.0.1:8000` as the app's backend URL, not
   `localhost`** — headless Chrome resolves `localhost` to `::1` first and uvicorn binds IPv4 only,
   which silently drops the app into its bundled-fixture fallback.
2. Skip onboarding by seeding `shared_preferences` **before** the app boots: it is `localStorage`
   under a `flutter.` prefix with `json.encode`d values —
   `flutter.onboarded='true'`, `flutter.language='"en"'`, `flutter.backend_url='"http://127.0.0.1:8000"'`,
   `flutter.personas='["health"]'`, `flutter.home_location='"{\"id\":…,\"lat\":28.61,…}"'`
   (a JSON **string** containing JSON). Navigate once, seed, then navigate again.
3. **Load the page twice after seeding.** On the first load the home request races ahead of the
   guest token and gets a 401, so the app shows "Sample data"; the token is stored by then and the
   second load renders live data.
4. `Input.dispatchMouseEvent` with `type: 'mouseWheel'` scrolls the Flutter canvas — that is how
   the `_scrolled.png` shots reach the gauge/sea cards further down the feed.

### RESUMED — B1 finished 2026-09-07 (the 11:03 IST pause is cleared for B1)
The pause after a1345b2 left B1 unverified. The resumed run did the rest: `flutter analyze`
(clean), `flutter test` (44 passed), `flutter build web`, and both screenshots. B1 is `[x]`.
A3 (backend live alerts + admin + deploy + CI) is the only phase still mid-flight from that pause —
it was running its own uvicorn on port 8000 during this verification, which is how the live-data
screenshot happened.

### B0/B1/B2/B3 — "Unable to establish loopback connection" from Gradle: SOLVED (B1, 2026-09-07 10:30)
Supersedes the earlier orchestrator note that blamed the sandbox's loopback networking.
`dangerouslyDisableSandbox: true` alone does **not** fix it — the build still fails.

Real cause, isolated with a 10-line JDK repro (`Selector.open()` in a bare `java Loop.java`):
JDK 17 builds `Selector`'s internal pipe from an **AF_UNIX socket pair** whose socket file is
created in `java.io.tmpdir` (= `%TEMP%`). On this machine AF_UNIX socket files cannot be created
under `C:\Users\...\AppData\Local\Temp` — `UnixDomainSockets.connect0` returns
`SocketException: Invalid argument: connect`, which `PipeImpl` rethrows as the misleading
`java.io.IOException: Unable to establish loopback connection`. Plain TCP loopback works fine, which
is why the earlier diagnosis looked plausible. Same `java Loop.java` with `TEMP=D:\sdk\tmp` prints
`selector OK / pipe OK / loopback socket OK`.

**Recipe for any Gradle / APK / `flutter run -d android` command from an agent shell:**
```bash
TEMP='D:\sdk\tmp' TMP='D:\sdk\tmp' D:/sdk/flutter/bin/flutter.bat build apk --debug
```
(keep `dangerouslyDisableSandbox: true` as well; harmless and avoids other surprises).
`flutter build web`, `analyze`, `test`, `pub get` need none of this. **A normal user terminal is
unaffected** — `%TEMP%` there is the real user temp and Gradle just works. `app/android/gradle.properties`
is untouched Flutter defaults and must stay that way. Documented in `docs/SETUP_WINDOWS.md` §7.9 and
`CLAUDE.md` §8.

### A2 (engine + /home) — what A1 hands you
**Get a Snapshot:**
```python
from app.services.snapshot import get_snapshot          # cached 5 min per (lat2dp, lon2dp, scenario)
snap = await get_snapshot(lat, lon, scenario="live", now=None, admin_warnings=None)
```
`now` (demo clock) or `admin_warnings` bypass the cache automatically. `build_snapshot()` is the
uncached variant. It raises `app.core.errors.NoDataError` (503) when Open-Meteo is down.

**Module map** (all under `backend/app/`):
`config.py` · `state.py` (global `demo_state.scenario` / `.now_override`, A3 drives it) ·
`core/{cache,timeutil,geo,i18n,errors}.py` · `providers/{base,open_meteo,bigdatacloud,rainviewer,imd,cpcb,tomtom,scenarios}.py` ·
`services/{snapshot,locations,aqi_cpcb,comfort,marine,visibility,workout,school_commute,commute,frost,packing,planting,tides,pollen,nowcast,flight_risk,warnings,util}.py` ·
`api/{health,locations,weather}.py` · `schemas/{location,warning,snapshot}.py`.
Add `core/db.py`, `core/security.py`, `models/`, `engine/`, `api/{auth,me,places,home,events}.py`.

**Card data → snapshot keys.** Most `data` blocks in 02 are already computed:

| card | source |
|---|---|
| current_conditions / hourly_forecast / daily_forecast / extended_forecast | `snap.current`, `snap.hourly` (48 h), `snap.daily` (16 d) |
| aqi | `snap.air_quality` (CPCB scale, `hourly[24]`) |
| pollen · tides · traffic | `snap.pollen` · `snap.tides` · `snap.traffic` — all `source: "estimated"` |
| warnings · nowcast | `snap.warnings` (merged + filtered + severity-sorted) · `snap.nowcast` |
| sea_conditions / water_temp | `snap.derived["sea"]` (present only when `snap.marine`) |
| comfort_index · heat_alert · humidity · uv_index · wind · sun_times | `derived["comfort"|"heat"|"humidity"|"uv"|"wind"|"sun"]` |
| best_workout_window · school_commute · commute_conditions | `derived["workout"|"school_commute"|"commute"]` |
| frost_alert · soil_moisture · rainfall_outlook · planting_guidance | `derived["frost"|"soil"|"rainfall_outlook"|"planting"]` |
| visibility · storm_fog_alert · rain_alert · travel_alerts · packing_suggestions | `derived["visibility"|"storm_fog"|"rain"|"flight_risk"|"packing"]` |

Still to build in A2: `radar` (call `/weather/radar`), `saved_places` (fan out snapshots),
`rain_probability` (needs `event_date`), `health_advisory` (compose from aqi/uv/humidity/heat/pollen).
Every derived block also carries a `urgency` float computed per the 02 rules — use it or override it.

**Gotchas found in A1**
- Open-Meteo's CAMS **pollen fields are `null` for every Indian coordinate** (confirmed in
  `tests/fixtures/air_*.json`; London returns real values). The monthly estimator is the normal
  path — always show the "Estimated" chip.
- Open-Meteo **visibility is metres** (converted to km in `normalize_forecast`) and **CO is µg/m³**
  (converted to mg/m³ for CPCB). `daylight_duration` seconds → `daylight_minutes`.
- Marine returns **HTTP 200 with `wave_height: null`** inland (not 400 as 05 assumed) — both cases
  are handled and map to `marine: null`, `tides: null`, no `derived["sea"]`.
- IMD returns `401 "Your IP/Domain <ip> needs to be whitelisted"`. `providers/imd.py` marks itself
  unavailable for 10 min after the first 401 and returns `None`. `/health` shows the status.
- `derived["storm_fog"]` is `None` when there is no hazard — gate the card on it.
- All times are ISO-8601 with the **location's** offset. Use `core.timeutil.iso/parse_any/tz_for`;
  `tzdata` is a pinned dependency because Windows has no system tz database.
- `zoneinfo` + `cachetools` + `respx` are pinned in `requirements.txt` / `requirements-dev.txt`.

**Tests**: `backend/.venv/Scripts/python -m pytest -q` → 210 passed, fully offline. `tests/conftest.py`
replays `tests/fixtures/*.json` through respx and fails on any unmocked host; add new upstreams there.
Re-record with `.venv/Scripts/python scripts/record_fixtures.py` (hits the real APIs).

### A3 (live alerts + admin) — what A2 hands you

**Everything is mounted twice**, at `/api/v1` and at the root (A1's convention) — add your
`admin.router` and `ws.router` to the `routers` tuple in `app/main.py` the same way.

**Where admin warnings plug into `/home`.** `api/home.py` calls
`snapshot_svc.get_snapshot(lat, lon, scenario=..., now=...)`. `build_snapshot` already accepts
`admin_warnings: list[dict] | None` and merges them through `services/warnings.merge()` (filter by
district / state / `radius_km`, drop `valid_to <= now`, sort by severity) — and passing it
**bypasses the snapshot cache**, which is what you want. So A3 needs exactly two edits:
1. load the live admin warnings (new `models/admin_warning.py`, `expires_at > now`) in `get_home`
   and pass them as `admin_warnings=`;
2. nothing else. `snap["warnings"]` flows into `Context.active_warnings`, and from there the
   `warnings` card gate, `urgency_warnings` (yellow 0.5 / orange 0.8 / red 1.0 → pinned at ≥ 0.8),
   `engine/home.banner_for` (banner at orange+) and `context.warning_count` all light up on their
   own. Verified today: `?scenario=thunderstorm` pins the warnings card and sets an orange banner.

**Where `demo_state` plugs in.** `app/state.py` holds `demo_state.scenario` / `.now_override`;
`get_home` already reads both as the fallback under the per-request `?scenario=` / `?now_override=`.
`POST /admin/scenario` and `POST /admin/now-override` only have to write `demo_state` — no engine
change. `GET /home/now` (hidden route) reports the effective clock for the console.

**Where the WS hook belongs.** `api/ws.py` should own the connection registry; the broadcast calls
belong in the **admin router**, right after the DB write, not in the engine (`app/engine/` is pure
and must stay that way):
- `POST /admin/warnings` → persist → `ws.broadcast_warning(w)` (`affects_you` = `warnings.applies_to(w, lat, lon, district, state)`, which already exists);
- `DELETE /admin/warnings/{id}` → `ws.broadcast("warning_cleared", {"id": id})`;
- `POST /admin/scenario` / `/admin/now-override` → `ws.broadcast("scenario_changed"|"now_override", …)`.
Cache note: after any admin write, call `cache.clear_all()` or at least drop the `snapshot` bucket,
otherwise a cached snapshot without the new warning can still be served for up to 5 minutes.

**Regenerate the fixtures** at the end of A3 (`scripts/gen_fixtures.py`) if the payload changes.

### B1/B2 — the fixture contract

`docs/fixtures/` holds 10 files, each one complete `HomeResponse` per docs/04, all Delhi at
`now_override=2026-09-08T07:30:00+05:30` unless noted:

| file | persona | location | scenario |
|---|---|---|---|
| `home_health.json` `home_fitness.json` `home_parent.json` `home_agriculture.json` `home_commuter.json` `home_event_planner.json` | that persona alone | Delhi | `clear_pleasant` |
| `home_beach.json` | beach | Panaji | `clear_pleasant` |
| `home_traveler.json` | traveler | Delhi + 2 saved places (Panaji, Mumbai) | `clear_pleasant` |
| `home_severe.json` | parent | Delhi | `thunderstorm` — orange banner, 4 pinned cards |
| `home_coastal.json` | beach | Panaji | `clear_pleasant` |

Regenerate with `backend/.venv/Scripts/python scripts/gen_fixtures.py` (offline; replays
`backend/tests/fixtures/`). Byte-for-byte reproducible except the random `usr_`/`plc_` ids.

- **30 of the 33 card types appear** across the 10 files. `frost_alert`, `heat_alert` and
  `travel_alerts` do not, because `clear_pleasant`/`thunderstorm` do not trigger their gates.
  To exercise those three renderers against a live backend:
  `?scenario=frost&personas=agriculture` · `?scenario=heatwave&personas=fitness` ·
  `?scenario=dense_fog&personas=traveler` **with at least one saved place** (all three verified).
- **Renderers to register** (`Card.renderer`): `hero, warnings, nowcast, hourly, daily, radar,
  gauge, metric, advice_list, timeline, alert, sea, tides, places, bar_chart`. Fall back to a
  generic renderer on an unknown value rather than throwing — A3 may add cards.
- `Card.actions[].id` is already localized in `label`; `pin` becomes `unpin` when the user pinned
  the card, so render the id you are given.
- `more_cards` is `[]` when `?lite=1`; hourly arrays trim to 12 and radar frames to 3.
- **Any contract change must edit `docs/04_API_CONTRACT.md` in the same commit** (CLAUDE.md §1)
  and be recorded under Deviations here.

**Auth for the app:** `POST /api/v1/auth/guest` → `{token, user}`; send
`Authorization: Bearer <token>` on `/home`, `/me*`, `/events`. OTP demo code is `123456`; pass the
old guest token in `X-Guest-Token` on `/auth/verify-otp` to merge places/prefs/engagement.

### B2 (full card system, map, places, WS, events) — what B1 hands you

**Package versions actually resolved** (`app/pubspec.lock`, Flutter 3.47.2 / Dart 3.13):
`flutter_riverpod 3.4.3` · `go_router 18.0.1` · `dio 5.11.1` · `shared_preferences 2.5.5` ·
`path_provider 2.1.6` · `connectivity_plus 7.3.1` · `geolocator 14.0.3` ·
`permission_handler 13.0.2` · `flutter_map 8.3.2` + `latlong2 0.10.1` · `fl_chart 1.2.0` ·
`intl 0.20.3` · `web_socket_channel 3.0.3` · `share_plus 13.3.0` · `url_launcher 6.3.2` ·
`flutter_animate 4.5.2` · `package_info_plus 10.2.1` · `cached_network_image 4.0.0` ·
`flutter_lints 6.0.0`. `flutter pub get` warns that 8 transitive packages have newer versions
pinned back by constraints — expected, not a problem. **Riverpod is v3**: `Notifier`/`build()`,
`ref.watch` inside `build`, no `StateNotifier`; no codegen anywhere (no build_runner), and l10n
comes from `flutter gen-l10n` driven by `app/l10n.yaml` into `lib/l10n/gen/`.

**Animation decision:** `flutter_animate` only (used in `home_page.dart` and
`warning_banner.dart`). `animated_reorderable_list` / `great_list_view` were *not* added — see
Deviations. If you want the WS re-rank animation from 06 §Animation, try
`animated_reorderable_list` first (`flutter pub add`, then `flutter analyze`); the documented
fallback is a keyed list + `flutter_animate` entrance + a highlight flash + the SnackBar.

**How to run the app.**
```bash
# web (fastest loop; no Android toolchain needed)
D:/sdk/flutter/bin/flutter.bat build web            # or: flutter run -d chrome
cd app/build/web && C:/Python313/python.exe -m http.server 8080 --bind 127.0.0.1   # run_in_background!
# device / emulator — needs the TEMP recipe from CLAUDE.md §8
TEMP='D:\sdk\tmp' TMP='D:\sdk\tmp' D:/sdk/flutter/bin/flutter.bat run -d <device>
```
The backend origin defaults to `http://localhost:8000` on web/iOS and **`http://10.0.2.2:8000`** on
Android (the emulator's host alias); Settings overrides it, so on a real handset put the LAN IP
there. `AppConfig` appends `/api/v1` itself — the stored URL is the origin only.

**Driving the web build headlessly** (how `docs/screenshots/*.png` were made, and how B2/C1 can
script per-persona screenshots): Flutter web paints to a canvas, so the agent browser tool cannot
click anything — there is no DOM to find, and the semantics tree only materialises after the
"Enable accessibility" placeholder is clicked *and* a frame is rendered (it is not, while the pane
is hidden). What works: launch Chrome headless with `--remote-debugging-port=9222
--user-data-dir=D:\sdk\tmp\cdp-profile` and drive it over CDP from a ~60-line Node script (Node 22
has a global `WebSocket`, so **no npm install**) — `Emulation.setDeviceMetricsOverride`
(390×844@2 for a phone-shaped shot), `Emulation.setEmulatedMedia` `prefers-color-scheme`,
`Input.dispatchMouseEvent` for taps at CSS coordinates, `Page.captureScreenshot` to a PNG file.
Two traps: CDP emulation overrides are dropped when the WebSocket session detaches, so set metrics
+ media and take the screenshot **in one run**; and Flutter only picks up a changed
`deviceScaleFactor` on reload, so navigate after setting metrics or half the canvas stays blank.

**Where things live** (all under `app/lib/`):
`core/{config,theme,router,icons,formatters,connectivity}.dart` ·
`data/{api_client,cache/json_file_cache}.dart` · `data/models/{home_response,card,warning,user,
location,json}.dart` · `data/repositories/{auth,home,locations,events,settings}_repo.dart` ·
`features/onboarding/{language,persona,location}_page.dart` + `onboarding_scaffold.dart` ·
`features/home/{home_page,providers}.dart` + `widgets/` (card shell, persona chips, warning banner,
freshness chip, offline banner, why sheet, reason chips, card detail sheet) · `features/settings/`.
**The renderer registry is `lib/features/home/renderers/registry.dart`** — a `switch` on
`card.renderer` in `RendererRegistry._dispatch`, plus two documented sets, `implemented` and
`pending`, that `test/fixtures_test.dart` asserts against. Add a renderer = new file in
`renderers/`, one `case`, and move its name from `pending` to `implemented`.

**Renderers that exist:** `hero`, `warnings`, `hourly`, `daily`, `metric`.
**Everything else falls back to `generic`** (a labelled key/value grid): `nowcast`, `radar`,
`gauge`, `advice_list`, `timeline`, `alert`, `sea`, `tides`, `places`, `bar_chart`. That fallback
is load-bearing and looks acceptable but generic in the screenshots — `School run` (timeline) and
`Heat alert` (alert) render as "Windows: 2 items / Overall Verdict: caution" key/value pairs.
Ten renderers is most of B2's card work.

**Tests** — `cd app && D:/sdk/flutter/bin/flutter.bat test` → **44 passed** in ~10 s:
- `test/fixtures_test.dart` is the contract test: it walks **all ten `docs/fixtures/*.json`**
  (`../docs/fixtures`, relative to the package root), parses each with the models, checks the 04
  enums / urgency bands / `estimated` labelling / banner→warning linkage, round-trips `toJson`,
  asserts the corpus still covers 30 card types, and **pumps every card of every payload through
  the registry** in English plus one of each type in Hindi. Keep it green: it is what stops a new
  renderer from crashing on a payload nobody looked at.
- `test/models_test.dart` pins the bundled fixture, `renderers_test.dart` the five real renderers,
  `home_page_test.dart` the whole home with a fake repo (note `useTallViewport` — the home is a
  lazy `CustomScrollView`, so a short test surface silently builds only the first two cards).

**Surprises worth knowing**
- The app **already renders live A3 backend data** end to end: guest token → `PUT /me/profile` →
  `GET /home`, verified against the running uvicorn on 8000 (`docs/screenshots/b1_home.png` is
  live 32 °C / AQI 306 Delhi data, and it contains a `heat_alert` card — one of the three types no
  fixture has). No contract mismatches surfaced.
- Onboarding must survive a dead backend: `_finish()` in `location_page.dart` calls
  `ensureGuestToken()` + `updateProfile()`, and both swallow `ApiException` and return `null`, so
  the user still reaches the home. Keep that property when you add `/me/places`.
- With the backend down the home stacks **two** banners — the red "Could not refresh. Showing saved
  data." and the grey "Sample data — the backend at … is not reachable." (see
  `b1_home_offline.png`). Harmless but redundant, and the red one's wording is wrong for the
  fixture case. Worth collapsing in B2.
- The popular-cities list on the location page falls back to `LocationsRepo.fallbackCities`
  (18 hard-coded cities) when `/locations/popular` is unreachable, so onboarding works offline.
- Devanagari renders fine in the web build (no bundled font needed); the first frame after a cold
  load can show tofu for ~1 s while the system font resolves.
- Cache keys are `home_<lat2dp>_<lon2dp>_<personas>_<lang>`, written by `JsonFileCache`
  (path_provider on device, `localStorage` under a `flutter.` prefix on web).

### B2/B3 — what A3 hands you (live alerts, admin console, deploy)

**Run the backend for the app** (nothing else needed — no key, no Docker):
```powershell
cd backend
.venv\Scripts\python -m uvicorn app.main:app --reload --port 8000
```
`GET /health` should answer `{"status":"ok",…}`. Every router is mounted twice, at `/api/v1` and
at the root, so both `/api/v1/home` and `/home` work. Backend URL for the app:
`http://localhost:8000` (Flutter web/desktop) · `http://10.0.2.2:8000` (Android emulator) ·
`http://<LAN-IP>:8000` (real phone) · `https://<service>.onrender.com` (Render). `CORS_ORIGINS=*`
is the default, so Flutter web needs no proxy.

**WebSocket — exact URL and message samples.** Derive it from the backend base
(`http`→`ws`, `https`→`wss`) and append `/ws/alerts`:
```
ws://localhost:8000/ws/alerts?token=<jwt>&lat=28.61&lon=77.21
```
`token` is the guest/OTP JWT (the same one `/home` uses). While `DEMO_MODE=1` it may be omitted;
an **invalid** token is closed with code 1008 before `hello`, so treat 1008 as "re-authenticate,
do not retry with the same token". Real frames captured from the running server:
```json
{"type":"hello","server_time":"2026-09-07T15:51:47+05:30","scenario":"live"}
{"type":"ping"}
{"type":"warning_issued","warning":{"id":"wrn_7a4734a416","severity":"orange","hazard":"thunderstorm","title":"Thunderstorm warning — Delhi","description":"Thunderstorm with lightning and gusty winds (50–60 km/h) likely over Delhi in the next 3 hours.","issued_at":"2026-09-07T15:55:48+05:30","valid_from":"2026-09-07T15:55:48+05:30","valid_to":"2026-09-07T17:55:48+05:30","district":"New Delhi","state":"Delhi","lat":28.61,"lon":77.21,"radius_km":75,"source":"admin","color_hex":"#F28C28"},"affects_you":true}
{"type":"warning_cleared","id":"wrn_7a4734a416"}
{"type":"scenario_changed","scenario":"heatwave"}
{"type":"now_override","now":"2026-09-08T07:30:00+05:30"}
{"type":"now_override","now":null}
```
Client → server, the only two frames the server reads:
`{"type":"pong"}` (answer every `ping`, one every 30 s — the server drops a socket whose send
fails) and `{"type":"location","lat":19.08,"lon":72.88}` when the user changes location. There is
**no ack** for `location`; the next `warning_issued` simply carries the recomputed `affects_you`.
The same warning goes to every client — only `affects_you` differs (verified: Delhi client `true`,
Mumbai client `false` for the sample above). Re-fetch `/home` on `warning_issued && affects_you`,
`scenario_changed` and `now_override`; ignore unknown `type`s so a later server can add one.

**Admin console**: `http://localhost:8000/admin/console` (no key in the URL; the page asks for
`ADMIN_KEY`, default `mausam-admin`, and keeps it plus the backend base in `localStorage`).
Panels: scenario buttons · demo clock · push-warning form with the five 05 presets ·
active-warnings table with delete · connected-client count (5 s refresh) + a live WS feed ·
reset-user. Everything it does is a plain REST call, e.g.
`POST /api/v1/admin/warnings` with `X-Admin-Key` and
`{"severity","hazard","title","description","district","state","lat","lon","radius_km","ttl_minutes"}`.

**The demo to wire up in B2/B3**: console → preset *Orange thunderstorm — Delhi* → **Push
warning** → the app receives `warning_issued` with `affects_you: true`, re-fetches `/home` and
animates: the `warnings` card appears in `pinned` with `urgency 0.8`, `banner` is set to the
orange warning and `context.warning_count` becomes 1. Delete the row (or wait out
`ttl_minutes`, default 120) and everything reverts. Measured on this machine: `/home` warm is
**10 ms**, and **27 ms** on the first request after a push.

**Contract clarifications made in A3** (docs/04 edited in the same commit, details under
Deviations): `/admin/console` takes no header; `POST /admin/scenario` and `/admin/now-override`
return the `GET /admin/state` object; a pushed warning must be targeted by `lat`+`lon`, `district`
or `state`; a `now` without an offset is read as IST; `{"now": null}` clears the demo clock.
Nothing in `HomeResponse`, `Card` or `Warning` changed — `docs/fixtures/*.json` are still valid
byte for byte.

**Deploy** (B3's README section can point at this): `infra/render.yaml` is a Render blueprint
(free plan, `rootDir: backend`, `uvicorn … --port $PORT`, health check `/health`, `ADMIN_KEY` and
`JWT_SECRET` generated). Free-plan gotchas for a live demo: the instance sleeps after ~15 min
(hit `/health` a minute before presenting), the disk is ephemeral (guest users and pushed warnings
reset on deploy), and there is exactly one instance — which is what the in-process WS registry
needs. `infra/docker-compose.yml` is the local Docker path (written, **not run** — no Docker on
this machine). `.github/workflows/backend.yml` runs the offline pytest suite on every push/PR
touching `backend/`.
