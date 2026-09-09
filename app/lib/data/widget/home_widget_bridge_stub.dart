import 'home_widget_bridge.dart';

/// Web build: there is no home-screen widget and the `home_widget` plugin (which imports
/// `dart:io`) must not be compiled at all. docs/06 §Home-screen widget → Limits.
HomeWidgetBridge createHomeWidgetBridge() => const NoopHomeWidgetBridge();
