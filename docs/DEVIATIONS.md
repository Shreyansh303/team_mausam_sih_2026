# Deviations from the specifications

The numbered specs (`00_VISION.md` … `06_MOBILE_SPEC.md`, plus `09_PUSH_NOTIFICATIONS.md`) are normative, and
[`04_API_CONTRACT.md`](04_API_CONTRACT.md) is the interface both halves conform to. This file lists every place
where the shipped code differs from what a spec says, and why. Entries are grouped by area, not by date; each
names the spec section, what was built instead, the reason, and where the behaviour is tested or observable (a
test, an endpoint, a screenshot, or a step in [`QA_REPORT.md`](QA_REPORT.md)). Where the spec was corrected in
the same change the entry says so; the current spec text is then already right and the entry explains the history.

**The nine demo defects.** The end-to-end walk in [`QA_REPORT.md` → Defects found and
fixed](QA_REPORT.md#defects-found-and-fixed) found nine defects, D1–D9, each fixed with a regression test. They
appear below tagged with their number: D1 and D9 under *Backend and data*, D2, D4 and D8 under *Flutter app*,
D3, D5, D6 and D7 under *Demo behaviour*.

---

## Backend and data

**IMD district ids are unknown; IMD calls are skipped or backed off.** Spec: `05` §Providers reads current
weather, nowcast and warnings from IMD by station/district id. Built: `backend/app/data/imd_ids.json` has station
ids for 35 cities but every `district_id` is `null` (IMD does not publish them), and every IMD endpoint answers
`401` until the host is whitelisted. `providers/imd.py` skips a call with no id, backs off 10 minutes on `401` and
falls through to Open-Meteo; `/health` reports it. Verified:
`backend/tests/test_providers.py::test_imd_401_marks_the_provider_unavailable_and_returns_none`.

**`init_db()` drops and recreates a table whose columns no longer match the models.** Spec: `05` §Layout lists
`core/db.py` and no migration tool. Built: a table whose live column set or nullability differs from the model is
dropped, recreated and logged; otherwise a `mausam.db` from an older build is a hard 500 on the first insert. The
store holds only demo/guest state. Verified:
`backend/tests/test_home_api.py::test_init_db_rebuilds_a_table_left_over_from_an_older_schema`.

**An admin write invalidates only the `snapshot` cache bucket.** Spec: `01` §Non-functional targets, `/home` p95
< 400 ms warm. Built: `api/admin.py` calls `cache.invalidate("snapshot")` and leaves the provider buckets warm —
an admin warning cannot change what an upstream returned. Clearing everything made the next `/home` refetch every
upstream (2.7 s measured); the narrower invalidation answers in 27 ms and still sees the new warning. A request
carrying `now_override` never hits the snapshot cache (warm `/home` ~2 ms, demo-clock request ~15 ms). Verified:
`backend/tests/test_ws_admin.py::test_admin_write_drops_snapshots_but_keeps_provider_caches_warm`.

- **`parse_any` repairs an offset whose `+` arrived as a space.** `…T07:30:00+05:30` URL-decodes to `… 05:30` in
  curl and browsers; `core/timeutil.parse_any` accepts both. Verified:
  `backend/tests/test_api.py::test_snapshot_accepts_a_demo_clock`.
- **`AdminWarning` stores its times as ISO strings plus one epoch float (`expires_at_ts`).** SQLite drops the
  offset from `DateTime(timezone=True)`, so the "still live" filter would compare naive to aware and raise.
  Portable to Postgres unchanged. Verified:
  `backend/tests/test_ws_admin.py::test_expired_admin_warning_vanishes_from_home_and_state`.
- **`daylabel()` resolves day and month names through the catalog** — `daylabel(lang, value, *, with_dow=False)`
  in `engine/builders/base.py`, no `strftime`. Verified: `backend/tests/test_i18n.py::test_date_labels_are_localized`.
- **Admin-pushed and IMD warnings, and place names, are not localized.** They are free text typed by a person or
  issued by IMD; a translation key would misrepresent the source. See `QA_REPORT.md` → Known limitations 6.

**Derived-metric services emit deferred translation tokens, not English sentences.** Spec: `05` §i18n resolves
strings with `t(lang, key)`. Built: the snapshot is cached per (lat, lon, scenario), not per language, so a service
cannot localize; it emits `i18n.token(key, **params)` and the card builder resolves it once `ctx.lang` is known.
The changed shapes (`school_commute`/`commute` `windows[].reasons`, `planting.tips`, `packing.items[].item_key`,
`flight_risk.detail_tokens`) sit inside `Snapshot.derived`, which the contract leaves untyped; card `data` keeps
the plain-string shape of `02`. Verified: `backend/tests/test_i18n.py::test_hindi_advice_and_reasons_are_hindi`.

**Scenario warning copy is resolved by hazard, not stored as keys.** `scenario.warning.<hazard>.{title,description}`
is looked up when `warning.source == "scenario"`, falling back to the scenario JSON's English, so the `04`
`Warning` object gains no `*_key` fields. This relies on each scenario's warning having a distinct hazard (true
today). Scenario *nowcast* text carries an explicit `text_key`. Verified:
`backend/tests/test_i18n.py::test_every_scenario_nowcast_names_a_key_that_exists`.

