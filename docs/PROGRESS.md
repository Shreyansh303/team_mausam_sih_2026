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
- [ ] B2b animations · events · why-sheet actions · places · map · settings · demo sheet · WS client · low-bandwidth · a11y · l10n · icon/splash
- [ ] B3 integration + APK + CI
- [ ] C1 e2e QA
- [ ] C2 docs + pitch
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
- [x] all renderers + detail pages (B2a) · [ ] animations · events pipeline · why-sheet actions
- [ ] places page · map page (radar + warnings) · settings complete · demo sheet · WS client · low-bandwidth · a11y
- [ ] l10n en/hi complete · icon/splash · screenshots per persona

## B3 checklist
- [ ] live backend integration, contract mismatches fixed · WS reorder verified in web build
- [ ] release APK built · .github/workflows/flutter.yml · README app section

## C1 / C2
- [ ] QA_REPORT.md with every demo step verified
- [ ] README final · 08_PITCH.md · pptx

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

## Notes for next phase

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
