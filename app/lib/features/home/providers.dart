import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity.dart';
import '../../core/formatters.dart';
import '../../data/api_client.dart';
import '../../data/cache/json_file_cache.dart';
import '../../data/models/location.dart';
import '../../data/models/user.dart' show TimeWindow;
import '../../data/repositories/auth_repo.dart';
import '../../data/repositories/events_repo.dart';
import '../../data/repositories/home_repo.dart';
import '../../data/repositories/locations_repo.dart';
import '../../data/repositories/places_repo.dart';
import '../../data/repositories/radar_repo.dart';
import '../../data/repositories/settings_repo.dart';
import 'renderers/radar.dart' show RadarRenderer;

// ---------------------------------------------------------------- infrastructure

final settingsRepoProvider = Provider<SettingsRepo>((ref) => SettingsRepo());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  // Keep the client in step with the settings the user edits at runtime.
  ref.listen<AppSettings>(settingsProvider, (previous, next) {
    client.baseUrl = next.backendUrl;
    client.lang = next.language;
  }, fireImmediately: true);
  return client;
});

final jsonCacheProvider = Provider<JsonFileCache>((ref) => JsonFileCache());

final authRepoProvider =
    Provider<AuthRepo>((ref) => AuthRepo(api: ref.watch(apiClientProvider)));

/// The bearer token the API client and the alerts socket both need (docs/04 `POST /auth/guest`).
/// Resolves to `null` when the backend is unreachable — every caller treats that as "carry on
/// unauthenticated", which is what keeps onboarding and home alive without a backend.
final authTokenProvider = FutureProvider<String?>((ref) async {
  // Re-issued when the user points the app at a different backend.
  ref.watch(settingsProvider.select((AppSettings s) => s.backendUrl));
  return ref.watch(authRepoProvider).ensureGuestToken();
});

final homeRepoProvider = Provider<HomeRepo>((ref) => HomeRepo(
      api: ref.watch(apiClientProvider),
      cache: ref.watch(jsonCacheProvider),
    ));

final locationsRepoProvider =
    Provider<LocationsRepo>((ref) => LocationsRepo(api: ref.watch(apiClientProvider)));

/// docs/04 `GET /weather/radar` — the frames the map page loops through.
final radarRepoProvider =
    Provider<RadarRepo>((ref) => RadarRepo(api: ref.watch(apiClientProvider)));

/// docs/04 `/me/places` (max 8) — the saved places behind the traveller cards.
final placesRepoProvider =
    Provider<PlacesRepo>((ref) => PlacesRepo(api: ref.watch(apiClientProvider)));