**Card copy rounds the way the app does (D9).** Spec: `02` templates show rounded values; `06` renders the same
value with Dart's `.round()` / `toStringAsFixed(n)`. Built: `engine/builders/base.num()` quantizes the exact binary
double (`Decimal(float(v))`, `ROUND_HALF_UP`) — Python's `f"{30.5:.0f}"` is banker's rounding ("Feels like 31°"
beside "feels like 30 °C"), and `Decimal(str(v))` rounds 6.05 up when Dart does not ("6.0" under "6.1"). Checked
against `dart run`: 30.5 → 31, 2.35 → 2.4, 6.05 → 6.0. Verified:
`backend/tests/test_home_api.py::test_card_copy_rounds_the_way_the_app_does`.

**No catalog string fakes a plural with parentheses (D1).** Six count-bearing lines read "{count} saved place(s)",
"1 travel alert(s) — Mumbai" and so on. Each is now an explicit `.one` / `.other` pair in `en` and `hi` (Hindi does
not inflect these): `saved_places.headline`, `saved_places.detail_warning`, `daily_forecast.detail`,
`health_advisory.headline`, `rainfall_outlook.detail`, `travel_alerts.headline`. Verified:
`backend/tests/test_i18n.py::test_no_catalog_string_fakes_a_plural_with_parentheses`.

**`PyJWT[crypto]` is the one dependency added for push.** Spec: `05` §Layout pins `pyjwt`. Built:
`PyJWT[crypto]>=2.9,<3` in `backend/requirements.txt` pulls `cryptography` for the RS256 assertion FCM's OAuth2
flow needs (PyJWT does only HS256 on its own). Smaller than `google-auth`, which would also want `requests`/`urllib3`
while the backend speaks `httpx`; the flow is ~40 lines in `services/push.py`. One extra prebuilt wheel, unused
unless FCM is on. Verified: `backend/tests/test_push.py::test_fcm_builds_the_http_v1_request`.

**The fixture corpus is generated output, and its ids are random.** `fixtures/home_*.json` (ten real `/home`
payloads) come from `backend/scripts/gen_fixtures.py`; regenerating changes only the `usr_`/`plc_`/`wrn_` ids
unless engine output changed. `app/assets/fixtures/home_sample.json` is re-copied from `home_severe.json` after
each regeneration. Verified: `backend/tests/test_api.py::test_recorded_fixtures_are_committed`.

---

## API contract (docs/04)

A live `/home` was diffed against `fixtures/home_severe.json` at the top level and inside `Card`, `context`,
`freshness`, `engine` and `banner`: the key sets are identical, and the real web build against a local backend
produced zero failed requests. Everything below is additive or a clarification the contract now states.

- **Routers are mounted at `/api/v1` and at the root.** `main.py` includes every router twice, the root copy
  hidden from the schema, so bare URLs such as `GET /health` work with curl. Verified:
  `backend/tests/test_api.py::test_health_is_also_served_without_the_api_prefix`.
