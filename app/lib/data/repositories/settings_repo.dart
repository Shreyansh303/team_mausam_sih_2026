import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';
import '../models/location.dart';

/// docs/04 §Objects `User.school_windows` / `commute_windows` —
/// `{"label":"morning_drop","start":"07:00","end":"09:00"}`.
class TimeWindow {
  const TimeWindow({required this.label, required this.start, required this.end});

  final String label;

  /// `HH:mm`, local to the user's home location.
  final String start;
  final String end;

  TimeWindow copyWith({String? start, String? end}) =>
      TimeWindow(label: label, start: start ?? this.start, end: end ?? this.end);

  factory TimeWindow.fromJson(Map<String, dynamic> json) => TimeWindow(
        label: '${json['label'] ?? ''}',
        start: '${json['start'] ?? '00:00'}',
        end: '${json['end'] ?? '00:00'}',
      );

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'label': label, 'start': start, 'end': end};

  /// docs/04 §Objects `User` — the defaults the backend itself uses.
  static const List<TimeWindow> defaultSchool = <TimeWindow>[
    TimeWindow(label: 'morning_drop', start: '07:00', end: '09:00'),
    TimeWindow(label: 'afternoon_pickup', start: '13:00', end: '16:00'),
  ];

  static const List<TimeWindow> defaultCommute = <TimeWindow>[
    TimeWindow(label: 'morning', start: '08:00', end: '10:00'),
    TimeWindow(label: 'evening', start: '17:00', end: '20:00'),
  ];
}

/// Everything the app persists locally between launches.
class AppSettings {
  const AppSettings({
    required this.backendUrl,
    this.language = 'en',
    this.personas = const <String>[],
    this.homeLocation,
    this.onboarded = false,
    this.lowBandwidth = false,
    this.units = 'metric',
    this.largeText = false,
    this.schoolWindows = TimeWindow.defaultSchool,
    this.commuteWindows = TimeWindow.defaultCommute,
  });

  final String backendUrl;
  final String language;

  /// 1–3 persona ids, first = primary (docs/06 §onboarding).
  final List<String> personas;
  final LocationResult? homeLocation;
  final bool onboarded;
  final bool lowBandwidth;

  /// docs/04 §Objects `User.units` — `metric` or `imperial`.
  final String units;

  /// docs/06 §settings_page "large text".
  final bool largeText;

  final List<TimeWindow> schoolWindows;
  final List<TimeWindow> commuteWindows;

  bool get isImperial => units == 'imperial';

  AppSettings copyWith({
    String? backendUrl,
    String? language,
    List<String>? personas,
    LocationResult? homeLocation,
    bool? onboarded,
    bool? lowBandwidth,
    String? units,
    bool? largeText,
    List<TimeWindow>? schoolWindows,
    List<TimeWindow>? commuteWindows,
  }) =>
      AppSettings(
        backendUrl: backendUrl ?? this.backendUrl,
        language: language ?? this.language,
        personas: personas ?? this.personas,
        homeLocation: homeLocation ?? this.homeLocation,
        onboarded: onboarded ?? this.onboarded,
        lowBandwidth: lowBandwidth ?? this.lowBandwidth,
        units: units ?? this.units,
        largeText: largeText ?? this.largeText,
        schoolWindows: schoolWindows ?? this.schoolWindows,
        commuteWindows: commuteWindows ?? this.commuteWindows,
      );

  /// The `PUT /me/profile` body (docs/04 — partial `User`).
  Map<String, dynamic> toProfilePatch() => <String, dynamic>{
        'personas': personas,
        'language': language,
        'units': units,
        if (homeLocation != null) 'home_location': homeLocation!.toJson(),
        'school_windows': schoolWindows.map((w) => w.toJson()).toList(),
        'commute_windows': commuteWindows.map((w) => w.toJson()).toList(),
      };

  static AppSettings initial() => AppSettings(backendUrl: AppConfig.defaultBackendUrl);
}

/// Reads and writes [AppSettings] through SharedPreferences.
class SettingsRepo {
  SettingsRepo({SharedPreferences? prefs}) : _prefs = prefs; // ignore: prefer_initializing_formals

  static const _kBackendUrl = 'backend_url';
  static const _kLanguage = 'language';
  static const _kPersonas = 'personas';
  static const _kHomeLocation = 'home_location';
  static const _kOnboarded = 'onboarded';
  static const _kLowBandwidth = 'low_bandwidth';
  static const _kUnits = 'units';
  static const _kLargeText = 'large_text';
  static const _kSchoolWindows = 'school_windows';
  static const _kCommuteWindows = 'commute_windows';

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
      units: p.getString(_kUnits) ?? 'metric',
      largeText: p.getBool(_kLargeText) ?? false,
      schoolWindows: _readWindows(p.getString(_kSchoolWindows), TimeWindow.defaultSchool),
      commuteWindows: _readWindows(p.getString(_kCommuteWindows), TimeWindow.defaultCommute),
    );
  }

  static List<TimeWindow> _readWindows(String? raw, List<TimeWindow> fallback) {
    if (raw == null || raw.isEmpty) return fallback;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) return fallback;
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => TimeWindow.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return fallback;
    }
  }

  Future<void> save(AppSettings s) async {
    final p = await _p();
    await p.setString(_kBackendUrl, s.backendUrl);
    await p.setString(_kLanguage, s.language);
    await p.setStringList(_kPersonas, s.personas);
    await p.setBool(_kOnboarded, s.onboarded);
    await p.setBool(_kLowBandwidth, s.lowBandwidth);
    await p.setString(_kUnits, s.units);
    await p.setBool(_kLargeText, s.largeText);
    await p.setString(
        _kSchoolWindows, jsonEncode(s.schoolWindows.map((w) => w.toJson()).toList()));
    await p.setString(
        _kCommuteWindows, jsonEncode(s.commuteWindows.map((w) => w.toJson()).toList()));
    if (s.homeLocation != null) {
      await p.setString(_kHomeLocation, jsonEncode(s.homeLocation!.toJson()));
    } else {
      await p.remove(_kHomeLocation);
    }
  }
}
