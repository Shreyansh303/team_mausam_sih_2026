# HANDOFF — continuing this project with your own Claude

This repo is designed so that any Claude Code session can pick it up cold. The plan is in `docs/`
(normative), the rules in `CLAUDE.md` (auto-loaded by Claude Code), and the live state in
`docs/PROGRESS.md`. Nothing important lives outside git except the local toolchain.

## 1. Where things stand
See `docs/PROGRESS.md` → "Phase status" (the checkboxes are the truth) and `git log --oneline`.
Handoff-ready points are phase boundaries with a clean tree. The intended split:
- **Done by the first owner:** A1–A3 (backend: data layer, personalization engine, `/home`, auth,
  live alerts, admin console, deploy/CI) and B0–B1 (Flutter toolchain, app foundation).
- **For the next owner:** B2 (full card system, map, places, WebSocket, events), B3 (integration,
  APK, CI), C1 (end-to-end QA against the judge demo script), C2 (README, pitch deck), stretch.

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

## 4. Ready-to-paste orchestrator prompt (start of each new session)
```
You are the orchestrator for Team Mausam's SIH 2026 project in this repo. Read CLAUDE.md,
docs/HANDOFF.md, docs/PROGRESS.md and docs/07_PHASES.md. You do not implement anything yourself.
For the next unchecked phase(s) in PROGRESS.md (respecting the parallelism rules), spawn an Opus
agent (Agent tool, model "opus", run in background) whose prompt tells it to: read CLAUDE.md,
docs/07_PHASES.md §<phase>, docs/PROGRESS.md (Deviations + Notes for next phase) and the docs the
phase names; deliver the phase's full list; verify with real commands and paste output tails;
commit + push per milestone with no attribution lines; tick PROGRESS.md and write notes for the
next phase; stay inside its assigned directories. When an agent reports, verify briefly (git log,
tests), then spawn the next phase. When I say "pause", TaskStop all agents, checkpoint (commit +
push), mark phases [~]; when I say "resume", re-spawn per the recovery protocol. Keep your own
turns short and do not spend tokens re-deriving what the docs already say.
```

## 5. Per-phase agent prompt template
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

## 6. Demo assets the next owner should know exist
- Admin console: `http://<backend>/admin/console` (key `mausam-admin` in demo mode) — push
  warnings, switch scenarios, set the demo clock.
- Scenarios: `?scenario=heatwave|cyclone|dense_fog|frost|severe_aqi|thunderstorm|heavy_rain|
  monsoon_flood|clear_pleasant|live`; demo clock: `?now_override=<ISO>`.
- Fixtures for the app: `docs/fixtures/home_*.json` (8 personas + severe + coastal).
- Judge demo script: `docs/00_VISION.md` → "Judge demo script".
