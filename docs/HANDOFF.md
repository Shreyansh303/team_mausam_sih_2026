# HANDOFF — picking this project up cold

This repo is built so that a new owner on a fresh machine, or the same owner in a fresh session,
can continue without asking anyone anything. The plan is in `docs/` (normative), the rules in
`CLAUDE.md`, and the live state in `docs/PROGRESS.md`. Nothing important lives outside git except
the local toolchain.

Read this file, then `docs/PROGRESS.md` (the checkboxes and the "Notes for next phase" sections are
the truth), then `docs/07_PHASES.md`.

## 1. Where things stand (handed off 2026-09-09, commit `7dea043`, tree clean, origin in sync)

**Every planned phase is done.** A1–A3 (backend), B0–B3 (app), C1 (QA), C2 (docs/pitch/deck) and
the stretch phases S1, S2, S3 are all `[x]` in `docs/PROGRESS.md`. The only unchecked box is the
stretch line that stands for **S4 (more languages)**. The prototype runs, the demo has been walked
end to end, and everything below is optional or external.

**Backend (A1–A3).** FastAPI on Python 3.13, fully offline-testable. Providers with an
IMD → Open-Meteo → estimated fallback chain, 33 card builders, the personalization engine from
`docs/03` (scoring, context, explainability, learning), `/home` with every parameter in the
contract, guest/OTP auth, saved places, the events pipeline, en/hi catalogs, the admin console,
`/ws/alerts`, Docker/Render config and CI. Evidence, re-run for this handoff:
`cd backend && .venv/bin/python -m pytest -q` → **386 passed, 1 warning in 23.98 s**, with no
network and no keys.

**App (B0–B3).** Flutter 3.47.2, package `mausam_app`. Onboarding, home shell, all **15 renderers**
across the **33 card types** plus a full-screen detail page each, the WebSocket client, the batched
events pipeline, why-sheet actions, places, map, settings, demo sheet, low-bandwidth mode, the
accessibility pass, en/hi complete with mr/ta/bn falling back per key, icon and splash. Evidence,
re-run for this handoff: `flutter analyze` → **No issues found! (4.0 s)** ·
`flutter test` → **124 passed** · `flutter build web` verified in S2 ·
`app/build/app/outputs/flutter-apk/app-release.apk` is on disk at **62 496 956 B (62.5 MB)**,
3 ABIs, minSdk 24 / targetSdk 36, **debug-signed** (no `app/android/key.properties` exists, so the
release build falls back to the debug key and says so at build time). That file is 200 B larger
than the 62 496 756 B B3 recorded because the release-signing work rebuilt it on 2026-09-09.

**QA and pitch (C1, C2).** `docs/QA_REPORT.md` is the evidence file: verdict **PASS**, all ten
steps of the judge demo script walked against a live backend in the real web build, plus all ten
scenarios, `lite=1`, offline (cache and bundled), Hindi, dismiss-learning, and a static
release-APK check. Nine defects were found there and fixed, each with a regression test.
**40 screenshots** at `docs/screenshots/c1_*.png` (63 in the directory in total).
`docs/08_PITCH.md` carries the pitch content with every number traced to where it was measured, and
`docs/TeamMausam_SIH2026_PS26076.pptx` is the 6-slide deck.

**Stretch (S1, S2, S3, and the small S-app items).** S1 is a bounded per-user logistic-regression
ranker behind `ENGINE_ML=1` (v1 stays the default and the floor; no new dependency). S2 is the
Android home-screen widget — built and unit-tested, **never seen on a device**. S3 is the push
backend: transport abstraction, device registry (`POST /me/devices`, `DELETE /me/devices/{token}`,
`GET /admin/devices`), `docs/09_PUSH_NOTIFICATIONS.md`, and every admin broadcast wired to it; the
app half is deliberately not written. Two smaller items also landed: release builds sign from
`app/android/key.properties` when that file exists (`b15645b`), and hides survive a reinstall via a
card-prefs seed at start-up (`217030e`).

**Machine and CI.** H0 moved the project from the original Windows box to a MacBook Air (Apple M1);
`docs/PROGRESS.md` → "Notes for next phase → H0 — this Mac" is the full record. Both GitHub
workflows are green on their most recent runs for the paths they watch:
`flutter` at `90f83c6` → **success** (run 34357713681) and `backend` at `b315bf3` → **success**
(run 34357060720). `7dea043` itself is a docs-only commit and triggers neither workflow.

