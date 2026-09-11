import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mausam_app/core/theme.dart';
import 'package:mausam_app/data/api_client.dart';
import 'package:mausam_app/data/cache/json_file_cache.dart';
import 'package:mausam_app/data/repositories/events_repo.dart';
import 'package:mausam_app/data/repositories/home_repo.dart';
import 'package:mausam_app/data/repositories/profile_repo.dart';
import 'package:mausam_app/data/repositories/settings_repo.dart';
import 'package:mausam_app/features/home/home_page.dart';
import 'package:mausam_app/features/home/providers.dart';
import 'package:mausam_app/features/home/live_alerts.dart';
import 'package:mausam_app/features/home/renderers/radar.dart';
import 'package:mausam_app/features/home/widgets/why_sheet.dart';
import 'package:mausam_app/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture.dart';
import 'support.dart';

/// A cache that lives in memory, so the widget test never touches path_provider.
class _MemoryCache extends JsonFileCache {
  final Map<String, CacheEntry> _store = <String, CacheEntry>{};

  @override
  Future<CacheEntry?> get(String key) async => _store[key];

  @override
  Future<void> put(String key, Map<String, dynamic> data) async {
    _store[key] = CacheEntry(data: data, storedAt: DateTime.now());
  }

  @override
  Future<void> remove(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();
}

/// Engagement events are fire-and-forget telemetry with a 10 s flush timer; in a widget test
/// that timer outlives the tree and trips `!timersPending`. The queue is tested directly in
/// `events_repo_test.dart`.
class _SilentEvents extends EventsRepo {
  _SilentEvents() : super(api: ApiClient(baseUrl: 'http://127.0.0.1:1'));

  @override
  void add(EngagementEvent event) {}

  @override
  void recordImpression(String type, {int? position}) {}

  @override
  Future<void> flush() async {}
}

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L.supportedLocales,
        home: const HomePage(),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String fixtureJson;

  setUpAll(() {
    fixtureJson = jsonEncode(loadSampleHomeJson());
  });

  setUp(() {
    RadarRenderer.tileProviderFactory = BlankTileProvider.new;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'personas': <String>['parent', 'commuter'],
      'language': 'en',
      'onboarded': true,
    });
  });

  /// The home is a lazy `CustomScrollView`: on the default 800x600 test surface only the first
  /// couple of cards are ever built. Give the test a tall viewport so the whole ranked list is
  /// in the tree and the finders below mean what they say. The bundled fixture is the severe
  /// scenario — 4 pinned + hero + 8 ranked cards — so this has to be very tall.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  ProviderContainer buildContainer({ProfileRepo? profileRepo}) {
    // No backend: the repo's network call fails and it falls through to the bundled fixture,
    // which is exactly the "backend switched off" step of the docs/00 demo script.
    final repo = HomeRepo(
      api: ApiClient(baseUrl: 'http://127.0.0.1:1'),
      cache: _MemoryCache(),
      loadAsset: (_) async => fixtureJson,
    );
    return ProviderContainer(
      overrides: [
        homeRepoProvider.overrideWithValue(repo),
        eventsRepoProvider.overrideWithValue(_SilentEvents()),
        settingsProvider.overrideWith(_FixedSettings.new),
        // No real WebSocket in a widget test (docs/06 §Home behaviour connects one on mount).
        alertsSocketProvider.overrideWithValue(silentAlertsSocket()),
        // Only the two card-prefs tests below need this one (docs/04 `GET /me/card-prefs`).
        if (profileRepo != null) profileRepoProvider.overrideWithValue(profileRepo),
      ],
    );
  }

  testWidgets('home renders the fixture: banner, pinned warning, hero and cards',
      (tester) async {
    useTallViewport(tester);
    final container = buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);

    // AppBar shows the location from the payload.
    expect(find.text('New Delhi'), findsWidgets);

    // docs/06 §Home behaviour — the banner appears whenever `banner != null`.
    expect(find.text('Orange warning: thunderstorm with lightning'), findsWidgets);

    // Hero + a persona-driven card are on screen.
    expect(find.text('School run'), findsOneWidget);
    expect(find.textContaining('Feels like'), findsWidgets);

    // Sample-data notice, because there is no backend in this test.
    expect(find.textContaining('Sample data'), findsWidgets);

    // "More for you" expander exists because the fixture has more_cards.
    expect(find.text('More for you'), findsOneWidget);
  });

  testWidgets('persona chips row shows the saved personas first', (tester) async {
    useTallViewport(tester);
    final container = buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.widgetWithText(FilterChip, 'Parent'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Commuter'), findsOneWidget);
    // A persona the user did not pick is offered as an outlined chip (the "role view" entry
    // point in docs/06 §Home behaviour).
    expect(find.widgetWithText(FilterChip, 'Health'), findsOneWidget);
  });

  testWidgets('expanding "More for you" reveals the tail cards', (tester) async {
    useTallViewport(tester);
    final container = buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // `14-day outlook` is in `more_cards`, so it is not in the tree until the tail expands.
    expect(find.text('14-day outlook'), findsNothing);
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(find.text('14-day outlook'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-pressing a card opens the why sheet', (tester) async {
    useTallViewport(tester);
    final container = buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.longPress(find.text('School run'));
    await tester.pumpAndSettle();

    expect(find.text('Why am I seeing this?'), findsOneWidget);
    // The reason text is localized by the backend (docs/03 §Explainability); the app renders
    // whatever string it is handed.
    expect(find.text('Because you follow Parenting'), findsWidgets);
    // Scoped to the sheet: every card also renders its own `actions` row from the
    // payload, and the fixture's `hide` action carries the same localized label.
    expect(
      find.descendant(of: find.byType(WhySheet), matching: find.text('Hide this card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides seeded from /me/card-prefs are applied to the first feed', (tester) async {
    useTallViewport(tester);
    final container = buildContainer(
      profileRepo: _SeededPrefs(const CardPrefs(hidden: <String>['school_commute', 'aqi'])),
    );
    addTearDown(container.dispose);

    // What `main` does once the guest token lands (docs/04 `GET /me/card-prefs`), so a reinstall
    // shows the feed the server already knows about instead of every card the user had hidden.
    await seedCardPrefs(container);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // `school_commute` is pinned in the fixture and `aqi` is a ranked card: both filtered out.
    expect(find.text('School run'), findsNothing);
    expect(find.text('Air quality'), findsNothing);
    // The rest of the feed is untouched.
    expect(find.text('Rain radar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unreachable backend leaves the feed at its defaults', (tester) async {
    useTallViewport(tester);
    // `ProfileRepo.cardPrefs()` returns null on any ApiException — the offline path.
    final container = buildContainer(profileRepo: _SeededPrefs(null));
    addTearDown(container.dispose);

    await seedCardPrefs(container);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(container.read(hiddenCardsProvider), isEmpty);
    expect(find.text('School run'), findsOneWidget);
    expect(find.text('Air quality'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// `/me/card-prefs` without a backend. `null` is what the real repo returns when the call fails.
class _SeededPrefs extends ProfileRepo {
  _SeededPrefs(this.prefs) : super(api: ApiClient(baseUrl: 'http://127.0.0.1:1'));

  final CardPrefs? prefs;

  @override
  Future<CardPrefs?> cardPrefs() async => prefs;
}

/// Settings are normally hydrated from SharedPreferences in `main`; in the test we start from
/// a known profile so the home query is deterministic.
class _FixedSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(
        backendUrl: 'http://127.0.0.1:1',
        language: 'en',
        personas: <String>['parent', 'commuter'],
        onboarded: true,
      );
}
