import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'home_widget_bridge.dart';
import 'widget_snapshot.dart';

/// The real bridge, over the `home_widget` plugin (Android only).
class PluginHomeWidgetBridge implements HomeWidgetBridge {
  const PluginHomeWidgetBridge();

  /// Android only: there is no iOS widget in this prototype. On a desktop test host the
  /// channel is not registered either, so the app falls back to the no-op bridge.
  static bool get isSupported => Platform.isAndroid;

  @override
  Future<void> publish(WidgetSnapshot snapshot, {WidgetRefreshConfig? config}) async {
    if (!isSupported) return;
    try {
      await HomeWidget.saveWidgetData<String>(
        HomeWidgetKeys.snapshot,
        jsonEncode(snapshot.toJson()),
      );
      if (config != null) {
        for (final entry in config.toKeyValues().entries) {
          await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
        }
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: HomeWidgetKeys.providerClass);
    } catch (e) {
      // A launcher hosting no widget, a plugin that is not registered under a test binding —
      // none of that is a reason to break the screen the user is looking at.
      debugPrint('home widget publish skipped: $e');
    }
  }

  @override
  Future<Uri?> initialLaunch() async {
    if (!isSupported) return null;
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      debugPrint('home widget launch uri unavailable: $e');
      return null;
    }
  }

  @override
  Stream<Uri?> launches() =>
      isSupported ? HomeWidget.widgetClicked.handleError((Object e) {
        debugPrint('home widget click stream error: $e');
      }) : const Stream<Uri?>.empty();
}

HomeWidgetBridge createHomeWidgetBridge() =>
    PluginHomeWidgetBridge.isSupported ? const PluginHomeWidgetBridge() : const NoopHomeWidgetBridge();
