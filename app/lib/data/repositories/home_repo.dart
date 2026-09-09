import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/config.dart';
import '../api_client.dart';
import '../cache/json_file_cache.dart';
import '../models/home_response.dart';
import '../widget/home_widget_bridge.dart';
import '../widget/widget_snapshot.dart';

/// Where the `HomeResponse` on screen came from — drives the freshness chip and the banners.
enum HomeSource { network, cache, fixture }

class HomeResult {
  const HomeResult({
    required this.home,
    required this.source,
    this.storedAt,
    this.error,
  });

  final HomeResponse home;
  final HomeSource source;

  /// When [source] is cache, the moment the payload was written.
  final DateTime? storedAt;

  /// Set when a refresh failed but we still have something to show (docs/06 §Home behaviour:
  /// "Errors keep cache and show a small banner with retry").
  final String? error;

  bool get isLive => source == HomeSource.network;
  bool get isFixture => source == HomeSource.fixture;
}

/// Identifies one home request; also the cache key.
class HomeQuery {
  const HomeQuery({
    required this.lat,
    required this.lon,
    this.personas = const <String>[],
    this.lang = 'en',
    this.scenario,
    this.nowOverride,
    this.eventDate,
    this.lite = false,
  });

  final double lat;
  final double lon;

  /// Overrides the profile personas for this request only (docs/04 §GET /home params).
  final List<String> personas;
  final String lang;
  final String? scenario;
  final String? nowOverride;
  final String? eventDate;
  final bool lite;

  Map<String, dynamic> toQueryParameters() => <String, dynamic>{
        'lat': lat,
        'lon': lon,
        if (personas.isNotEmpty) 'personas': personas.join(','),
        'lang': lang,
        if (scenario != null) 'scenario': scenario,
        if (nowOverride != null) 'now_override': nowOverride,
        if (eventDate != null) 'event_date': eventDate,
        if (lite) 'lite': 1,
      };

  String get cacheKey =>
      'home_${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}_${personas.join('-')}_$lang';

  @override
  bool operator ==(Object other) =>
      other is HomeQuery &&
      other.lat == lat &&
      other.lon == lon &&
      other.lang == lang &&
      other.scenario == scenario &&
      other.nowOverride == nowOverride &&
      other.eventDate == eventDate &&
      other.lite == lite &&
      other.personas.join(',') == personas.join(',');

  @override
  int get hashCode => Object.hash(
      lat, lon, lang, scenario, nowOverride, eventDate, lite, personas.join(','));
}

/// docs/06_MOBILE_SPEC.md §Layout `home_repo (cache-first + refresh)`.
///
/// Resolution order for a home payload:
///   1. `GET /home` from the backend (and write it to the cache);
///   2. the cached copy of the same query;
///   3. `assets/fixtures/home_sample.json` — the bundled sample so the app is never a blank
///      screen during a demo with no backend. It is a byte-for-byte copy of A2's real
///      `docs/fixtures/home_severe.json` (parent, New Delhi, `scenario=thunderstorm`), not a
///      hand-written payload; refresh it from that file whenever the contract moves.
class HomeRepo {
  HomeRepo({
    required ApiClient api,
    JsonFileCache? cache,
    Future<String> Function(String)? loadAsset,
    HomeWidgetBridge? widgetBridge,
    this.units = 'metric',
  })  : _api = api, // ignore: prefer_initializing_formals
        _cache = cache ?? JsonFileCache(),
        _loadAsset = loadAsset ?? rootBundle.loadString,
        _widget = widgetBridge ?? defaultHomeWidgetBridge();

  final ApiClient _api;
  final JsonFileCache _cache;
  final Future<String> Function(String) _loadAsset;

  /// docs/06 §Home-screen widget — every real payload is mirrored to the Android widget.
  final HomeWidgetBridge _widget;

  /// `metric` | `imperial`; the widget formats its own temperature, so it needs to be told.
  String units;

  Map<String, dynamic>? _fixtureCache;

  /// Cache first if available, then the network. [preferCache] returns immediately with a
  /// cached copy when there is one, leaving the caller to trigger [refresh].
  Future<HomeResult?> cached(HomeQuery query) async {
    final entry = await _cache.get(query.cacheKey);
    if (entry == null) return null;
    try {
      final home = HomeResponse.fromJson(entry.data);
      await _publishToWidget(home, query);
      return HomeResult(
        home: home,
        source: HomeSource.cache,
        storedAt: entry.storedAt,
      );
    } catch (_) {
      await _cache.remove(query.cacheKey);
      return null;
    }
  }

  /// Full resolution: network → cache → bundled fixture. Never throws.
  Future<HomeResult> load(HomeQuery query) async {
    try {
      return await refresh(query);
    } on ApiException catch (e) {
      final fromCache = await cached(query);
      if (fromCache != null) {
        return HomeResult(
          home: fromCache.home,
          source: HomeSource.cache,
          storedAt: fromCache.storedAt,
          error: e.message,
        );
      }
      return HomeResult(home: await loadFixture(), source: HomeSource.fixture, error: e.message);
    } catch (e) {
      final fromCache = await cached(query);
      if (fromCache != null) {
        return HomeResult(
          home: fromCache.home,
          source: HomeSource.cache,
          storedAt: fromCache.storedAt,
          error: '$e',
        );
      }
      return HomeResult(home: await loadFixture(), source: HomeSource.fixture, error: '$e');
    }
  }

  /// Hits `GET /home` and caches the payload. Throws [ApiException] on failure.
  Future<HomeResult> refresh(HomeQuery query) async {
    final json = await _api.getJson('/home', query: query.toQueryParameters());
    final home = HomeResponse.fromJson(json);
    await _cache.put(query.cacheKey, json);
    await _publishToWidget(home, query);
    return HomeResult(home: home, source: HomeSource.network);
  }

  /// docs/06 §Home-screen widget — "whenever the app receives a `/home` response (network or
  /// cache), write a compact snapshot and ask the widget to redraw".
  ///
  /// The bundled fixture is deliberately **not** published: it is sample data (CLAUDE.md §6),
  /// and a launcher widget has no room to say so. A widget with nothing to show says "Open
  /// Mausam to refresh" instead, which is the truth.
  Future<void> _publishToWidget(HomeResponse home, HomeQuery query) async {
    try {
      await _widget.publish(
        WidgetSnapshot.fromHome(home, lang: query.lang, units: units),
        config: WidgetRefreshConfig(
          backendUrl: _api.baseUrl,
          lat: query.lat,
          lon: query.lon,
          token: _api.token,
          personas: query.personas,
          lang: query.lang,
          units: units,
        ),
      );
    } catch (_) {
      // Never fatal — the widget is an extra surface, not part of the home screen's contract.
    }
  }

  /// The bundled sample payload (docs/07 §B1 — "author app/assets/fixtures/home_sample.json").
  Future<HomeResponse> loadFixture() async {
    final json = _fixtureCache ??= Map<String, dynamic>.from(
      jsonDecode(await _loadAsset(AppConfig.sampleHomeAsset)) as Map,
    );
    return HomeResponse.fromJson(json);
  }
}