- **`Snapshot.derived` carries nine blocks beyond the ten named** (`sun, uv, wind, rain, soil, rainfall_outlook,
  storm_fog, sea, humidity`) so card builders read their `data` straight out of the snapshot. Additive; `derived`
  is untyped by design. Verified: `backend/tests/test_snapshot.py::test_snapshot_shape_matches_the_contract`.
- **`/locations/popular` returns up to 120 cities (spec: ≥ 40).** 106 of the 212 cities in
  `backend/app/data/cities.json` are flagged `popular`; the route defaults to `limit=120`. Verified:
  `backend/tests/test_api.py::test_locations_popular_covers_coastal_and_hill`.
- **`GET /health` reports IST, not UTC.** It has no location, so it uses the same `Asia/Kolkata` clock as
  `hello.server_time` on the WebSocket. Verified: `backend/tests/test_api.py::test_health`.
- **`Snapshot.nowcast.text_token` is a new optional field** (the `Tides.disclaimer_key` pattern), visible only on
  `/weather/snapshot`; `text` still carries the English rendering.
- **Additive: `tides.data.disclaimer` is a resolved string; `GET /home/now` reports the demo clock.** `02`/`04`
  name `disclaimer` on the tides card while the snapshot exposes `disclaimer_key`; the builder resolves it.
  `GET /home/now` (hidden from the schema) serves the admin console. Verified:
  `backend/tests/test_home_api.py::test_coastal_home_has_sea_and_tides`.

**`Snapshot.fetched_at` carries the location's offset and equals the demo clock when one is set.** Spec: every
time carries the location's offset. Built: it was `datetime.now(UTC)`, which made `Card.updated_at` and
`freshness.*` UTC and changed the fixtures on every run; now it is location-local, or `now_override` when set.
Verified: `backend/tests/test_home_api.py::test_now_override_moves_the_hero_and_reorders_the_feed`.

**`users.language` is nullable; `GET /me` coerces `null` to `"en"`.** Spec: `User.language` is a string. Built:
the column stays `null` until the user picks a language, which is what makes the documented order work —
`?lang=` → saved choice → `Accept-Language` → `en`. A stored `"en"` default always shadowed `Accept-Language`.
Verified: `backend/tests/test_home_api.py::test_accept_language_header_is_used_when_no_query_or_profile`.

**`/ws/alerts` accepts a missing `token` under `DEMO_MODE=1`; an invalid one is always closed with 1008.** The
admin console and `wscat` connect without one. `04` §WebSocket was updated in the same change, with the admin-auth
clarifications it now carries (`/admin/console` needs no header; scenario and now-override writes return the
`/admin/state` object; a warning is targeted by lat+lon, district or state; a `now` without an offset is IST). No
message types were added beyond the six in `04`; a client `location` frame gets no acknowledgement — the next
`warning_issued` carries the recomputed `affects_you`. Verified:
`backend/tests/test_ws_admin.py::test_ws_rejects_a_bad_token`, `test_ws_location_message_moves_the_client`.

**Devices and push are additive, and push messages are data-only.** `/health` gained `push:{transport,devices}`;
`/admin/state` gained `devices` and `push_transport`; `POST /me/devices`, `DELETE /me/devices/{token}` and
`GET /admin/devices` are new and optional. Nothing existing changed shape. Messages carry no `notification` block
on purpose: an OS-rendered notification would be in whatever language the server picked, while the app has five
locales and the strings already, so it builds the notification from `data` (`Device.lang`); the iOS trade-off is
in [`09_PUSH_NOTIFICATIONS.md`](09_PUSH_NOTIFICATIONS.md) §3 and §6. Verified:
`backend/tests/test_push.py::test_health_reports_the_push_block`.

**A registration token identifies an install, not a user.** `POST /me/devices` is an upsert on the token; a
token reappearing under another account moves to it (the handset changed hands). Deletion is ownership-checked,
and tokens are redacted to their last six characters in logs and in `GET /admin/devices` — a push token is a
send-capability. Verified: `backend/tests/test_push.py::test_a_device_can_only_be_deleted_by_its_owner`.

---

## Personalization engine (docs/03)