### What is open

Nothing is blocked and nothing is broken. These are the real remaining items.

1. **File the IMD whitelisting request.** Every `https://mausam.imd.gov.in/api/*` endpoint answers
   `401` from a host IMD has not approved, so the prototype runs on Open-Meteo and says so.
   `README.md` §"IMD integration path" has the exact contents of the letter (static IP or domain,
   organisation and purpose, the four endpoints used, the request rate, a contact) and asks for the
   **district id list**, which IMD does not publish — `backend/app/data/imd_ids.json` has station
   ids for 35 cities and `district_id: null` for every one of them. No code depends on this; file
   it first only because the reply takes weeks.
2. **The device smoke test.** *Nothing in this repo has ever run on a handset* — there is no phone
   and no emulator image on the build machine. Install `app-release.apk` on any Android device and
   check the paths the web build cannot exercise: first launch, the location-permission prompt, GPS
   onboarding, background event flushing (C2 notes), then the widget's eight-point checklist in
   `docs/PROGRESS.md` → "Notes for next phase → S2 — notes" (add it from the picker, first content,
   severity colour, the three deep-link paths, forcing the WorkManager job, stale/offline, Hindi
   chrome vs content, dark mode). Until this is done the honest phrasing everywhere stays
   "verified in the web build plus a static APK check", never "tested on a handset".
3. **Send `meta.urgency` on `POST /events`** (S1 notes, one line in the app). The field is already
   accepted, already documented as optional in `docs/04`, and already a feature of the v2 ranker —
   but today every event lands in `urg:unknown`, so the urgency bands train to nothing. The why
   sheet needs no change to display the `learning:up` / `learning:down` reason; a distinct
   icon/colour for that reason family is the obvious follow-up.
4. **Deploy the backend.** `infra/render.yaml` is a Render blueprint (free plan, `rootDir: backend`,
   `uvicorn … --port $PORT`, health check `/health`, `ADMIN_KEY` and `JWT_SECRET` generated).
   Free-plan gotchas recorded in the A3 notes: the instance **sleeps after ~15 min** (hit `/health`
   a minute before presenting), the disk is **ephemeral** (guest users and pushed warnings reset on
   deploy), and there is exactly **one** instance — which is what the in-process WebSocket registry
   needs. `infra/docker-compose.yml` is the local Docker path; it was written but never run.
5. **The S3 app wiring.** Needs a **Firebase project** and a `google-services.json` in
   `app/android/app/` (gitignore it first; it must never be committed). Then `firebase_core` +
   `firebase_messaging` + `flutter_local_notifications`, `POST_NOTIFICATIONS` on Android 13+,
   `POST /me/devices` on first launch / token refresh / language or location change, and
   `DELETE /me/devices/{token}` on sign-out. Messages are **data-only** on purpose — the app builds
   the notification in the user's language. The registration half can be built and tested with no
   Firebase account at all: the transport stays `noop` without `FCM_*` env vars and logs each
   broadcast. Read `docs/09_PUSH_NOTIFICATIONS.md` first, §9 especially — topics, an IMD-driven
   trigger, TTL and quiet hours are what still separate this from a real alerting system.
6. **A release keystore**, only if this is ever published. The build already reads
   `app/android/key.properties` and falls back to the debug key with a build-time notice when the
   file is absent, so CI and a fresh clone need no secrets. Create the key **outside the repo**:
   ```bash
   keytool -genkey -v -keystore ~/mausam-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mausam
   # app/android/key.properties — storeFile absolute, or relative to app/android/app/
   printf 'storeFile=%s\nstorePassword=CHANGEME\nkeyAlias=mausam\nkeyPassword=CHANGEME\n' ~/mausam-release.jks > app/android/key.properties
   ```
   Both files are gitignored. A `key.properties` missing a field fails the build rather than signing
   half-configured. Verify with `apksigner verify --print-certs`.
