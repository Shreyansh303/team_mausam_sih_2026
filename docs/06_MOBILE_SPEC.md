# 06 · Mobile app spec (Flutter, package `mausam_app`)

## Toolchain (Windows, user-space, no admin)
`scripts/setup_flutter_windows.ps1` (idempotent) installs to `D:\sdk`: Flutter stable (zip from
`https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json` → current
stable), Temurin JDK 17 (zip, not MSI), Android cmdline-tools → `D:\sdk\android` with
`platform-tools`, `platforms;android-35`, `build-tools;35.0.0` (or what `flutter doctor` asks for),
accepts licenses (`yes | sdkmanager --licenses`), sets user env (`setx`) `FLUTTER_HOME`, `JAVA_HOME`,
`ANDROID_HOME` and appends to user `PATH`. `scripts/flutter_env.ps1` / `scripts/flutter_env.sh`
export the same for the current shell. Gate for done: `flutter doctor` shows Flutter + Android
toolchain + Chrome OK; `flutter build web` and `flutter build apk --debug` succeed on the scaffold.

## Packages (latest stable at install; no build_runner codegen)
flutter_riverpod, go_router, dio, shared_preferences, path_provider, connectivity_plus,
geolocator, permission_handler, flutter_map, latlong2, fl_chart, intl + flutter_localizations
(`flutter gen-l10n` via `l10n.yaml`), web_socket_channel, share_plus, url_launcher,
flutter_animate, package_info_plus, cached_network_image. Card re-rank animation: use
`animated_reorderable_list` (or `great_list_view`) if it builds on the installed Flutter; otherwise a
keyed `ListView` + `flutter_animate` slide/fade entrance + a highlight flash on cards whose
position improved + a SnackBar "Warning moved to top". The pinned-warning arrival animation is
mandatory either way.

## Layout
```
app/lib/
  main.dart · app.dart (MaterialApp.router, theme, locale from settings)
  core/ config.dart (backend URL default: web → http://localhost:8000, Android emulator → http://10.0.2.2:8000, device → last saved; override in Settings/Demo)
        theme.dart (M3, seed #1565C0, severity colours: yellow #F5C518, orange #F28C28, red #D32F2F, green #2E7D32; dark mode)
        icons.dart (icon string + WMO code → IconData/emoji), formatters.dart (time/relative/units), connectivity.dart
  data/ api_client.dart (Dio, auth interceptor, lang header, error mapping)
        models/ (hand-written fromJson: user, location, place, warning, card, home_response, snapshot subset)
        cache/ json_file_cache.dart (per key file under app documents dir; get/put with timestamp)
        repositories/ auth_repo, profile_repo, home_repo (cache-first + refresh), places_repo, locations_repo, events_repo (batched, flushed every 10 s or on background), radar_repo
        ws/ alerts_socket.dart (reconnect w/ backoff, pong, exposes stream)
  features/
    onboarding/ language_page, persona_page (8 persona tiles with icon + one-line, pick 1–3, first = primary), location_page (GPS button + search + popular cities), done → guest token + PUT profile
    home/ home_page.dart (CustomScrollView: AppBar(location, demo icon), persona chips row, warning banner, quick actions row, pinned, hero, cards, "More for you" expander, freshness chip, offline banner)
          providers.dart (homeProvider(family by location+personas override), settingsProvider, authProvider, wsProvider)
          widgets/ card_shell.dart, reason_chips.dart, why_sheet.dart, freshness_chip.dart, offline_banner.dart, quick_actions.dart, persona_chips.dart
          renderers/ registry.dart + hero.dart, warnings.dart, nowcast.dart, hourly.dart, daily.dart, radar.dart, gauge.dart, metric.dart, advice_list.dart, timeline.dart, alert.dart, sea.dart, tides.dart, places.dart, bar_chart.dart, generic.dart
          detail/ card_detail_page.dart (full-screen detail per renderer, charts via fl_chart)
    places/ places_page (list, add via search, delete, set kind), map/ map_page (flutter_map: OSM tiles, RainViewer radar overlay with frame slider, warning circles/markers, user marker)
    settings/ settings_page (language, units, personas, home location, school/commute windows, backend URL, low-bandwidth, large text, reset learning, about)
    demo/ demo_sheet (time override picker, scenario dropdown, open admin console, simulate offline)
  l10n/ app_en.arb, app_hi.arb, app_mr.arb, app_ta.arb, app_bn.arb
app/assets/ fixtures/home_sample.json (fallback when backend unreachable and no cache), fonts/NotoSansDevanagari-*.ttf
app/test/ models_test.dart, renderers_test.dart (every card type in fixture renders without exception), home_page_test.dart
```

