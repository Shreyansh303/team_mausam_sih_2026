import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mausam_app/data/api_client.dart';
import 'package:mausam_app/data/cache/json_file_cache.dart';
import 'package:mausam_app/data/models/home_response.dart';
import 'package:mausam_app/data/repositories/home_repo.dart';
import 'package:mausam_app/data/widget/home_widget_bridge.dart';
import 'package:mausam_app/data/widget/widget_snapshot.dart';

import 'fixture.dart';

/// Records what the app would have sent to the Android widget (S2) instead of touching the
/// `home_widget` platform channel.
class FakeWidgetBridge implements HomeWidgetBridge {
  final List<WidgetSnapshot> published = <WidgetSnapshot>[];
  final List<WidgetRefreshConfig?> configs = <WidgetRefreshConfig?>[];

  /// What a widget tap would deliver; the home page listens to this stream.
  final StreamController<Uri?> taps = StreamController<Uri?>.broadcast();
  Uri? initial;

  @override
  Future<void> publish(WidgetSnapshot snapshot, {WidgetRefreshConfig? config}) async {
    published.add(snapshot);
    configs.add(config);
  }

  @override
  Future<Uri?> initialLaunch() async => initial;

  @override
  Stream<Uri?> launches() => taps.stream;
}

/// Serves one `/home` payload, or fails like an unreachable backend.
class _StubApi extends ApiClient {
  _StubApi(this.payload) : super(baseUrl: 'http://127.0.0.1:8000');

  Map<String, dynamic> payload;
  bool fail = false;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    Object? cancelToken,
  }) async {
    calls++;
    if (fail) {
      throw ApiException('Cannot reach the backend.', code: 'unreachable', isNetwork: true);
    }
    return payload;
  }
}

class _MemoryCache extends JsonFileCache {
  final Map<String, CacheEntry> store = <String, CacheEntry>{};

  @override
  Future<CacheEntry?> get(String key) async => store[key];

  @override
  Future<void> put(String key, Map<String, dynamic> data) async {
    store[key] = CacheEntry(data: data, storedAt: DateTime.now());
  }

  @override
  Future<void> remove(String key) async => store.remove(key);

  @override
  Future<void> clear() async => store.clear();
}

/// Rewrites a payload so it looks like `?lang=hi` output: Devanagari strings in every place the
/// snapshot copies from, and `context.lang` set accordingly.
Map<String, dynamic> _hindiPayload(Map<String, dynamic> base) {
  final json = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
  (json['context'] as Map<String, dynamic>)['lang'] = 'hi';
  (json['location'] as Map<String, dynamic>)['name'] = 'नई दिल्ली';
  final hero = json['hero'] as Map<String, dynamic>;
  (hero['data'] as Map<String, dynamic>)['condition_text'] = 'गरज के साथ बौछार';
  final pinned = (json['pinned'] as List<dynamic>).first as Map<String, dynamic>;
  pinned['title'] = 'मौसम चेतावनियाँ';
  (pinned['insight'] as Map<String, dynamic>)['headline'] =
      'ऑरेंज चेतावनी: बिजली के साथ गरज';
  return json;
}

