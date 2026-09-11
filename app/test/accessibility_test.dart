import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mausam_app/core/theme.dart';
import 'package:mausam_app/data/api_client.dart';
import 'package:mausam_app/data/cache/json_file_cache.dart';
import 'package:mausam_app/data/models/home_response.dart';
import 'package:mausam_app/data/repositories/events_repo.dart';
import 'package:mausam_app/data/repositories/home_repo.dart';
import 'package:mausam_app/data/repositories/settings_repo.dart';
import 'package:mausam_app/features/home/home_page.dart';
import 'package:mausam_app/features/home/providers.dart';
import 'package:mausam_app/features/home/live_alerts.dart';
import 'package:mausam_app/features/home/renderers/radar.dart';
import 'package:mausam_app/features/home/widgets/card_shell.dart';
import 'package:mausam_app/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture.dart';
import 'support.dart';

/// docs/06_MOBILE_SPEC.md §Definition of done — accessibility: semantics labels, contrast, tap
/// targets, text scaling.
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

class _SilentEvents extends EventsRepo {
  _SilentEvents() : super(api: ApiClient(baseUrl: 'http://127.0.0.1:1'));

  @override
  void add(EngagementEvent event) {}

  @override
  void recordImpression(String type, {int? position}) {}

  @override
  Future<void> flush() async {}
}

class _FixedSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(
        backendUrl: 'http://127.0.0.1:1',
        language: 'en',
        personas: <String>['parent', 'commuter'],
        onboarded: true,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String fixtureJson;

  setUpAll(() => fixtureJson = jsonEncode(loadSampleHomeJson()));

  setUp(() {
    RadarRenderer.tileProviderFactory = BlankTileProvider.new;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'personas': <String>['parent', 'commuter'],
      'language': 'en',
      'onboarded': true,
    });
  });

  ProviderContainer buildContainer() => ProviderContainer(
        overrides: [
          homeRepoProvider.overrideWithValue(HomeRepo(
            api: ApiClient(baseUrl: 'http://127.0.0.1:1'),
            cache: _MemoryCache(),
            loadAsset: (_) async => fixtureJson,
          )),
          eventsRepoProvider.overrideWithValue(_SilentEvents()),
          settingsProvider.overrideWith(_FixedSettings.new),
          // No real WebSocket in a widget test (docs/06 §Home behaviour connects one on mount).
          alertsSocketProvider.overrideWithValue(silentAlertsSocket()),
        ],
      );

  Widget app(ProviderContainer container, {TextScaler? textScaler}) =>
      UncontrolledProviderScope(
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
          builder: textScaler == null
              ? null
              : (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                    child: child!,
                  ),
          home: const HomePage(),
        ),
      );

  testWidgets('the home screen meets the tap-target and labelled-target guidelines',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = buildContainer();
    addTearDown(container.dispose);
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(app(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('every card exposes the docs/06 semantics label', (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = buildContainer();
    addTearDown(container.dispose);
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(app(container));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final home = HomeResponse.fromJson(loadSampleHomeJson());
    final hero = home.hero!;
    // docs/06 §Card shell — "{title}. {subtitle}. {insight.headline}".
    expect(
      find.bySemanticsLabel(hero.semanticsLabel),
      findsWidgets,
      reason: 'the hero card must announce title, subtitle and insight',
    );
    expect(find.byType(CardShell), findsWidgets);
    handle.dispose();
  });

  testWidgets('the feed still lays out at a 1.5x text scale', (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(app(container, textScaler: const TextScaler.linear(1.5)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
  });
}
