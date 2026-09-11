# Submission Guide

Pre-submission checklist for this repository — **Team Mausam · SIH 2026 · PS 26076**
(MoES / India Meteorological Department). Each row names a requirement from the SIH submission
template, whether it is done, and where it lives in this tree. Fill in every **PENDING** row before
the deadline.

Repository: <https://github.com/Shreyansh303/team_mausam_sih_2026>

## Required repository content

| Requirement | Status | Where |
|---|---|---|
| Source code is present | done | `backend/` (FastAPI service), `app/` (Flutter app), `infra/` (Docker, Render), `scripts/` (toolchain setup) |
| README explains the project | done | `README.md` §1–13 |
| Problem statement ID and title | done | `README.md` §1 (PS ID 26076, title, organisation, theme, category); verbatim statement in `README.md` §2 and `docs/00_VISION.md` |
| Problem description and proposed solution | done | `README.md` §2–3; long form in `docs/08_PITCH.md` §1–2 |
| Key features | done | `README.md` §4; per-card detail in `docs/02_CARD_CATALOG.md` |
| Technology stack | done | `README.md` §5; decisions in `docs/01_ARCHITECTURE.md` |
| System architecture | done | `README.md` §6; reviewer-facing overview in `docs/architecture.md` |
| Repository structure | done | `README.md` §7; also below |
| Setup and run instructions that work | done | `README.md` §11–12; long form for every platform in `docs/RUNNING.md`; Windows toolchain in `docs/SETUP_WINDOWS.md` |
| Team members and roles | **PENDING** | `README.md` §1 — placeholder table; no member list is recorded anywhere else in the repository |
| Screenshots | done | `assets/screenshots/` (63 PNG files) with the index `assets/screenshots/README.md`; a selection is embedded in `README.md` §10 |
| Final PPT in `submission/` | done | `submission/TeamMausam_SIH2026_PS26076.pptx` (six slides, speaker notes), described in `submission/PRESENTATION.md` and linked from `README.md` §8 |
| Drive/OneDrive link to the PPT (only if too large) | done (optional) | Google Drive folder linked from `submission/PRESENTATION.md` §External presentation link and `README.md` §8 — the file is 1.4 MB and tracked, so the link is a convenience |
| Demo video link (optional, recommended) | done | YouTube link in `submission/DEMO.md` §Demo video link and `README.md` §9 |
| Licence | done | `LICENSE` (MIT, Team Mausam) |
| Python requirements at the root | done | `requirements.txt` → `backend/requirements.txt` |
| Continuous integration | done | `.github/workflows/backend.yml` (offline `pytest`), `.github/workflows/flutter.yml` (`flutter analyze`, `flutter test`, release APK and web bundle as artifacts) |
| Evidence that the prototype works end to end | done | `docs/QA_REPORT.md` — all ten demo steps walked against a live backend, verdict PASS |
| Repository is accessible to the reviewers | **PENDING** | confirm the repository is public (or that the evaluators have access) and that the URL above opens logged out |

## Repository structure

```
team_mausam_sih_2026/
├── README.md                          project overview — 13 numbered sections
├── SUBMISSION_GUIDE.md                this checklist
├── LICENSE                            MIT
├── requirements.txt                   -> backend/requirements.txt
├── submission/
│   ├── PRESENTATION.md                the deck, and where its content comes from
│   ├── DEMO.md                        demo video link and the ten-step script it records
│   └── TeamMausam_SIH2026_PS26076.pptx
├── assets/
│   └── screenshots/                   63 PNGs from the QA walk and earlier milestones + README.md index
├── docs/
│   ├── architecture.md                reviewer-facing architecture overview
│   ├── RUNNING.md                     run guide for Windows, macOS and Linux; troubleshooting
│   ├── DEVIATIONS.md                  where the implementation departs from the numbered specs
│   ├── SETUP_WINDOWS.md               Flutter/Android toolchain on Windows without admin rights
│   ├── QA_REPORT.md                   end-to-end walk of the judge demo script (verdict PASS)
│   ├── 00_VISION.md                   problem statement, personas, product principles, demo script
│   ├── 01_ARCHITECTURE.md             stack decisions, data sources, deployment
│   ├── 02_CARD_CATALOG.md             all 33 cards: personas, affinities, insight and urgency rules
│   ├── 03_PERSONALIZATION_ENGINE.md   scoring formulas, context, learning, explainability
│   ├── 04_API_CONTRACT.md             REST + WebSocket contract (normative for both sides)
│   ├── 05_BACKEND_SPEC.md             FastAPI structure, providers, derived metrics, scenarios
│   ├── 06_MOBILE_SPEC.md              Flutter structure, screens, renderers, offline, i18n
│   ├── 08_PITCH.md                    pitch text — the source of the deck
│   ├── 09_PUSH_NOTIFICATIONS.md       FCM design for the production alert transport
│   ├── 10_SIH_DECK_CONTENT.md         finale-deck slide-by-slide content
│   ├── 11_IMPACT_NUMBERS.md           sourced external impact statistics
│   └── fixtures/                      10 example /home payloads shared by backend and app
├── backend/                           FastAPI service, Python 3.13
│   ├── app/                           api · engine · providers · services · schemas · models · data · static
│   ├── tests/                         offline pytest suite (upstream payloads replayed from tests/fixtures/)
│   ├── scripts/                       record_fixtures.py, gen_fixtures.py
│   ├── Dockerfile · requirements.txt · requirements-dev.txt · .env.example · README.md
├── app/                               Flutter app, package mausam_app
│   ├── lib/                           core · data · features · l10n
│   ├── test/                          flutter test suite
│   ├── android/ · ios/ · web/ · assets/
│   └── pubspec.yaml · README.md
├── infra/                             docker-compose.yml, render.yaml
├── scripts/                           toolchain setup and emulator scripts (Windows and macOS/Linux)
└── .github/workflows/                 backend.yml, flutter.yml
```