7. **S4 — finish `mr` / `ta` / `bn`.** This is translation work, not engineering: the pipeline, the
   per-key fallback and the parity tests (`backend/tests/test_i18n.py`, `app/test/l10n_test.dart`)
   all exist. Counts re-derived at this commit:

   | | en / hi | mr, ta, bn each | missing per partial locale |
   |---|---|---|---|
   | backend catalogs (`backend/app/data/i18n/*.json`) | **606** | **54** | 552 |
   | app messages (`app/lib/l10n/*.arb`) | **353** | **69** | 284 |

   ```bash
   # backend catalogs are flat dicts; app ARBs mix messages with "@"-prefixed metadata
   python3 -c 'import json,glob;[print(f, len(json.load(open(f)))) for f in sorted(glob.glob("backend/app/data/i18n/*.json"))]'
   python3 -c 'import json,glob;[print(f, len([k for k in json.load(open(f)) if not k.startswith("@")])) for f in sorted(glob.glob("app/lib/l10n/*.arb"))]'
   ```
   Do **not** count ARB keys with `grep -c '"'` — it counts the `@`-metadata blocks and over-reports
   the partials. Note while you are there: `README.md`, `docs/QA_REPORT.md` and `docs/08_PITCH.md`
   all say **604** backend keys, which was right when C2 wrote it; S1 added two reason keys and the
   number is now **606**. The app total (353) is unchanged. Keep claiming "5 languages offered,
   2 complete".

**Recommended order:** 1 (paperwork, start the clock) → 2 (cheapest, and it is the one claim the
repo cannot currently make) → 3 (one line) → 4 (gives judges a URL) → 5 (the one that matters for a
real deployment) → 6 (only for a store build) → 7 (needs native speakers).

## 2. How the work is run (the protocol)

- **The orchestrator session never writes code.** It reads `docs/PROGRESS.md`, spawns **one
  implementation agent per phase**, reads that agent's short report, verifies with a quick command
  and moves on. Run the orchestrator on a **strong model** and the implementation agents on a
  **cheaper capable model**: the orchestrator's turns stay tiny and the volume lands on the cheaper
  budget.
- **Parallelism.** A backend phase and an app phase touch different directories and may run side by
  side — `A3 ∥ B2` is the pair that actually worked here. **Never two agents in one tree.** Two
  agents may safely share `docs/PROGRESS.md` and `README.md` provided each one `git add`s only its
  own paths **by name** (never `git add -A` from the repo root); that is what kept the parallel runs
  from clobbering each other.
- **Checkpoints.** Agents commit per milestone and push every commit. **No attribution lines of any
  kind** in a commit message — no co-author trailers, no "generated with", no tool or product names.
  The author is the repo's configured git user and nothing else. Install the local auto-push hook
  once per clone:
  ```bash
  printf '#!/bin/sh\n[ "$(git rev-parse --abbrev-ref HEAD)" = main ] && git push origin main >/dev/null 2>&1 || true\n' > .git/hooks/post-commit && chmod +x .git/hooks/post-commit
  ```
- **Pause and resume — this worked three times** (A2, B1/A3, C1) and is the single most useful
  thing in this protocol. At ~95 % of the session limit, or on the human's word: stop every agent,
  commit and push **whatever is on disk** as an explicit WIP checkpoint (`phase(C1): WIP checkpoint
  — …`), mark the in-progress phases `[~]` in `docs/PROGRESS.md`, and stop. To resume, re-spawn with
  the "Resume phase" prompt in `docs/PROGRESS.md` §Recovery. **The resumer re-runs the phase's
  verification gates first and trusts the tree over the checklist** — an interrupted agent loses its
  conversation, not its files, and the checklist is always the stalest artefact in the repo.
- **Agents leave servers running when they are killed.** After any pause, check and clean up:
  ```bash
  pgrep -fl "uvicorn|http.server"     # then: pkill -f "uvicorn app.main:app"; pkill -f "http.server"
  ```
  Long-running servers must always be started in the background — a foreground server never exits,
  hits the tool timeout and is reported as a failure even though it is running fine.
- **The safety timer.** The orchestrator cannot see the usage meter; the human pings a percentage.
  A one-shot timer **80–90 minutes** after starting two parallel agents is the net that has actually
  caught the limit. Consider turning off any "extra usage" setting on the plan so hitting 100 % can
  never bill credits.
