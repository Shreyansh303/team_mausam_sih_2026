import 'widget_snapshot.dart';

// The plugin pulls in `dart:io`, which dart2js cannot compile, so the only import of
// `package:home_widget` in the app sits behind this switch. The web build (the judge demo) and
// `flutter test` therefore never see it. docs/06 §Home-screen widget → Limits.
import 'home_widget_bridge_stub.dart'
    if (dart.library.io) 'home_widget_bridge_io.dart' as impl;

/// What the Kotlin background worker needs in order to call `/home?lite=1` on its own, an hour
/// after the app was last open (docs/06 §Home-screen widget → Background refresh).
///
/// Nothing here is new state: it is the same backend URL, guest token, location, personas and
/// language the app is already using, copied where a process without a Flutter engine can read
/// it. The token lives in app-private storage, exactly as `shared_preferences` already keeps it.
class WidgetRefreshConfig {
  const WidgetRefreshConfig({
    required this.backendUrl,
    required this.lat,
    required this.lon,
    this.token,
    this.personas = const <String>[],
    this.lang = 'en',
    this.units = 'metric',
  });

  final String backendUrl;
  final double lat;
  final double lon;
  final String? token;
  final List<String> personas;
  final String lang;
  final String units;

  Map<String, String> toKeyValues() => <String, String>{
        HomeWidgetKeys.backendUrl: backendUrl,
        HomeWidgetKeys.token: token ?? '',
        HomeWidgetKeys.lat: '$lat',
        HomeWidgetKeys.lon: '$lon',
        HomeWidgetKeys.personas: personas.join(','),
        HomeWidgetKeys.lang: lang,
        HomeWidgetKeys.units: units,
      };
}

/// Keys in the shared storage the widget reads. Duplicated verbatim in
/// `android/app/src/main/kotlin/com/teammausam/mausam_app/WidgetKeys.kt` — change both.
class HomeWidgetKeys {
  HomeWidgetKeys._();

  static const String snapshot = 'mausam_snapshot';
  static const String backendUrl = 'mausam_backend_url';
  static const String token = 'mausam_token';
  static const String lat = 'mausam_lat';
  static const String lon = 'mausam_lon';
  static const String personas = 'mausam_personas';
  static const String lang = 'mausam_lang';
  static const String units = 'mausam_units';

  /// Fully qualified so `HomeWidget.updateWidget` finds the receiver without guessing.
  static const String providerClass = 'com.teammausam.mausam_app.MausamWidgetProvider';
}

/// Publishes [WidgetSnapshot]s to the Android home-screen widget.
///
/// An interface, not a static call, so `HomeRepo` can be tested without the platform channel
/// (`app/test/widget_snapshot_test.dart`).
abstract class HomeWidgetBridge {
  /// Writes the snapshot and asks the widget to redraw. Must never throw: a home refresh is
  /// not allowed to fail because a launcher widget could not be updated.
  Future<void> publish(WidgetSnapshot snapshot, {WidgetRefreshConfig? config});

  /// The deep link the app was cold-started with, when the launch came from the widget.
  Future<Uri?> initialLaunch();

  /// Later taps, while the app is already running (the widget's PendingIntent is `singleTop`,
  /// so these arrive as `onNewIntent`).
  Stream<Uri?> launches();
}

/// A bridge that does nothing — the web build, the iOS build and every unit test.
class NoopHomeWidgetBridge implements HomeWidgetBridge {
  const NoopHomeWidgetBridge();

  @override
  Future<void> publish(WidgetSnapshot snapshot, {WidgetRefreshConfig? config}) async {}

  @override
  Future<Uri?> initialLaunch() async => null;

  @override
  Stream<Uri?> launches() => const Stream<Uri?>.empty();
}

/// `mausam://card/<type>` → `<type>`; `mausam://home` (and anything else) → `null`.
///
/// The widget's two tap targets, from `MausamWidgetProvider` / `WidgetKeys.cardUri`. Home needs
/// no route of its own: it is the app's initial location (docs/06 §Layout `core/router.dart`).
String? widgetLaunchCardType(Uri? uri) {
  if (uri == null || uri.scheme != 'mausam' || uri.host != 'card') return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  return segments.isEmpty ? null : segments.first;
}

/// The bridge the app uses: the real one on Android, a no-op everywhere else.
HomeWidgetBridge defaultHomeWidgetBridge() => impl.createHomeWidgetBridge();