**Test 7 asserts every *ungated* coverage card, not "≥ 3 of the persona's own cards".** Spec: `03` §Tests 7,
under `clear_pleasant`. That scenario removes every hazard, so hazard-gated coverage cards (`warnings`,
`rain_alert`, `storm_fog_alert`, `frost_alert`, `heat_alert`) do not exist — parent has 1 ungated card of 3,
commuter 2 of 3. The test asserts every ungated coverage card reaches the top 8 (identical for six personas,
stronger for the other two); loosening the gates was rejected, a rain alert with no rain being false. Verified:
`backend/tests/test_engine.py::test_7_every_persona_gets_three_of_its_own_cards_in_the_top_eight`.

**`Card.score` is not in 0..1.** `03` §Algorithm is `0.5·rel·ctx + 0.5·urg + eng` plus pin/urgency boosts; the
pinned `school_commute` in `fixtures/home_severe.json` scores 1.175. `04` only showed an example value and now
says the field is opaque; the app shows it as text in the why sheet, never as a bar. Verified: `app/test/fixtures_test.dart`.

**Ranker v2 is plain-Python SGD; scikit-learn was not added.** The feature vector is ~15 non-zero entries and
training is capped, so a library would buy nothing and cost a wheel on every deploy; `engine/ml.py` is sparse
logistic SGD and `requirements.txt` is unchanged. `03` §Learning (v2) was rewritten to match. Verified: `backend/tests/test_ml.py`.

- **`is_coastal` is not a feature.** It is a hard gate in the catalog, not a preference, and not recoverable from
  a logged event — the training row would be a constant whose weight never leaves 0.
- **The urgency band trains only from `meta.urgency`, which the app does not send today.** Every event lands in
  `urg:unknown`, so the real bands stay at 0 until the client adds the optional field (`04` §Ranker v2). It is
  deliberately not inferred from the live urgency at prediction time — a learned weight on urgency is exactly
  what the bound exists to prevent.

**Two cold starts, not one.** Beyond `MIN_EVENTS = 8`, a card type the user has never interacted with stays at
`p_tap = 0.5`. A model fitted on one sparse log spends its always-on features as a "cards are usually not tapped"
prior, so an unseen card would come back near `p = 0.2`, be demoted and be labelled "Learned from what you skip"
without ever having been on screen. Class balancing (`ml.balance`) is kept but does not fix this alone. Verified:
`backend/tests/test_ml.py::test_an_untrained_card_type_stays_on_the_v1_score`.

**Each positive is paired with one sampled negative.** Implicit feedback needs negatives, and a user who only taps
produces none — ten taps on `aqi` would lift every card equally. The negative is a card type the user has never
engaged with, rotated deterministically through the sorted candidate list (no RNG). Verified:
`backend/tests/test_ml.py::test_same_events_produce_the_same_weights`.

**The learned term applies only to unpinned, non-hero cards.** The cleanest statement of the bound (learning only
reorders the non-urgent part of the feed); the hero is lifted out of the ranking, so a learned term there would
move nothing while still claiming a line in the why sheet. Verified:
`backend/tests/test_ml.py::test_the_maximal_term_never_reorders_across_the_pinned_block`.

**`HomeResponse.engine` is unchanged with the flag on** — still `{"version": "1.0", "weights": {…}}`, or the "flag
on, no events → byte-identical" proof of the cold start would break. The flag is reported by `/health`
(`engine.ml`) and `/admin/state` (`engine_ml`); the per-card contribution surfaces through `reasons`
(`learning:up` / `learning:down`). Verified: `backend/tests/test_ml.py::test_health_and_admin_state_report_the_flag`.

---

## Card catalog (docs/02)

**`school_commute` gained `late`,`night` ×0.5 on weekdays.** Without it the card scores 0.5 all night and `03`
§Tests 5 ("at 22:00 it is not in the top 3") is unsatisfiable. Card 22 was updated in the same change; every other
multiplier is as written. Verified:
`backend/tests/test_engine.py::test_5_parent_sees_school_commute_in_the_morning_not_at_night`.

**`hourly_forecast.data.hours` is not always 24.** Card 4 says `hours[24]`; the engine emits what is left of its
48-hour window from `now` — 17 entries at 07:30 — and 12 under `?lite=1`. Renderers read the list length.
Verified: `backend/tests/test_home_api.py::test_lite_trims_arrays_and_drops_more_cards`.

