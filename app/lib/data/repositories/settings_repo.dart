import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';
import '../models/location.dart';

/// Everything the app persists locally between launches.
class AppSettings {
  const AppSettings({
    required this.backendUrl,
    this.language = 'en',
    this.personas = const <String>[],
    this.homeLocation,
    this.onboarded = false,
    this.lowBandwidth = false,
  });

  final String backendUrl;
  final String language;

  /// 1–3 persona ids, first = primary (docs/06 §onboarding).
  final List<String> personas;
  final LocationResult? homeLocation;
  final bool onboarded;
  final bool lowBandwidth;

  AppSettings copyWith({
    String? backendUrl,
    String? language,
    List<String>? personas,
    LocationResult? homeLocation,
    bool? onboarded,
    bool? lowBandwidth,
  }) =>
      AppSettings(
        backendUrl: backendUrl ?? this.backendUrl,
        language: language ?? this.language,
        personas: personas ?? this.personas,
        homeLocation: homeLocation ?? this.homeLocation,
        onboarded: onboarded ?? this.onboarded,
        lowBandwidth: lowBandwidth ?? this.lowBandwidth,
      );

  static AppSettings initial() => AppSettings(backendUrl: AppConfig.defaultBackendUrl);
}

/// Reads and writes [AppSettings] through SharedPreferences.
class SettingsRepo {
  SettingsRepo({this._prefs});

  static const _kBackendUrl = 'backend_url';
  static const _kLanguage = 'language';
  static const _kPersonas = 'personas';
  static const _kHomeLocation = 'home_location';
  static const _kOnboarded = 'onboarded';
  static const _kLowBandwidth = 'low_bandwidth';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _p() async => _prefs ??= await SharedPreferences.getInstance();

  Future<AppSettings> load() async {
    final p = await _p();
    LocationResult? loc;
    final rawLoc = p.getString(_kHomeLocation);
    if (rawLoc != null && rawLoc.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawLoc);
        if (decoded is Map) {
          loc = LocationResult.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        loc = null;
      }
    }
    return AppSettings(
      backendUrl: p.getString(_kBackendUrl) ?? AppConfig.defaultBackendUrl,
      language: p.getString(_kLanguage) ?? 'en',
      personas: p.getStringList(_kPersonas) ?? const <String>[],
      homeLocation: loc,
      onboarded: p.getBool(_kOnboarded) ?? false,
      lowBandwidth: p.getBool(_kLowBandwidth) ?? false,
    );
  }

  Future<void> save(AppSettings s) async {
    final p = await _p();
    await p.setString(_kBackendUrl, s.backendUrl);
    await p.setString(_kLanguage, s.language);
    await p.setStringList(_kPersonas, s.personas);
    await p.setBool(_kOnboarded, s.onboarded);
    await p.setBool(_kLowBandwidth, s.lowBandwidth);
    if (s.homeLocation != null) {
      await p.setString(_kHomeLocation, jsonEncode(s.homeLocation!.toJson()));
    } else {
      await p.remove(_kHomeLocation);
    }
  }
}