- **Watch the disk.** An APK build once left this volume at **433 MB free** (2.4 GB of Gradle
  intermediates plus a 176 MB debug APK plus the 62 MB release APK). Check `df -h /` before any
  Gradle work, and delete `app/build/app/intermediates` and the debug APK afterwards.
  **`flutter clean` deletes the release APK** — never run it casually; if it is run, the APK has to
  be rebuilt before anyone can claim it exists.

## 3. Machine setup for a new owner

**macOS is the primary machine now.** Exact paths and versions verified in H0 on a MacBook Air
(Apple M1, arm64), macOS 26.6.2:

| tool | path | version |
|---|---|---|
| venv python | `backend/.venv/bin/python` | 3.13.2 |
| flutter | `~/development/flutter/bin/flutter` | **3.47.2 stable** |
| JDK 17 (`JAVA_HOME`) | `~/development/jdk-17` | Temurin 17.0.20.1+1 |
| Android SDK (`ANDROID_HOME`) | `~/development/android` | platforms 35 · 36 · 37.0 · **37** (the clone, see §4) · build-tools 35.0.0 + 36.0.0 |
| sdkmanager | `~/development/android/cmdline-tools/latest/bin/sdkmanager` | **cmdline-tools 21.0** |

- **Backend (any OS):** Python 3.13 → `python -m venv backend/.venv` → install
  `backend/requirements.txt` and `requirements-dev.txt` → `pytest -q` green →
  `uvicorn app.main:app --port 8000`. No API keys. `backend/README.md` has the env table.
- **An agent shell does not source `~/.zshrc`** — always use the absolute paths above, or re-export
  inline:
  ```bash
  export JAVA_HOME="$HOME/development/jdk-17"; export ANDROID_HOME="$HOME/development/android"
  export PATH="$HOME/development/flutter/bin:$JAVA_HOME/bin:$PATH"
  ```
- **Do not "upgrade" `cmdline-tools/latest`.** Releases after 21.0 dropped the classic `sdkmanager`
  for a new `android` CLI behind a shim that **hangs forever** on a non-interactive install and
  prints warning lines before `--version`, which breaks `flutter doctor` and every scripted SDK
  install. Keep the pinned 21.0 zip
  (`commandlinetools-mac-15641748_latest.zip`) unzipped as `cmdline-tools/latest`.
- **`app/android` pins compileSdk 37, AGP 9.1.0, Kotlin 2.4.0, Gradle 9.3.1.** `android-36` and
  `build-tools;36.0.0` are what actually matter; a 35-only SDK will not build this app.
- **Xcode is optional.** `flutter doctor` flags it here (no simulator runtime, no CocoaPods) and
  that is allowed — judges get the Android APK. iOS needs macOS + Xcode + CocoaPods and is not in
  CI.
- **Windows is the documented alternative:** `scripts/setup_flutter_windows.ps1` (user-space install
  to `D:\sdk`) then `docs/SETUP_WINDOWS.md`. Path swaps from the Windows-first docs: the venv
  interpreter is `backend\.venv\Scripts\python.exe`, and `taskkill /F /PID` replaces `pkill`. The
  `TEMP=D:\sdk\tmp` Gradle recipe in `CLAUDE.md` §8 and `scripts/flutter_env.*` are **Windows-only**
  and do not apply on macOS — the loopback bug they work around does not reproduce here.

## 4. Phase H0 — fresh-machine bootstrap (run first on a new computer)

Nothing but git is assumed. An implementation agent does all of it; the human only opens a session
in the cloned folder. Deliverable: both verification gates green, then `[x] H0` in
`docs/PROGRESS.md`. This phase worked as written — keep it.

1. Backend: install Python 3.13 if missing (user-space is fine) → `python -m venv backend/.venv` →
   pip install `backend/requirements.txt` + `requirements-dev.txt` → gate: `pytest -q` in
   `backend/` green (offline, no keys) → start uvicorn in the background, curl `/api/v1/health`,
   stop it.
