# Project Presentation

The SIH 2026 idea-presentation decks for **Team Mausam · PS 26076** (MoES / India
Meteorological Department) are kept in this folder, alongside the rest of the repository.

## Presentation file

The deck the team presents:

- **PPT:** [Open Final Presentation](./TeamMausam_SIH2026_Presentation.pptx)
  (`TeamMausam_SIH2026_Presentation.pptx`, 7.1 MB, 6 slides)

| # | Slide | What it carries |
|---|---|---|
| 1 | Title and problem statement | The mandated PS fields (ID 26076, title, Ministry of Earth Sciences / IMD, theme Smart Automation, category Software, Team Mausam), the package id, the repository and demo links, and the target platforms |
| 2 | Solution overview | One ranked feed per user: 1–3 personas, smart ranking by relevance, context and urgency, server-driven layout, honest data, live updates, multilingual copy, built for real phones |
| 3 | Technical approach | Flutter app, FastAPI backend, the pure-Python ranking pipeline, and the provider chain IMD → Open-Meteo → estimated |
| 4 | Feasibility and viability | Technical, operational, economic and institutional feasibility; the risks and how each one is handled |
| 5 | Impact and benefits | Who each persona's top cards serve, and the social, economic and environmental benefit behind them |
| 6 | Research and references | The specs and QA evidence behind the claims, the data sources, and the external statistics with their citations |

The title slide carries the disclaimer that applies to the whole project: this is a Team Mausam
prototype for SIH 2026, not an IMD product, not affiliated with or endorsed by IMD or MoES; it uses
IMD's public warning colour conventions and no IMD logos.

## Companion deck

An earlier build of the same story, generated from the pitch document, is kept as well. It is
plainer than the deck above but carries speaker notes on every slide, so it is useful for rehearsal.

- **PPT:** [Open the companion deck](./TeamMausam_SIH2026_PS26076.pptx)
  (`TeamMausam_SIH2026_PS26076.pptx`, 1.4 MB, six slides, speaker notes on every slide)

| # | Slide | What it carries |
|---|---|---|
| 1 | Title and the problem | The mandated PS fields (ID 26076, title, theme Smart Automation, category Software, Team Mausam), the eight user groups from the problem statement, and why a single fixed screen fails them |
| 2 | Proposed solution | One ranked feed per user, computed on the server and explained on the card: gate, then score `0.5 · relevance · context + 0.5 · urgency + learning` over 33 card types |
| 3 | Technical approach | Flutter app, FastAPI backend, pure-Python ranking engine, the provider chain IMD → Open-Meteo → estimated; no API key needed to run any of it |
| 4 | Feasibility and viability | Test counts, measured latencies and payload sizes, the end-to-end QA verdict, risks and how each is handled |
| 5 | Impact and benefits | What lands at the top of each persona's screen, and the cards behind it |
| 6 | The demo, and what comes next | The ten-step judge demo script and the future scope |

### Where the content comes from

- **Slide text and every number on it:** [`../docs/07_PITCH.md`](../docs/07_PITCH.md), the pitch
  document the companion deck was generated from. Each measured figure there names where it was
  measured; the evidence file is [`../docs/QA_REPORT.md`](../docs/QA_REPORT.md).
- **Finale-deck slide content** (the denser, slide-by-slide layout with a source next to every
  claim): [`../docs/09_SIH_DECK_CONTENT.md`](../docs/09_SIH_DECK_CONTENT.md).
- **Sourced external impact statistics** for the impact slide, each with its citation:
  [`../docs/10_IMPACT_NUMBERS.md`](../docs/10_IMPACT_NUMBERS.md).

### Requirements

- Two decks are tracked here and no others: the final presentation and the companion build above.
  Superseded drafts are not tracked.
- The file names identify the team and the event: `TeamMausam_SIH2026_Presentation.pptx` is the
  one to open first; `TeamMausam_SIH2026_PS26076.pptx` also names the problem statement.
- Before the final print, re-run the two test suites (`pytest -q` in `backend/`,
  `flutter test` in `app/`) and update the two test counts on the companion deck's slide 4 if they
  have moved (see the note at the top of `../docs/09_SIH_DECK_CONTENT.md`).
- If a deck ever grows past what the repository host accepts, the viewer link below is the
  fallback.
- Test any external link while logged out or in an incognito window.

## External presentation link

<https://drive.google.com/drive/u/0/folders/1w29cHLEjk3sNfNN1hwYWn3AOmVcMml2t>

The same final deck in a Google Drive folder, for reviewers who would rather open it in a browser
than download the `.pptx`. The file tracked in this folder is the authoritative copy.