---

## Flutter app (docs/06)

**The bundled sample is a byte-for-byte copy of `fixtures/home_severe.json`.** Spec: `06` §Layout allows a
hand-written fallback payload. Built: real engine output beats a transcription, so
`app/assets/fixtures/home_sample.json` is copied from the corpus. Consequence: the offline demo is parent / New
Delhi / `scenario=thunderstorm` (orange banner, four pinned cards). Verified: `QA_REPORT.md` Step 7,
[`c1_step07_offline_sample_data.png`](../assets/screenshots/c1_step07_offline_sample_data.png).

**The re-rank animation is a keyed list plus `flutter_animate` only.** `06` §Packages offers
`animated_reorderable_list` / `great_list_view` "if it builds on the installed Flutter", with the keyed list as the
documented fallback; the fallback shipped, with no package beyond `flutter_animate` 4.5.2. Verified:
[`c1_step05_ws_rerank.png`](../assets/screenshots/c1_step05_ws_rerank.png).

- **Card detail is a pushed page**, `features/home/detail/card_detail_page.dart`, as `06` §Layout specifies; an
  earlier modal stand-in was deleted.
- **`RendererRegistry.pending` is an empty set rather than removed**: `app/test/fixtures_test.dart` asserts
  against `implemented ∪ pending`, so a new renderer kind can be declared before it exists.
- **`RadarRenderer.tileProviderFactory` is a static test hook**: `fixtures_test.dart` sets it to a provider
  returning a 1×1 transparent PNG so the radar card runs without the network; production leaves it `null`.
- **`TimeWindow` existed twice** (`data/models/user.dart` and the settings repository); the model's copy won and
  gained `copyWith` plus the `04` defaults.
- **Changing a saved place's `kind` is `DELETE` + `POST`.** `04` has no update route for `/me/places`; inventing
  one would have been a contract change. Verified: `QA_REPORT.md` Step 9.
- **The warning banner's foreground colour is derived from the background's luminance.** White on IMD yellow
  (`#F5C518`) and orange (`#F28C28`) fails WCAG AA. Verified: `app/test/accessibility_test.dart` runs
  `textContrastGuideline` over the whole home screen.
- **One `_FeedStatus` strip replaces two stacked banners**, with a fixed priority — bundled sample → offline →
  stale cache — so the wording always matches what is on screen. Verified:
  [`c1_step07_offline_cached.png`](../assets/screenshots/c1_step07_offline_cached.png).
- **No `firebase_messaging` in the app.** Adding it without a `google-services.json` breaks `flutter build apk`,
  and that file cannot be committed. The app side is documented in `backend/README.md` §Push notifications and
  [`09_PUSH_NOTIFICATIONS.md`](09_PUSH_NOTIFICATIONS.md) §9; the WebSocket remains the demo transport.

**The tides card draws an interpolated curve between the published turning points.** Spec: card 17 publishes
`events[≤4]`; `06` asks for a 24-hour tide curve. Built: `TideCurve.of` (`renderers/tides.dart`) samples a
half-cosine between consecutive extremes every 20 minutes — the same family of model the backend uses. Markers sit
on the published points; the card shows the "Estimated" pill and the backend `disclaimer`
([`00_VISION.md`](00_VISION.md), principle 6). Verified:
[`c1_step04_coastal_tides_estimated.png`](../assets/screenshots/c1_step04_coastal_tides_estimated.png).

**Radar tile layers set `maxNativeZoom` (RainViewer 7, OSM 19).** RainViewer answers HTTP 200 above z7 with a PNG
reading "Zoom Level Not Supported", so `errorTileCallback` never fired and the placeholder was painted over the
map from one pinch in (`initialZoom` is 7); flutter_map now upscales the z7 tile. Verified:
`app/test/fixtures_test.dart` (`RadarMap.radarMaxNativeZoom`).

**Two display-only statics: `Fmt.imperial` and `RadarRenderer.tilesEnabled`.** Renderers must work in widget
tests built outside a `ProviderScope`, so units and low-bandwidth are statics that `SettingsNotifier` alone writes
(`hydrate()`, `update()`); threading them through fifteen renderer constructors buys nothing the notifier does not
already guarantee. `units: imperial` is itself display-only — the API always answers in metric (`04` preamble),
`Fmt.temp` / `Fmt.kph` / `MetricRenderer` convert on screen, and `PUT /me/profile` records the user's choice.
Verified: `app/test/renderers_test.dart`.