2. App on **macOS** (user-space, no sudo): (a) Flutter stable — the macOS zip for the right CPU from
   `https://docs.flutter.dev/install/archive`, unzipped to `~/development/flutter`, `bin` on PATH in
   `~/.zshrc`; (b) JDK 17 — the Adoptium tar.gz extracted to `~/development/jdk-17`, `JAVA_HOME`
   set; (c) Android SDK — **cmdline-tools 21.0** (see §3) into
   `~/development/android/cmdline-tools/latest`, `ANDROID_HOME` set, then
   `yes | sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "platforms;android-36" "build-tools;36.0.0"`
   and `yes | sdkmanager --sdk_root=$ANDROID_HOME --licenses`, then
   `flutter config --android-sdk $ANDROID_HOME`; (d) Chrome for `flutter run -d chrome`.
   Windows alternative: `scripts/setup_flutter_windows.ps1` + `docs/SETUP_WINDOWS.md`.
   Gate: `flutter doctor` shows Flutter + Android toolchain + Chrome OK (Xcode may be `[!]`);
   `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build web` all pass in `app/`;
   `flutter build apk --debug` succeeds (the first Gradle run pulls ~2.7 GB — background it and
   poll). No `TEMP` recipe is needed on macOS.
3. Install the auto-push hook from §2; confirm `git config user.name` / `user.email` are the new
   owner's.
4. Record machine specifics (OS, absolute paths, versions) in `docs/PROGRESS.md` under
   "Notes for next phase".

**The three Gradle/Android gotchas H0 hit here** (all solved; full detail in the H0 notes):

1. **The Gradle wrapper could not download its own distribution** — one of the four IPs behind
   `release-assets.githubusercontent.com` refuses TCP 443 on this network and the JVM tries only the
   first one. Fix: `curl -fL --retry 5 --retry-all-errors` the `gradle-9.3.1-all.zip` straight into
   the wrapper's cache slot under `~/.gradle/wrapper/dists/`; the installer then skips its own
   download. Redo it if `~/.gradle` is wiped or the wrapper version changes.
2. **`platforms;android-37` no longer exists — only `platforms;android-37.0`**, whose metadata the
   older parser cannot match (`Failed to find target with hash string 'android-37'`). Fix, already
   applied: `platforms/android-37` is an APFS clone of `android-37.0` with `source.properties` and
   `package.xml` patched back to the legacy naming. Both directories are kept.
3. **`permission_handler_android` 14.1.0 requires compileSdk 37**, which failed the AAR-metadata
   check against 36. H0 verified the one-line fix and reverted it as a project change; B2b committed
   it (`0f4eda2`), so `app/android/app/build.gradle.kts` now pins `compileSdk = 37`. AGP warns
   "maximum recommended compile SDK … is 36" and builds anyway.

## 5. Ready-to-paste orchestrator prompt (start of each new session)

```
You are the orchestrator for Team Mausam's SIH 2026 project in this repo. Read CLAUDE.md,
docs/HANDOFF.md, docs/PROGRESS.md and docs/07_PHASES.md. You do not implement anything yourself:
all implementation runs on background agents on a cheaper capable model, so that strong-model usage
stays minimal. If PROGRESS.md does not show "[x] H0" for this machine, first spawn one agent for
Phase H0 (docs/HANDOFF.md §4: bootstrap the Python venv, the Flutter/JDK/Android toolchain, run
every verification gate, install the auto-push hook, tick H0). Every planned phase is otherwise
done, so the work now comes from docs/HANDOFF.md §1 "What is open", in its recommended order:
(1) file the IMD whitelisting request; (2) the device smoke test of app-release.apk plus the S2
widget checklist, if a handset is available; (3) send meta.urgency on POST /events; (4) deploy the
backend from infra/render.yaml; (5) the S3 app wiring (needs a Firebase project and a
google-services.json that must never be committed); (6) a release keystore, only for a store build;
(7) S4 — finish the mr/ta/bn catalogs. Spawn one agent per item, whose prompt tells it to: read
CLAUDE.md, docs/07_PHASES.md, docs/PROGRESS.md (Deviations + Notes for next phase) and the docs the
item names; deliver the item in full; verify with real commands and paste output tails; commit and
push per milestone with no attribution lines of any kind; tick PROGRESS.md and write notes for
whoever comes next; stay inside its assigned directories. A backend item and an app item may run in
parallel; never two agents in one tree, and each must git add only its own paths by name. When an
agent reports, verify briefly (git log, the gates), then spawn the next. When I say "pause" or give
a usage percentage above ~90: stop all agents, commit and push what is on disk as a WIP checkpoint,
mark those items [~]; on "resume", re-spawn per the recovery protocol in PROGRESS.md, and check
pgrep -fl "uvicorn|http.server" for servers a killed agent left behind. Schedule a one-shot safety
pause 80-90 minutes after starting two parallel agents. Keep your own turns short and never
re-derive what the docs already say.
```