void main() {
  late Map<String, dynamic> sample;

  setUp(() {
    sample = loadSampleHomeJson();
  });

  group('WidgetSnapshot.fromHome', () {
    test('takes the hero card and the top pinned card — pinned beats ranked', () {
      final home = HomeResponse.fromJson(sample);
      final snapshot = WidgetSnapshot.fromHome(home);

      expect(home.pinned, isNotEmpty, reason: 'the severe fixture pins four cards');
      expect(home.cards, isNotEmpty);
      expect(snapshot.pinned!.type, home.pinned.first.type);
      expect(snapshot.pinned!.type, isNot(home.cards.first.type));

      expect(snapshot.hero, isNotNull);
      expect(snapshot.hero!.tempC, home.hero!.data['temp_c']);
      expect(snapshot.hero!.condition, home.hero!.data['condition_text']);
      expect(snapshot.locationName, 'New Delhi');
      expect(snapshot.updatedAt, home.newestFreshness);
      expect(snapshot.isEmpty, isFalse);
    });

    test('falls back to the top ranked card when nothing is pinned', () {
      final home = HomeResponse.fromJson(<String, dynamic>{...sample, 'pinned': <dynamic>[]});
      final snapshot = WidgetSnapshot.fromHome(home);

      expect(snapshot.pinned!.type, home.cards.first.type);
      expect(snapshot.pinned!.insight, home.cards.first.insight!.headline);
    });

    test('a warnings card carries the IMD warning colour, not the card severity band', () {
      // docs/04 §Objects `Warning.color_hex`. The severe fixture's warning is orange.
      final warningsCard = HomeResponse.fromJson(sample)
          .allCards
          .firstWhere((c) => c.type == 'warnings');
      final home = HomeResponse.fromJson(<String, dynamic>{
        ...sample,
        'pinned': <dynamic>[warningsCard.toJson()],
      });

      final snapshot = WidgetSnapshot.fromHome(home);
      expect(snapshot.pinned!.type, 'warnings');
      expect(snapshot.pinned!.colorHex, '#F28C28');
      expect(snapshot.pinned!.severity, 'warning');
    });

    test('severity bands colour every other card type', () {
      HomeResponse pinnedWith(String severity) => HomeResponse.fromJson(<String, dynamic>{
            ...sample,
            'pinned': <dynamic>[
              <String, dynamic>{'type': 'aqi', 'title': 'Air quality', 'severity': severity},
            ],
          });

      expect(WidgetSnapshot.fromHome(pinnedWith('severe')).pinned!.colorHex, '#D32F2F');
      expect(WidgetSnapshot.fromHome(pinnedWith('warning')).pinned!.colorHex, '#F28C28');
      expect(WidgetSnapshot.fromHome(pinnedWith('watch')).pinned!.colorHex, '#F5C518');
      expect(WidgetSnapshot.fromHome(pinnedWith('info')).pinned!.colorHex, '#1565C0');
    });

    test('an estimated card is labelled as such (honest-data principle)', () {
      final home = HomeResponse.fromJson(sample);
      // The severe fixture pins commute_conditions, which is modelled, not observed.
      expect(home.pinned.first.isEstimated, isTrue);
      expect(WidgetSnapshot.fromHome(home).pinned!.estimated, isTrue);
    });

    test('an empty payload produces an empty snapshot', () {
      final home = HomeResponse.fromJson(<String, dynamic>{
        'generated_at': '',
        'location': <String, dynamic>{},
        'context': <String, dynamic>{},
      });
      final snapshot = WidgetSnapshot.fromHome(home);

      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.hero, isNull);
      expect(snapshot.pinned, isNull);
      expect(jsonDecode(jsonEncode(snapshot.toJson()))['hero'], isNull);
    });

    test('a Hindi payload round-trips through the shared-storage JSON', () {
      final home = HomeResponse.fromJson(_hindiPayload(sample));
      final snapshot = WidgetSnapshot.fromHome(home);

      // Exactly what the Kotlin side reads back out of shared storage.
      final encoded = jsonEncode(snapshot.toJson());
      final decoded = WidgetSnapshot.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(decoded.lang, 'hi');
      expect(decoded.locationName, 'नई दिल्ली');
      expect(decoded.hero!.condition, 'गरज के साथ बौछार');
      expect(decoded.pinned!.title, 'मौसम चेतावनियाँ');
      expect(decoded.pinned!.insight, 'ऑरेंज चेतावनी: बिजली के साथ गरज');
      expect(decoded.pinned!.colorHex, snapshot.pinned!.colorHex);
      expect(decoded.updatedAt, snapshot.updatedAt);
      expect(jsonDecode(encoded)['v'], WidgetSnapshot.schemaVersion);
    });

    test('the language and units of the request travel with the snapshot', () {
      final home = HomeResponse.fromJson(sample);
      final snapshot = WidgetSnapshot.fromHome(home, lang: 'hi', units: 'imperial');

      expect(snapshot.lang, 'hi');
      expect(snapshot.units, 'imperial');
    });
  });

  group('HomeRepo publishes to the widget', () {
    const query = HomeQuery(lat: 28.61, lon: 77.21, personas: <String>['parent'], lang: 'en');

    test('on every successful network load, with the config the worker needs', () async {
      final bridge = FakeWidgetBridge();
      final api = _StubApi(sample)..token = 'guest-token';
      final repo = HomeRepo(
        api: api,
        cache: _MemoryCache(),
        widgetBridge: bridge,
        units: 'metric',
      );

      final result = await repo.load(query);
      expect(result.source, HomeSource.network);
      expect(bridge.published, hasLength(1));
      expect(bridge.published.single.locationName, 'New Delhi');

      final config = bridge.configs.single!;
      expect(config.backendUrl, 'http://127.0.0.1:8000');
      expect(config.token, 'guest-token');
      expect(config.lat, 28.61);
      expect(config.lon, 77.21);
      expect(config.personas, <String>['parent']);
      expect(config.lang, 'en');
      expect(config.units, 'metric');

      await repo.load(query);
      expect(bridge.published, hasLength(2), reason: 'every load republishes');
    });

    test('and again when the payload comes from the cache', () async {
      final bridge = FakeWidgetBridge();
      final api = _StubApi(sample);
      final cache = _MemoryCache();
      final repo = HomeRepo(api: api, cache: cache, widgetBridge: bridge);

      await repo.refresh(query); // seeds the cache
      bridge.published.clear();

      api.fail = true;
      final result = await repo.load(query);

      expect(result.source, HomeSource.cache);
      expect(bridge.published, isNotEmpty);
      expect(bridge.published.last.hero, isNotNull);
    });

    test('but never publishes the bundled sample payload', () async {
      final bridge = FakeWidgetBridge();
      final api = _StubApi(sample)..fail = true;
      final repo = HomeRepo(
        api: api,
        cache: _MemoryCache(),
        widgetBridge: bridge,
        loadAsset: (_) async => jsonEncode(sample),
      );

      final result = await repo.load(query);

      expect(result.source, HomeSource.fixture);
      expect(bridge.published, isEmpty);
    });

    test('the keys written to shared storage match the Kotlin side', () {
      const config = WidgetRefreshConfig(
        backendUrl: 'http://10.0.2.2:8000',
        lat: 15.49,
        lon: 73.83,
        token: 't',
        personas: <String>['beach', 'traveler'],
        lang: 'hi',
        units: 'metric',
      );

      expect(config.toKeyValues(), <String, String>{
        'mausam_backend_url': 'http://10.0.2.2:8000',
        'mausam_token': 't',
        'mausam_lat': '15.49',
        'mausam_lon': '73.83',
        'mausam_personas': 'beach,traveler',
        'mausam_lang': 'hi',
        'mausam_units': 'metric',
      });
      expect(HomeWidgetKeys.snapshot, 'mausam_snapshot');
      expect(HomeWidgetKeys.providerClass, 'com.teammausam.mausam_app.MausamWidgetProvider');
    });
  });

  group('widget tap deep links', () {
    test('the pinned row names the card to open; the card itself opens home', () {
      expect(widgetLaunchCardType(Uri.parse('mausam://card/warnings')), 'warnings');
      expect(widgetLaunchCardType(Uri.parse('mausam://card/school_commute')), 'school_commute');
      expect(widgetLaunchCardType(Uri.parse('mausam://home')), isNull);
      expect(widgetLaunchCardType(Uri.parse('mausam://card/')), isNull);
      expect(widgetLaunchCardType(Uri.parse('https://example.com/card/warnings')), isNull);
      expect(widgetLaunchCardType(null), isNull);
    });
  });
}