## Card shell (every card)
Material 3 `Card` (radius 16), left accent bar coloured by `severity`, header row: icon, title,
optional chips [`Estimated`, `Pinned`], overflow menu (Details, Pin/Unpin, Show less, Hide, Share).
Body = renderer(card). Footer: insight headline (bold) + detail (2 lines max), reason chips (up to
2, tappable → why sheet), actions from `card.actions`. Gestures: tap → detail page (sends `tap`);
expand affordance on large cards (sends `expand`); long-press → why sheet; swipe-left → "Show less"
(sends `dismiss`, card animates to More). Semantics label: "{title}. {subtitle}. {insight.headline}".

## Why sheet
Lists `reasons` with icons; shows personas that drove it; buttons: Pin to top, Show less, Hide this
card, Restore hidden cards (if any). Each sends the event and refreshes home.

## Home behaviour
- Load order: cached JSON (instant, shows freshness chip "Updated 12 min ago") → network refresh →
  animated diff. Pull-to-refresh. Errors keep cache and show a small banner with retry.
- Persona chips: user's personas (filled) + others (outlined). Tapping an outlined chip loads
  `/home?personas=<id>` as a temporary "role view" with a "Viewing as Fitness · Save" strip.
- Banner: shown when `banner != null`; tap scrolls to pinned warnings; Share button.
- WebSocket: connect on home; on `warning_issued` with `affects_you` → show banner immediately with
  the warning → refetch → animate. On `scenario_changed` / `now_override` → refetch.
- Impressions: send `impression` for cards visible ≥ 1 s (throttled, once per card per load).
- Low-bandwidth mode: `lite=1`, no radar tiles, no images; tiny payload badge.
- Offline: connectivity banner; all actions that need network are disabled with tooltip.

## Renderers (kind → what to draw)
hero: big temp, condition icon, feels-like, hi/lo, 4 micro-stats (humidity, wind, UV, AQI), sunrise/sunset strip, "All clear" pill or warning pill · warnings: list of severity-coloured tiles with validity, tap → detail · nowcast: 3-h text with severity chip · hourly: horizontal 24-h strip (icon, temp, rain %) · daily: 7 rows (icon, hi/lo bar, rain %) · radar: small `flutter_map` with latest RainViewer frame + "Open map" · gauge: semicircular gauge with category colour and value (aqi CPCB colours, comfort, soil moisture) · metric: value + unit + category + one-line advice (+ tiny sparkline if hourly present) · advice_list: icon + title + detail rows (packing grouped per place) · timeline: horizontal bar of windows with verdict colours and labels · alert: severity tile with level, peak time, advice bullets · sea: sea-state badge, wave height/period, SST, swim/surf pills, 24-h wave sparkline · tides: 24-h tide curve with high/low markers and "Estimated" chip · places: horizontal cards per saved place (local time, temp, icon, hi/lo, severity dot) · bar_chart: daily mm/probability bars with focus day highlighted · generic: title/subtitle/insight + key-value grid of `data` scalars (never crash on unknown cards).

## i18n
ARB for chrome; backend localizes card content via `lang`. Locale persisted in settings; changing it
refetches home. Devanagari font bundled (Noto Sans Devanagari) for web; Android uses system fonts.

## Android config
`applicationId com.teammausam.mausam_app`, label "Mausam Personalized", minSdk 23, permissions:
INTERNET, ACCESS_COARSE/FINE_LOCATION; `usesCleartextTraffic=true` (demo http backends); adaptive
icon (simple cloud/sun glyph in IMD blue, generated as PNG in repo — no IMD logo).

## Definition of done for the app
`flutter analyze` (no errors), `flutter test` green, `flutter build web` ok, `flutter build apk --debug`
ok, every card type in `docs/fixtures/home_*.json` renders, demo script in 00 executes end-to-end
against the local backend (web build verified in browser; APK on device if available).