## 6. Per-phase agent prompt template

```
Implement <item> of the Team Mausam SIH 2026 project in <repo path>. Read in order: CLAUDE.md,
docs/HANDOFF.md §1, docs/PROGRESS.md (Deviations, Notes for next phase), then <the docs the item
names>. They are normative. Scope: <dirs> plus docs/PROGRESS.md. Do not touch <other dirs> (another
agent may be working there). Deliver the full list. Verify before reporting, and paste the output
tails: backend work -> cd backend && .venv/bin/python -m pytest -q (386 passed today, so your
number must be >= 386); app work -> cd app && ~/development/flutter/bin/flutter analyze ("No issues
found!"), flutter test (124 passed today, so >= 124) and flutter build web. Never run flutter clean
-- it deletes app/build/app/outputs/flutter-apk/app-release.apk. Leave no servers running. Commit
and push at each milestone ("phase(<id>): ..."), no attribution lines of any kind, never git add -A
from the repo root. Tick docs/PROGRESS.md, record deviations, write "Notes for next phase".
Final report: Done / Verified / Not done + why / Exact next step.
```

## 7. Demo assets the next owner should know exist

- **Admin console:** `http://<backend>/admin/console`. The page asks for the admin key (default
  `mausam-admin`) and the backend base and keeps both in `localStorage`. Panels: scenario buttons ·
  demo clock · push-warning form with five presets · active-warnings table with delete · connected
  clients (5 s refresh, and now also `push devices: N · transport noop`) · live WebSocket feed ·
  reset-user. Everything it does is a plain REST call with `X-Admin-Key`.
- **Scenarios (10):** `?scenario=heatwave|cyclone|dense_fog|frost|severe_aqi|thunderstorm|`
  `heavy_rain|monsoon_flood|clear_pleasant|live`, per request or globally from the console
  (`POST /admin/scenario {"name": …}` — the body key is `name`).
- **Demo clock:** `?now_override=<ISO>`; without an offset it is read as IST; `{"now": null}` clears
  it. **Keep it inside the 48-hour forecast window (today or tomorrow).** Outside it the *ranking*
  still moves but the *reading* stays on the live observation rather than inventing one — deliberate,
  and the app's presets and time picker are both computed from today for exactly this reason.
- **Fixtures:** `docs/fixtures/home_*.json` — the 8 personas plus `home_severe.json` and
  `home_coastal.json`. `app/assets/fixtures/home_sample.json` is a byte-for-byte copy of
  `home_severe.json` and is what the app shows with no network (parent / New Delhi / thunderstorm).
- **Judge demo script:** `docs/00_VISION.md` → "Judge demo script" (also in `README.md`). All ten
  steps are verified step by step in `docs/QA_REPORT.md`, with the doc quoted, what was observed,
  a verdict, a screenshot and the fix commit per row.
- **The learned reason (S1).** Start the backend with the flag, then drive it:
  ```bash
  cd backend && ENGINE_ML=1 .venv/bin/python -m uvicorn app.main:app --port 8000   # background it
  curl -s localhost:8000/health | python3 -c "import sys,json;print(json.load(sys.stdin)['engine'])"
  # {'ml': True}
  BASE=http://localhost:8000/api/v1
  TOKEN=$(curl -s -X POST $BASE/auth/guest | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
  curl -s -X POST $BASE/events -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
       -d "$(python3 -c "import json;print(json.dumps({'events':[{'type':'aqi','action':'tap'}]*10}))")"
  curl -s "$BASE/home?lat=28.61&lon=77.21" -H "Authorization: Bearer $TOKEN" \
   | python3 -c "import sys,json;b=json.load(sys.stdin);c=[x for x in b['cards']+b['more_cards'] if x['type']=='aqi'][0];print(c['score'],[r['code'] for r in c['reasons']])"
  ```
  The card gains a `learning:up` reason whose text carries the signed contribution
  ("Learned from your taps (+0.09)"), localized en/hi. **The bound is the thing to say out loud:**
  the term is clamped to ±0.1, is added to `score` and never to `urgency`, and is applied only to
  unpinned, non-hero cards — so a learned card is below a pinned warning structurally, not by
  arithmetic. `POST /me/reset-learning` puts the score back to its v1 value exactly.
