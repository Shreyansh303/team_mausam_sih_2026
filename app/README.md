# mausam_app

The Flutter client of the Team Mausam prototype for SIH 2026, PS 26076: a persona-aware,
self-adapting home screen for weather, air-quality and marine data. It renders the ranked cards the
backend returns from `GET /home`, shows why each card is there, learns from taps and dismissals,
re-ranks live when a warning arrives over the WebSocket, works offline from cache, and is
multilingual (English and Hindi complete; Marathi, Tamil and Bengali best-effort with per-key
fallback).

Display name "Mausam Personalized (Team Mausam prototype)", app id `com.teammausam.mausam_app`.
This is a Team Mausam prototype, not an IMD product (see `../docs/00_VISION.md`, principle 8).

## Run

Start the backend first ([`../README.md`](../README.md) §12, or the long-form guide in
[`../docs/RUNNING.md`](../docs/RUNNING.md)). Then, from this directory:

```bash
flutter pub get
flutter run -d chrome        # web; or plain `flutter run` with an emulator or device attached
```

Backend URL rule: web and desktop default to `http://localhost:8000`, the Android emulator to
`http://10.0.2.2:8000`, a physical device needs the laptop's LAN IP set under **Settings → Backend
URL**, and `--dart-define=BACKEND_URL=<origin>` bakes a default into a build; Settings always
overrides. With no backend reachable the app renders from cache, then from the bundled sample
payload, and labels each as such.

## Check

```bash
flutter analyze
flutter test
flutter build web
```

`../README.md` §11 lists the full test and build gates for both halves of the project.

## Layout

- `lib/core/` — config, theme, router, connectivity, formatters
- `lib/data/` — API client, JSON cache, models, repositories, WebSocket client, widget snapshot
- `lib/features/` — onboarding, home (cards, renderers, detail pages, why sheet), places, map,
  settings, demo controls
- `lib/l10n/` — ARB files and generated localizations
- `test/` — widget, model, fixture-contract and l10n tests
- `android/` — the Android project, including the home-screen widget provider

## Further reading

- [`../docs/06_MOBILE_SPEC.md`](../docs/06_MOBILE_SPEC.md) — screens, renderers, offline
  behaviour, i18n, the home-screen widget
- [`../docs/04_API_CONTRACT.md`](../docs/04_API_CONTRACT.md) — the REST and WebSocket contract the
  app consumes
- [`../docs/fixtures/`](../docs/fixtures/) — real `/home` payloads the fixture-contract test runs
  against
