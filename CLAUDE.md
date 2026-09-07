# Team Mausam — SIH 2026 · PS 26076 · Personalized homepage for the "Mausam" app

Read this file first. Then read `docs/07_PHASES.md` and the docs your phase references.

## What we are building
A working prototype of a **persona-aware, context-aware, self-adapting home screen** for IMD's
Mausam mobile app. The backend (FastAPI) fetches weather/air/marine data, derives
persona-specific insights, and runs a **personalization engine** that ranks ~33 card types.
The Flutter app renders the ranked cards, learns from taps/dismissals, re-ranks live when a
warning is pushed over WebSocket, works offline from cache, and is multilingual (en/hi + more).

Problem statement text and the 8 personas: `docs/00_VISION.md`.

## Repo map
```
CLAUDE.md                 this file
docs/                     THE PLAN. Specs are normative; code follows docs.
  00_VISION.md            problem statement, personas, principles, judge demo script
  01_ARCHITECTURE.md      stack decisions, data sources (verified), repo layout, deployment
  02_CARD_CATALOG.md      every card: personas, affinities, data, insight + urgency rules
  03_PERSONALIZATION_ENGINE.md  scoring formulas, context, learning, explainability
  04_API_CONTRACT.md      REST + WebSocket contract between backend and app (normative)
  05_BACKEND_SPEC.md      FastAPI structure, providers, derived-metric formulas, scenarios
  06_MOBILE_SPEC.md       Flutter structure, screens, renderers, offline, i18n, animation
  07_PHASES.md            phase-by-phase work packages for implementation agents
  PROGRESS.md             living checklist — update it as you finish items
  fixtures/               example JSON payloads shared by backend and app
backend/                  FastAPI service (Python 3.13, venv at backend/.venv)
app/                      Flutter app (package `mausam_app`)
infra/                    docker-compose, render.yaml
scripts/                  setup + run scripts (Windows-first)
.github/workflows/        CI: backend tests, Flutter analyze/test, APK build artifact
```

## Ground rules for implementation agents
1. **Scope.** Touch only the directories your phase assigns, plus `docs/PROGRESS.md` and
   `docs/fixtures/`. If you must change a spec, edit the doc in the same change and record
   the deviation in PROGRESS.md under "Deviations".
2. **The API contract is law.** `docs/04_API_CONTRACT.md` is the interface between backend and
   app. Field names, enums and units there are exact.
3. **Verify before you report.** Run the tests/build for your phase and include the command and
   the last ~10 lines of real output in your final report. Never claim a build passed that you
   did not run.
4. **Checkpoint often.** After each milestone: `git add <your paths> && git commit -m "phase(<id>): <what>"`.
   If `.git/index.lock` exists, wait 5 s and retry (another agent may be committing). Never
   `git add -A` from the repo root; never rewrite history. **After every commit, push:**
   `git push origin main`; if rejected, `git pull --rebase origin main` then push again. Commit
   small and often (each milestone, not one giant commit). **No attribution lines of any kind**
   in commit messages (no Co-Authored-By, no "Generated with", no tool names) — the author is the
   repo's configured git user only.
5. **Progress file.** Tick items in `docs/PROGRESS.md` as you complete them and add
   "Notes for next phase" (gotchas, versions, anything a cold-start agent needs).
6. **Honest data.** Anything modelled/estimated (tides, pollen, traffic) must carry
   `"source": "estimated"` and the UI must label it. Never present estimates as observations.
7. **No secrets in git.** Use `.env.example`. No API keys are required for the default setup.
8. **Windows host.** Git Bash and PowerShell 5.1 are available; Python 3.13 at `C:\Python313\python.exe`;
   Node 22. Assume **no admin rights**. Toolchains install under `D:\sdk\`.
   Env changes made with `setx` do not apply to the current shell — use absolute paths.
   **Gradle/APK builds from an agent shell need `TEMP`/`TMP` on a short local path** — run them as
   `TEMP='D:\sdk\tmp' TMP='D:\sdk\tmp' flutter build apk --debug` (also pass
   `dangerouslyDisableSandbox: true`). Cause (verified with a JDK repro in B1, superseding the
   earlier "sandbox blocks loopback" note): JDK 17's `Selector.open()` creates an **AF_UNIX** socket
   file in `java.io.tmpdir`; under `%LOCALAPPDATA%\Temp` that `connect` returns `EINVAL`, which
   `PipeImpl` reports as `java.io.IOException: Unable to establish loopback connection`, and Gradle
   cannot start. Do **not** try IPv4 flags, daemon toggles or `app/android/gradle.properties` edits —
   they do not touch the cause. `flutter build web`, `flutter analyze`, `flutter test`, Python and
   curl are fine inside the sandbox. A normal user terminal is unaffected by any of this.
9. **Don't impersonate IMD.** App id `com.teammausam.mausam_app`, display name
   "Mausam Personalized (Team Mausam prototype)". Use IMD colour conventions, not IMD logos.
10. **Final report format (keep it short):** Done / Verified (commands + output tail) /
    Not done + why / Exact next step. No essays.

## Quick commands (after setup)
```
# backend
cd backend && .venv/Scripts/python -m uvicorn app.main:app --reload --port 8000
cd backend && .venv/Scripts/python -m pytest -q
# app (Flutter)  — toolchain lives in D:\sdk\flutter (see scripts/setup_flutter_windows.ps1)
cd app && flutter pub get && flutter analyze && flutter test
cd app && flutter build web            # fast check, serves from build/web
cd app && flutter build apk --debug    # needs Android SDK from setup script
```