- **`/health`** reports the provider chain, the active scenario, `engine:{"ml":bool}` and
  `push:{transport,devices}` — a one-line honest status for a judge who asks what is live.
- **Push:** `docs/09_PUSH_NOTIFICATIONS.md` is the full design (why the WebSocket is not enough,
  the transport swap, the message schema, registration, `affects_you`, Android/iOS delivery,
  security, rollout checklist, sequence diagram). The registry works today with no Firebase account
  — the transport is `noop` and logs every broadcast.
- **The home-screen widget:** once the app is installed and has loaded the feed once, long-press the
  home screen → Widgets → **Mausam Personalized** → drag out the 4x1 or 4x2 tile. It shows the last
  `/home` payload — temperature, condition, location, how old the reading is, and the top pinned
  card in its severity colour — refreshes about hourly, and opens the app or that card's detail when
  tapped. `docs/06_MOBILE_SPEC.md` §Home-screen widget. **Never seen on a device** (open item 2).
- **The deck:** `docs/TeamMausam_SIH2026_PS26076.pptx`, 6 slides, speaker notes on all six, seven
  `c1_*` screenshots embedded. It is **generated, not hand-authored** — regenerate rather than
  editing the packed XML. Recipe in `docs/PROGRESS.md` → "Notes for next phase → Stretch → How the
  deck was built": a `pptxgenjs` script in a scratch directory, content taken section by section
  from `docs/08_PITCH.md`. The four gotchas that cost time: set `pres.layout = "LAYOUT_WIDE"`
  **before** adding slides; hex colours with no `#` and no alpha; a literal `"·  "` prefix instead
  of `bullet: true`; and `valign: "top"` on any box taller than its text.
- **Best screenshots to show** (full table with the reasons in the C2 notes):
  `c1_step02_morning_0730_parent_commuter.png` for the opening;
  `c1_step03_persona_{parent,fitness,health}.png` — same backend, same location, same minute, three
  different feeds; `c1_step05_ws_before.png` → `c1_step05_ws_rerank.png` for the live re-rank;
  `c1_step11_scenario_heatwave.png` for severity at full strength;
  `c1_step06_why_sheet_pollen.png` → `c1_step06_humidity_demoted_to_more.png` for explainability;
  `c1_step04_coastal_tides_estimated.png` for honest data;
  `c1_step08_hindi_home.png` for multilingual; `c1_step07_offline_cached.png` for no-network.
  **`b2b_demo_sheet.png` and `b2b_places.png` are stale** — use `c1_extra_demo_sheet.png` and
  `c1_step09_places_page.png`.
- **The honest phrasing the pitch uses, and why it has to stay.** Everything on screen in this repo
  was observed in the **web build (100 % of the same Dart code) plus a static APK check**, never on
  a handset. The APK is **debug-signed** — "installable", not "release-ready". Say
  **"5 languages offered, 2 complete"** — mr/ta/bn fall back per key. Tides, pollen and traffic are
  **modelled**: each carries `"source": "estimated"`, the UI draws an **Estimated** chip, and tides
  add a disclaimer naming INCOIS and the Survey of India. **IMD is not whitelisted** and returned
  `401` throughout the QA run; the fallback chain handled it and `/health` said so. Never present
  an estimate as an observation (`CLAUDE.md` §6), and never use IMD logos or imply IMD endorsement
  (§9).

**Rehearsal notes for a live demo** (from the C2 notes): start the backend first and point the app
at `http://127.0.0.1:8000`, never `localhost`; wait for the **green dot** on the freshness chip —
that is `/ws/alerts` connected, and it is what makes step 5 work. **Delete any pushed warning before
moving on** (`GET /admin/state` lists the ids, `DELETE /admin/warnings/{id}`) — a live warning pins
cards and changes every later screen. Step 6 takes **three** "Show less" taps, not two. The
traveller step needs **two saved places added first** (Mumbai, London) or `saved_places` /
`packing_suggestions` / `travel_alerts` are simply absent. The demo needs a network: Open-Meteo and
RainViewer are keyless but live — rehearse the offline path as the feature it is.
