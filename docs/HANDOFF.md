# HANDOFF — continuing this project with your own Claude

This repo is designed so that any Claude Code session can pick it up cold. The plan is in `docs/`
(normative), the rules in `CLAUDE.md` (auto-loaded by Claude Code), and the live state in
`docs/PROGRESS.md`. Nothing important lives outside git except the local toolchain.

## 1. Where things stand (handed off 2026-09-07, commit `27f9d8a`, tree clean, origin in sync)
See `docs/PROGRESS.md` → "Phase status" (the checkboxes are the truth) and `git log --oneline`.
- **Done (first owner):** A1–A3 — backend complete: providers with IMD→Open-Meteo fallback, 33 card
  builders, personalization engine with explainability + learning, `/home` with every param, auth,
  saved places, events, en/hi i18n, admin console, WebSocket live alerts, Docker/Render config,
  GitHub Actions CI; **300 offline tests pass**. B0–B1 — Flutter toolchain script, app foundation
  (onboarding, home shell, persona chips, banner, cache/offline, 6 renderers + generic fallback,
  settings, en/hi scaffolding); `flutter analyze` clean, 44 tests pass, web build verified against
  the live backend (`docs/screenshots/b1_home.png`).
- **Next (new owner):** H0 (bootstrap your machine) → B2 (the ten pending renderers listed in
  `PROGRESS.md` "B2 — what B1 hands you", detail pages, re-rank animation, events pipeline,
  why-sheet actions, places, map, settings, demo sheet, WS client, low-bandwidth, a11y, full
  en/hi, icon/splash) → B3 (live integration, release APK, Flutter CI, run-it-yourself README) →
  C1 (QA against the judge demo script) → C2 (README, pitch, pptx) → stretch.
- Known items for B2 (details in PROGRESS notes): `hourly_forecast.data.hours` currently has the
  remaining hours of the day (17 in the fixture) rather than a fixed 24; `Card.score` can exceed 1.0
  when boosts stack — never treat it as 0..1; three card types (`frost_alert`, `heat_alert`,
  `travel_alerts`) appear in no fixture — use the scenario URLs in PROGRESS to render them.

## 2. How the work is run (the protocol)
- **Orchestrator session (Fable or any strong model) never writes code.** It reads
  `docs/PROGRESS.md`, spawns **one Opus agent per phase** (Agent tool, `model: "opus"`), reads the
  agent's short report, verifies with a quick command, and moves on. This keeps expensive-model
  usage tiny and spends the cheaper daily/weekly limit on implementation.
- **Parallelism:** A-phases (backend) and B-phases (app) touch different directories and may run
  side by side: A3 ∥ B2 → B3 → C1 → C2. Never two agents in the same directory.