**`Card.data` enum values are localized on the device, not by the backend.** `04` localizes titles, subtitles,
insights and reasons via `lang` and leaves enum values in `data` (`sea_state`, `risk`, `impact`, `intensity`,
`status`, `category`, window labels, hazards, seasons) as identifiers. `lib/l10n/labels.dart` maps them to ARB
strings with a `Fmt.humanize` fallback, so a value a later backend adds still reads as words; `GaugeSpec.of`,
`AlertSpec.of`, `BarChartSpec.of`, `TimelineWindow.parse` and `AdviceGroup.parse` take an `L`. `levelLabel` keeps
`medium` and `moderate` distinct (`02` uses both) and `qualityLabel` resolves the `good|caution|poor|avoid` ladder
of cards 22 and 28. Verified: `app/test/l10n_test.dart` ("the data-value label helpers cover the docs/02 enums…").

**Two alert ladders are translated on the device (D4).** `levelLabel` knew only
`none|low|medium|moderate|high|severe`; card 15 `heat_alert.level` is the NWS ladder
(`caution|extreme_caution|danger|extreme_danger`) and card 30 `storm_fog_alert.level` is `watch|warning|severe`.
Both fell through to `Fmt.humanize`, so under `?lang=hi` the heat card read "Extreme Caution" under
"अत्यधिक सावधानी" and the fog card read "कोहरा warning". Six ARB keys in `en` and `hi`, six arms in `levelLabel`.
Verified: `app/test/l10n_test.dart` ("every alert-card band docs/02 publishes is translated, not humanized"),
[`c1_step08_hindi_cards.png`](../assets/screenshots/c1_step08_hindi_cards.png).

**`mr`, `ta` and `bn` are partial: 69 app keys each, per-key fallback to English.** `05` §i18n allows partial
languages; the three carry the chrome a reviewer sees, and `flutter gen-l10n` prints "untranslated message(s)" for
each — the documented best-effort state, not a build error. Only `en` and `hi` are complete. Verified:
`app/test/l10n_test.dart`; `QA_REPORT.md` → Known limitations 2.

