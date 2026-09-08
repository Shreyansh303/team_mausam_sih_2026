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
import 'package:mausam_app/data/repositories/settings_repo.dart';
import 'package:mausam_app/features/home/home_page.dart';
import 'package:mausam_app/features/home/providers.dart';
import 'package:mausam_app/features/home/widgets/why_sheet.dart';
import 'package:mausam_app/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture.dart';

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
/// that timer outlives the tree and trips `!timersPending`. B2 tests the queue directly.
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

  ProviderContainer buildContainer() {
    // No backend: the repo's network call fails and it falls through to the bundled fixture,
    // which is exactly the "demo with the backend switched off" path docs/07 §B1 asks for.
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
    // Scoped to the sheet: since B2b every card also renders its own `actions` row from the
    // payload, and the fixture's `hide` action carries the same localized label.
    expect(
      find.descendant(of: find.byType(WhySheet), matching: find.text('Hide this card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
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
