import 'package:flutter/foundation.dart';

/// Static app configuration. docs/06_MOBILE_SPEC.md §Layout `core/config.dart`.
class AppConfig {
  AppConfig._();

  /// Display name. docs/00_VISION.md principle 8 — a Team Mausam prototype, not an IMD app.
  static const String appName = 'Mausam Personalized';
  static const String appNameLong = 'Mausam Personalized (Team Mausam prototype)';

  /// docs/04_API_CONTRACT.md — every REST path hangs off `{BACKEND}/api/v1`.
  static const String apiPrefix = '/api/v1';

  /// Default backend origin per platform (docs/06 §Layout). Overridable in Settings.
  ///  * web / desktop  → the dev machine itself
  ///  * Android emulator → 10.0.2.2 is the emulator's alias for the host loopback
  ///  * real device → the user must set the LAN IP in Settings; 10.0.2.2 is a harmless default
  ///    because it simply fails fast and the app falls back to cache/fixture.
  ///
  /// A build may hard-code the origin with
  /// `flutter build apk --dart-define=BACKEND_URL=https://host`, which is how the
  /// sideloadable demo APK is produced: a judge installs it and it talks to the
  /// deployed backend with no trip through Settings. Settings still overrides it.
  static const String _buildTimeBackendUrl =
      String.fromEnvironment('BACKEND_URL', defaultValue: '');

  static String get defaultBackendUrl {
    if (_buildTimeBackendUrl.isNotEmpty) return _buildTimeBackendUrl;
    if (kIsWeb) return 'http://localhost:8000';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
        return 'http://localhost:8000';
      default:
        return 'http://localhost:8000';
    }
  }

  /// Bundled sample payload used when the backend is unreachable and nothing is cached.
  static const String sampleHomeAsset = 'assets/fixtures/home_sample.json';

  static const Duration connectTimeout = Duration(seconds: 6);
  static const Duration receiveTimeout = Duration(seconds: 12);

  /// Cache is served instantly, then refreshed. Anything older than this is flagged stale.
  static const Duration cacheStaleAfter = Duration(minutes: 30);

  /// docs/06 §i18n — five ARBs. `en` and `hi` are complete; `mr`, `ta` and `bn` are
  /// best-effort and fall back to English per key (`flutter gen-l10n`).
  static const List<String> supportedLanguages = <String>['en', 'hi', 'mr', 'ta', 'bn'];

  static const List<int> personaPickRange = <int>[1, 3];
}