**Chip and copy ownership (D2).** `tides` drew an "Estimated" pill that the card shell and detail header already
draw from `card.estimated`; `timeline` drew `data.advice`, which the engine reuses verbatim as `insight.detail`.
Both renderers defer to the host when the host already shows it; `06` §Renderers records the rule. Verified:
`app/test/renderers_test.dart` ("tides leaves the Estimated chip to the card shell", "timeline does not repeat the
advice…"); `QA_REPORT.md` Step 4.

**Timeline windows are sorted by the clock (D8).** Card 22 publishes each window's *next occurrence*, so after
09:00 `morning_drop` is tomorrow while `afternoon_pickup` is today; the bar drew them chronologically while the
rows followed payload order, over an axis reading 12:30 → 09:30. The renderer now sorts by start time and prefixes
a window on a later day with that day ("Tomorrow 07:00 – 09:00"); `06` §Renderers updated. Verified:
`app/test/renderers_test.dart` ("timeline orders windows by the clock…").

### Home-screen widget (`06` §Home-screen widget)

**Three install-time permissions arrive through the manifest merge.** The widget adds none of its own, but
`home_widget`'s dependencies (`androidx.work`, `androidx.glance`) merge in `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`
and `FOREGROUND_SERVICE` — normal permissions, never prompted (the earlier release APK had only INTERNET, location
and network-state). WorkManager needs the first two, so they are kept rather than stripped with
`tools:node="remove"`. No new dangerous permission.

**The hourly refresh is WorkManager in Kotlin, not the plugin's Dart background callback.** `home_widget`'s
callback fires on a click and its `scheduleWidgetUpdates` only redraws — neither fetches. `MausamWidgetWorker.kt`
does `GET /home?lite=1` itself, at the cost of an `org.json` parser (`WidgetSnapshot.kt`) that must stay in step
with the Dart serializer; both are pinned by the round-trip test and the shared `v` schema version. Verified:
`app/test/widget_snapshot_test.dart` ("the keys written to shared storage match the Kotlin side").

- **`updated_at` is the payload's newest `freshness` timestamp, not the write time**, so a cache replay shows the
  true age of the reading and can be born stale.
- **The bundled sample is never published to the widget.** A launcher tile has no room for a "Sample data" chip
  and modelled data must not look observed; with no snapshot the widget says "Open Mausam to refresh". Verified:
  `widget_snapshot_test.dart` ("but never publishes the bundled sample payload").
- **`updatePeriodMillis` is 0.** Redraws come from the app (every `/home` payload) and the hourly worker; the age
  label is correct at every redraw, not every minute.
- **One provider serves both size classes**, chosen from `OPTION_APPWIDGET_MIN_HEIGHT` rather than the API 31
  `RemoteViews(Map<SizeF, RemoteViews>)` constructor. The 4x1 layout omits `widget_pinned_title` and the renderer
  skips that id (RemoteViews throws on a missing id).
- **`mausam://card/<type>` is resolved by the home page against the loaded feed**, not by the router — details
  are pushed with `MaterialPageRoute`. A type absent from the payload falls back to plain home. Verified:
  `widget_snapshot_test.dart` ("the pinned row names the card to open…").

---

## Build, toolchain and CI

**`minSdk` is 24 (Android 7.0), not 23.** Flutter 3.47's `MinSdkVersionMigration` rewrites any hardcoded `minSdk`
of 16–23 back to `flutter.minSdkVersion` on every build, so 23 cannot survive. `06` §Android config was updated in
place. Observable: `app/android/app/build.gradle.kts`; `QA_REPORT.md` → Release APK sanity check.

**`compileSdk = 37` is pinned.** `permission_handler_android` 14.1.0 fails the AAR-metadata check against 36; AGP
warns "maximum recommended compile SDK … is 36" and builds anyway. On Windows, SDK platform 37 installs as
`android-37.0` and needs an `android-37` directory junction or the release APK build fails. Observable:
`app/android/app/build.gradle.kts`.

**The release APK is signed with the debug key unless `android/key.properties` exists.** `build.gradle.kts` uses
a `release` signing config when the keystore properties are present and `debug` otherwise, so
`flutter build apk --release` works on a machine with no secrets — which is what `.github/workflows/flutter.yml`
builds. A Play-store build needs a real keystore. See `QA_REPORT.md` → Known limitations 8.

**`home_widget` 0.9.4 still applies the Kotlin Gradle Plugin.** Every Android build prints "Your app uses the
following plugins that apply Kotlin Gradle Plugin (KGP): home_widget …". It is a warning: builds succeed on Flutter
3.47.2 with `android.builtInKotlin=false` in `app/android/gradle.properties`. If a later Flutter drops that escape
hatch, the fallback is a plain `AppWidgetProvider` + MethodChannel — the Kotlin side is already hand-written; only
`saveWidgetData` / `updateWidget` / the launch URIs would need replacing.

- **`--dart-define=BACKEND_URL=<origin>` sets the default backend at build time.** `06` §Layout has `config.dart`
  default to localhost / `10.0.2.2` / the last saved URL; `core/config.dart` also reads `BACKEND_URL` so a
  sideloaded demo APK reaches a deployed backend with no trip through Settings, which still overrides it.

---

## Demo behaviour

**Admin warnings are stamped with the effective demo clock** (`now_override` when set, else real IST), not
`datetime.now(UTC)`. Otherwise a warning pushed while the console's clock sits at 07:30 on the demo day is already
"expired" against the snapshot's reference time and never reaches `/home`. Verified:
`backend/tests/test_ws_admin.py::test_admin_warning_is_pinned_on_home_with_a_banner`.

**`Snapshot.current` is read off the forecast hour matching `now_override`.** `00` §Judge demo script puts the
home at 07:30, but `/home` kept Open-Meteo's live `current` block, so the hero drew a moon over a dawn feed and
every derived metric disagreed with `context.now`. `services/snapshot.normalize_forecast(..., ref_now=)` (and
`normalize_air`) now select the matching hour. Without a demo clock nothing changes — live data stays the real
observation ([`00_VISION.md`](00_VISION.md), principle 6). Verified:
`backend/tests/test_snapshot.py::test_demo_clock_reads_current_off_that_hour`.

**The demo clock only moves the reading when a forecast hour actually matches (D7).** An out-of-range
`now_override` used to be snapped to midnight of the first forecast day and published under the requested
timestamp, so a "07:30" demo drew a moon with UV 0 over a sunrise-lit feed. Out of range, the live observation
stands and `current.time` reports the live time; `fetched_at` and `context.now` still carry the requested clock,
so the *ranking* is unaffected. Verified: `QA_REPORT.md` → Known limitations 7;
`backend/tests/test_snapshot.py::test_demo_clock_outside_the_forecast_window_keeps_the_live_reading`.

**The demo sheet's scenario list is the backend's scenario files, hardcoded (D3).** `05` §Scenarios names ten and
`04` publishes no listing route, so `features/demo/demo_sheet.dart` keeps one static list. It had also offered
`cold_wave`, for which no `backend/app/data/scenarios/cold_wave.json` exists — an unknown scenario is answered with
live data, so the chip highlighted and nothing changed. Removed; a scenario added to the backend must be added to
the sheet too. Verified: `app/test/demo_sheet_test.dart` ("every scenario chip has a scenario file behind it");
[`c1_extra_demo_sheet.png`](../assets/screenshots/c1_extra_demo_sheet.png).

**Clock presets and the time picker are built on today, not a hardcoded date (D5).** `DemoSheet.clockPresets` is
computed from today's date (`clockHours` × `presetFor`); the earlier literals carried a fixed day, so from the next
day every preset fell outside the forecast window and the entry above silently took over. The "Pick a time" chip
stamped the same literal and now uses `presetFor` too; chip labels are unchanged (`07:30 · 13:00 · 18:30 · 22:00`).
Verified: `app/test/demo_sheet_test.dart` pins `presetFor` to today and greps `demo_sheet.dart` for any
`'20xx-xx-xxT` literal.

**Scenario chip labels keep acronyms (D6).** `DemoSheet.scenarioLabel` carries a one-entry acronym map so
`severe_aqi` reads "Severe AQI", not "Severe Aqi", beside a card the app titles "AQI". `Fmt.humanize` was left
alone — it is the fallback for backend enums, and `app/test/l10n_test.dart` pins its "Volcanic Ash" behaviour.
Verified: `app/test/demo_sheet_test.dart`.

**`FreshnessChip` ages the payload against the effective demo clock** — the demo sheet's override, an admin
`now_override` frame off `/ws/alerts`, else the live payload's own `context.now` — not the device clock. The
backend stamps `freshness` with `now_override`, so a reviewer moving the clock to 07:30 otherwise saw "Updated 16 h
ago" on fresh data. A cached or bundled payload has no usable clock of its own and still ages against the device,
the "Updated 12 min ago" `06` asks for. Verified: `app/test/freshness_chip_test.dart`.

**Documentation: demo-clock examples use `$(date +%F)`, and screenshot grids use the `c1_*` shots.** Three
copy-paste `now_override` examples once carried a fixed date, which on any later day is a clock that appears to do
nothing; they now build the date at run time. App-side literals are guarded by `demo_sheet_test.dart`; no test
guards Markdown, so a future date literal in a doc is on the reviewer to catch. Separately, the `b2b_*` persona
shots in [`../assets/screenshots/`](../assets/screenshots/) pre-date D2, D8 and D9 and can show the bugs those
fixed; a grid should use `c1_step03_persona_*.png`, `c1_step05_ws_*.png`, `c1_step08_hindi_home.png` and
`c1_step07_offline_cached.png` (`b2b_map.png` remains valid — the map page was untouched by those fixes).

---

## How to record a new deviation

1. Edit the spec section in `docs/0x_*.md` in the same change, so the doc stays normative.
2. Add an entry here under exactly one area: bold title, then Spec → Built → Why → Where verified.
3. Add or update the test (or the `QA_REPORT.md` step) the entry cites, so the deviation cannot silently revert.