final eventsRepoProvider = Provider<EventsRepo>((ref) {
  final repo = EventsRepo(api: ref.watch(apiClientProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => ConnectivityService());

/// `true` while the device reports no network interface (docs/06 §Home behaviour: offline banner).
final offlineProvider = StreamProvider<bool>((ref) async* {
  // The demo sheet can pretend the device is offline (docs/06 §demo_sheet "simulate offline").
  if (ref.watch(demoProvider).simulateOffline) {
    yield true;
    return;
  }
  final service = ref.watch(connectivityServiceProvider);
  yield await service.isOffline();
  yield* service.offlineStream();
});

// ---------------------------------------------------------------- settings

/// Persisted app settings. Loaded once at startup by [SettingsNotifier.hydrate] (called from
/// `main`) so that the first frame already has the right locale and backend URL.
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.initial();

  Future<void> hydrate() async {
    state = await ref.read(settingsRepoProvider).load();
    _applyDisplayFlags(state);
  }

  Future<void> update(AppSettings next, {bool syncProfile = true}) async {
    state = next;
    _applyDisplayFlags(next);
    await ref.read(settingsRepoProvider).save(next);
    // Keep the server profile in step (docs/04 `PUT /me/profile`). Best-effort by design:
    // `updateProfile` swallows an unreachable backend so a demo without one still works.
    if (syncProfile && next.onboarded) {
      unawaited(ref.read(authRepoProvider).updateProfile(next.toProfilePatch()));
    }
  }

  /// Two display-only switches that renderers read without a `ref` (units and radar tiles), so
  /// they keep working in widget tests built outside a ProviderScope.
  static void _applyDisplayFlags(AppSettings s) {
    Fmt.imperial = s.isImperial;
    RadarRenderer.tilesEnabled = !s.lowBandwidth;
  }

  Future<void> setLanguage(String language) => update(state.copyWith(language: language));

  Future<void> setBackendUrl(String url) =>
      update(state.copyWith(backendUrl: url), syncProfile: false);

  Future<void> setPersonas(List<String> personas) => update(state.copyWith(personas: personas));

  Future<void> setHomeLocation(LocationResult location) =>
      update(state.copyWith(homeLocation: location));

  Future<void> completeOnboarding() => update(state.copyWith(onboarded: true));

  Future<void> setLowBandwidth(bool value) =>
      update(state.copyWith(lowBandwidth: value), syncProfile: false);

  /// docs/04 §Objects `User.units`.
  Future<void> setUnits(String units) => update(state.copyWith(units: units));

  Future<void> setLargeText(bool value) =>
      update(state.copyWith(largeText: value), syncProfile: false);

  Future<void> setSchoolWindows(List<TimeWindow> windows) =>
      update(state.copyWith(schoolWindows: windows));

  Future<void> setCommuteWindows(List<TimeWindow> windows) =>
      update(state.copyWith(commuteWindows: windows));
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

final localeProvider = Provider<Locale>((ref) {
  return Locale(ref.watch(settingsProvider).language);
});

// ---------------------------------------------------------------- home

/// A temporary "role view": tapping an outlined persona chip loads `/home?personas=<id>`
/// without changing the saved profile (docs/06 §Home behaviour).
class RoleViewNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void view(String personaId) => state = personaId;
  void clear() => state = null;
}

final roleViewProvider = NotifierProvider<RoleViewNotifier, String?>(RoleViewNotifier.new);

/// Judge-demo overrides (docs/06 §Layout `demo/demo_sheet`): a scenario name, a demo clock and
/// a simulated offline switch. They live outside [AppSettings] on purpose — nothing here is
/// persisted, so a restart always returns to live data.
class DemoState {
  const DemoState({this.scenario, this.nowOverride, this.simulateOffline = false});

  /// `null` = whatever the backend's global scenario is (docs/04 `GET /home?scenario=`).
  final String? scenario;

  /// ISO-8601 with offset, e.g. `2026-09-08T07:30:00+05:30`.
  final String? nowOverride;

  /// Pretends the device has no network, without touching the radio.
  final bool simulateOffline;

  bool get isActive => scenario != null || nowOverride != null || simulateOffline;

  DemoState copyWith({
    String? scenario,
    bool clearScenario = false,
    String? nowOverride,
    bool clearNowOverride = false,
    bool? simulateOffline,
  }) =>
      DemoState(
        scenario: clearScenario ? null : (scenario ?? this.scenario),
        nowOverride: clearNowOverride ? null : (nowOverride ?? this.nowOverride),
        simulateOffline: simulateOffline ?? this.simulateOffline,
      );
}

class DemoNotifier extends Notifier<DemoState> {
  @override
  DemoState build() => const DemoState();

  void setScenario(String? name) => state = name == null || name == 'live'
      ? state.copyWith(clearScenario: true)
      : state.copyWith(scenario: name);

  void setNowOverride(String? iso) =>
      state = iso == null ? state.copyWith(clearNowOverride: true) : state.copyWith(nowOverride: iso);

  void setSimulateOffline(bool value) => state = state.copyWith(simulateOffline: value);

  void reset() => state = const DemoState();
}

final demoProvider = NotifierProvider<DemoNotifier, DemoState>(DemoNotifier.new);

/// The query the home screen is currently showing: saved location + saved personas, unless a
/// role view overrides the persona list or the demo sheet overrides scenario / clock.
final homeQueryProvider = Provider<HomeQuery>((ref) {
  final settings = ref.watch(settingsProvider);
  final role = ref.watch(roleViewProvider);
  final demo = ref.watch(demoProvider);
  final loc = settings.homeLocation;
  return HomeQuery(
    lat: loc?.lat ?? 28.61,
    lon: loc?.lon ?? 77.21,
    personas: role != null ? <String>[role] : settings.personas,
    lang: settings.language,
    scenario: demo.scenario,
    nowOverride: demo.nowOverride,
    lite: settings.lowBandwidth,
  );
});

/// docs/06 §Home behaviour — "cached JSON (instant, shows freshness chip) → network refresh →
/// animated diff". Modelled as a stream so both states reach the UI from one subscription:
/// the cached payload is emitted first (if any), then the resolved one.
///
/// The family key is the whole query, so a persona / location / language change is a new
/// subscription. Pull-to-refresh is `ref.invalidate(homeProvider(query))`.
final homeProvider = StreamProvider.family<HomeResult, HomeQuery>((ref, query) async* {
  final repo = ref.watch(homeRepoProvider);
  ref.read(eventsRepoProvider).resetImpressions();

  final cached = await repo.cached(query);
  if (cached != null) yield cached;

  // `load` never throws: network → cache → bundled fixture.
  yield await repo.load(query);
});

/// Card types the user chose to hide locally in this session (docs/06 §Why sheet).
/// The server-side prefs round-trip lands in B2 with `/events` and `/me/card-prefs`.
class HiddenCardsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void hide(String type) => state = <String>{...state, type};
  void unhide(String type) => state = <String>{...state}..remove(type);
  void restoreAll() => state = <String>{};
}

final hiddenCardsProvider =
    NotifierProvider<HiddenCardsNotifier, Set<String>>(HiddenCardsNotifier.new);

/// Cards the user pushed down to "More for you" with a swipe / Show less.
class DemotedCardsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void demote(String type) => state = <String>{...state, type};
  void restore(String type) => state = <String>{...state}..remove(type);
  void restoreAll() => state = <String>{};
}

final demotedCardsProvider =
    NotifierProvider<DemotedCardsNotifier, Set<String>>(DemotedCardsNotifier.new);