## Presentation

The final deck is `submission/TeamMausam_SIH2026_PS26076.pptx`; `submission/PRESENTATION.md`
lists its six slides and the documents each slide draws on (`docs/08_PITCH.md`,
`docs/10_SIH_DECK_CONTENT.md`, `docs/11_IMPACT_NUMBERS.md`). It also carries a Google Drive viewer
link for reviewers who would rather open the deck in a browser; the tracked file is the
authoritative copy.

## Demo video

`submission/DEMO.md` holds the video link, the ten-step script the recording follows
(from `docs/00_VISION.md`), the recording notes, and the written evidence that backs the video up:
`docs/QA_REPORT.md` and the screenshot index.

## Screenshots

`assets/screenshots/` — 63 PNG files. The 40 `c1_*.png` shots are the end-to-end QA walk, one per
demo step and variant; the `b1_*`, `b2a_*`, `b2b_*` and `b3_*` shots are from earlier milestones.
`assets/screenshots/README.md` indexes them. All were taken from the Flutter web build driven
against a locally running backend, except the offline shots (backend stopped, rendering from the
on-device cache).

## Do not upload

None of the following belongs in the repository. `.gitignore` already excludes each of them;
check `git status` before every push anyway.

- Passwords, API keys, tokens, JWT secrets, admin keys for a public deployment.
- `.env` / `.env.local` with real values. **`backend/.env.example` is the only env file tracked**,
  and it contains no secrets — the default setup needs no API key at all (`docs/00_VISION.md`,
  product principle 9).
- The Firebase service-account JSON (`FCM_SERVICE_ACCOUNT_FILE`) and `google-services.json` —
  both are secrets; keep them outside the tree (`backend/README.md` §Push notifications).
- Android signing material: `app/android/key.properties`, `*.keystore`, `*.jks`.
- Build output and local tooling state: `app/build/`, `backend/.venv/`, `backend/data/*.db`,
  `app/android/local.properties`.
- Private credentials of any team member.

## What the README answers

| Question from the template | README section |
|---|---|
| Which problem statement is it for, and who built it? | §1 Project Information — PS ID, title, organisation, theme, category, and the team table (**fill in the member placeholders**) |
| What is the problem, and why does it matter? | §2 Problem Statement |
| What is the proposed solution? | §3 Proposed Solution |
| What are the key features? | §4 Key Features |
| Which technologies does it use, and how is it built? | §5 Technology Stack, §6 Architecture, §7 Repository Structure |
| How do I set it up and run it? | §11 Installation, §12 Run |
| Where are the presentation, the demo and the screenshots? | §8 Final Presentation, §9 Demo Video, §10 Screenshots / Prototype Photos |

`README.md` §13 Future Scope lists what is planned beyond the prototype.

## Before submission

1. **Fill the last placeholder.** Team members and roles in `README.md` §1 — no member list is
   recorded anywhere in this repository, so the table is still `<MEMBER_NAME>` / `<ROLE>` /
   `<GITHUB_HANDLE>`. Search the tree for `<MEMBER_NAME>` to confirm none remain. The demo-video
   and presentation links are already filled in.
2. **Run the two test suites** and confirm both pass:

   ```bash
   cd backend && .venv/bin/python -m pytest -q        # Windows: .venv\Scripts\python -m pytest -q
   cd app && flutter analyze && flutter test
   ```

   Both suites run fully offline. If the counts have moved since the deck was made, update
   slide 4 (`submission/PRESENTATION.md` §Requirements).
3. **Check the repository logged out.** Open
   <https://github.com/Shreyansh303/team_mausam_sih_2026> in a private/incognito window and
   confirm the README renders, the screenshots in §10 display, and
   `submission/TeamMausam_SIH2026_PS26076.pptx` downloads.
4. **Check every external link logged out** — the demo video and, if used, the deck link — in
   the same private window.
5. **Check for secrets one last time:** `git status` shows no `.env`, `google-services.json`,
   keystore or `key.properties`; `git ls-files | grep -i env` returns only `backend/.env.example`.
6. **Confirm CI is green** on the default branch: the `backend` and `flutter` workflows under
   `.github/workflows/`.
