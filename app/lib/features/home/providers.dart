import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity.dart';
import '../../data/api_client.dart';
import '../../data/cache/json_file_cache.dart';
import '../../data/models/location.dart';
import '../../data/repositories/auth_repo.dart';
import '../../data/repositories/events_repo.dart';
import '../../data/repositories/home_repo.dart';
import '../../data/repositories/locations_repo.dart';
import '../../data/repositories/settings_repo.dart';

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

final homeRepoProvider = Provider<HomeRepo>((ref) => HomeRepo(
      api: ref.watch(apiClientProvider),
      cache: ref.watch(jsonCacheProvider),
    ));

final locationsRepoProvider =
    Provider<LocationsRepo>((ref) => LocationsRepo(api: ref.watch(apiClientProvider)));

final eventsRepoProvider = Provider<EventsRepo>((ref) {
  final repo = EventsRepo(api: ref.watch(apiClientProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => ConnectivityService());

/// `true` while the device reports no network interface (docs/06 §Home behaviour: offline banner).
final offlineProvider = StreamProvider<bool>((ref) async* {
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
  }

  Future<void> update(AppSettings next) async {
    state = next;
    await ref.read(settingsRepoProvider).save(next);
  }

  Future<void> setLanguage(String language) => update(state.copyWith(language: language));

  Future<void> setBackendUrl(String url) => update(state.copyWith(backendUrl: url));

  Future<void> setPersonas(List<String> personas) => update(state.copyWith(personas: personas));

  Future<void> setHomeLocation(LocationResult location) =>
      update(state.copyWith(homeLocation: location));

  Future<void> completeOnboarding() => update(state.copyWith(onboarded: true));

  Future<void> setLowBandwidth(bool value) => update(state.copyWith(lowBandwidth: value));
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

/// The query the home screen is currently showing: saved location + saved personas, unless a
/// role view overrides the persona list.
final homeQueryProvider = Provider<HomeQuery>((ref) {
  final settings = ref.watch(settingsProvider);
  final role = ref.watch(roleViewProvider);
  final loc = settings.homeLocation;
  return HomeQuery(
    lat: loc?.lat ?? 28.61,
    lon: loc?.lon ?? 77.21,
    personas: role != null ? <String>[role] : settings.personas,
    lang: settings.language,
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