- **Checkpoints:** agents commit per milestone and push every commit; no attribution lines of any
  kind in commit messages (the author is the repo's git user). Install the local auto-push hook
  once per clone:
  ```bash
  printf '#!/bin/sh\n[ "$(git rev-parse --abbrev-ref HEAD)" = main ] && git push origin main >/dev/null 2>&1 || true\n' > .git/hooks/post-commit && chmod +x .git/hooks/post-commit
  ```
- **Usage-limit pause:** at ~95% of the 5-hour session limit, stop every agent (`TaskStop`),
  commit + push what is on disk as a WIP checkpoint, mark in-progress phases `[~]` in
  `PROGRESS.md`, and resume only after the reset. The orchestrator cannot see the meter — the
  human pings a percentage, and a one-shot timer (~80 min for two parallel agents) is the safety
  net. Consider turning off "extra usage" in your Claude plan so hitting 100% can never bill credits.
- **Recovery:** an interrupted agent loses its conversation, not its files. Follow "Recovery after
  an interrupted agent" in `PROGRESS.md`: trust the tree and the tests over the checklist.

## 3. Machine setup for a new owner
- **Backend (any OS):** Python 3.13 → `python -m venv backend/.venv` → install
  `backend/requirements.txt` and `backend/requirements-dev.txt` → `pytest -q` in `backend/` must be
  green → `uvicorn app.main:app --port 8000`. No API keys needed. `backend/README.md` has details.
- **App on Windows:** run `scripts/setup_flutter_windows.ps1` (user-space install to `D:\sdk`),
  then `docs/SETUP_WINDOWS.md`. The `TEMP=D:\sdk\tmp` recipe in `CLAUDE.md` §8 only matters for
  Gradle started from an agent shell; a normal terminal is unaffected.
- **App on macOS/Linux:** install Flutter stable, JDK 17 and the Android SDK the standard way
  until `flutter doctor` is happy; ignore the Windows-specific paths in `CLAUDE.md` §8.
- iOS builds and simulators need macOS; judges get the Android APK.

## 4. Phase H0 — fresh-machine bootstrap (run first on a new computer)
Nothing but git is assumed. An Opus agent does all of it; the human only opens Claude Code in the
cloned folder. Deliverable: both verification gates green, then `[x] H0` in PROGRESS.md.
1. Backend: install Python 3.13 if missing (winget/brew/apt or python.org, user-space OK) →
   `python -m venv backend/.venv` → pip install `backend/requirements.txt` + `requirements-dev.txt`
   → gate: `pytest -q` in `backend/` green (offline; no keys) → start uvicorn in background, curl
   `/api/v1/health`, stop it.
2. App: Windows → run `scripts/setup_flutter_windows.ps1` then follow `docs/SETUP_WINDOWS.md`
   (installs Flutter stable, JDK 17, Android SDK to `D:\sdk` without admin; adjust the drive letter
   in the script if there is no D:). macOS/Linux → install Flutter stable, JDK 17, Android
   command-line tools + platform-tools/build-tools, accept licenses. Gate: `flutter doctor` shows
   Flutter + Android toolchain + a browser OK; `flutter pub get`, `flutter analyze`, `flutter test`,
   `flutter build web` all pass in `app/`; `flutter build apk --debug` succeeds (on Windows from an
   agent shell use the TEMP recipe in CLAUDE.md §8).
3. Install the auto-push hook from §2; confirm `git config user.name/email` are the new owner's.
4. Record machine specifics (OS, paths, versions) in PROGRESS.md "Notes for next phase".

## 5. Ready-to-paste orchestrator prompt (start of each new session)
```
You are the orchestrator for Team Mausam's SIH 2026 project in this repo. Read CLAUDE.md,
docs/HANDOFF.md, docs/PROGRESS.md and docs/07_PHASES.md. You do not implement anything yourself:
all implementation runs on Opus agents (Agent tool, model "opus", run in background) so that
expensive-model usage stays minimal. If PROGRESS.md does not show "[x] H0" for this machine, first
spawn one Opus agent for Phase H0 (docs/HANDOFF.md §4: bootstrap Python venv, Flutter/JDK/Android
toolchain, run all verification gates, install the auto-push hook, tick H0). Then, for the next
unchecked phase(s) in PROGRESS.md (respecting the parallelism rules in docs/07_PHASES.md), spawn
one Opus agent per phase whose prompt tells it to: read CLAUDE.md, docs/07_PHASES.md §<phase>,
docs/PROGRESS.md (Deviations + Notes for next phase) and the docs the phase names; deliver the
phase's full list; verify with real commands and paste output tails; commit + push per milestone
with no attribution lines of any kind; tick PROGRESS.md and write notes for the next phase; stay
inside its assigned directories. When an agent reports, verify briefly (git log, tests), then
spawn the next phase. When I say "pause" or give a usage percentage above ~90, TaskStop all
agents, checkpoint (commit + push), mark phases [~]; when I say "resume", re-spawn per the
recovery protocol in PROGRESS.md. Schedule a one-shot safety pause ~80 minutes after starting two
parallel agents. Keep your own turns short and never re-derive what the docs already say.
```

## 6. Per-phase agent prompt template
```
Implement Phase <ID> of the Team Mausam SIH 2026 project in <repo path>. Read in order: CLAUDE.md,
docs/07_PHASES.md §<ID>, docs/PROGRESS.md (Deviations, Notes for next phase), then <docs the phase
names>. They are normative. Scope: <dirs> plus docs/PROGRESS.md. Do not touch <other dirs> (another
agent may be working there). Deliver the full §<ID> list. Verify before reporting: <phase's
verification commands>; paste output tails. Commit + push at each milestone
("phase(<ID>): ..."), no attribution lines, never git add -A from root. Tick PROGRESS.md, mark the
phase [x] when done, record deviations, write "Notes for next phase". Final report: Done /
Verified / Not done + why / Exact next step.
```

## 7. Demo assets the next owner should know exist
- Admin console: `http://<backend>/admin/console` (key `mausam-admin` in demo mode) — push
  warnings, switch scenarios, set the demo clock.
- Scenarios: `?scenario=heatwave|cyclone|dense_fog|frost|severe_aqi|thunderstorm|heavy_rain|
  monsoon_flood|clear_pleasant|live`; demo clock: `?now_override=<ISO>`.
- Fixtures for the app: `docs/fixtures/home_*.json` (8 personas + severe + coastal).
- Judge demo script: `docs/00_VISION.md` → "Judge demo script".
