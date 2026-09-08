import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'features/home/providers.dart';
import 'l10n/gen/app_localizations.dart';

/// docs/06_MOBILE_SPEC.md §Layout `app.dart` — MaterialApp.router, theme, locale from settings.
///
/// It is also where the engagement queue is flushed when the app leaves the foreground
/// (docs/06 §Layout `events_repo (batched, flushed every 10 s or on background)`).
class MausamApp extends ConsumerStatefulWidget {
  const MausamApp({super.key});

  @override
  ConsumerState<MausamApp> createState() => _MausamAppState();
}

class _MausamAppState extends ConsumerState<MausamApp> {
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onPause: () => unawaited(ref.read(eventsRepoProvider).flush()),
      onDetach: () => unawaited(ref.read(eventsRepoProvider).flush()),
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: locale,
      supportedLocales: L.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // docs/06 §settings_page "large text": the OS text scale is respected as the floor and
      // the in-app setting can only ever enlarge it, never shrink someone's accessibility
      // preference.
      builder: (context, child) {
        final platformScale = MediaQuery.textScalerOf(context);
        final scaled = settings.largeText
            ? platformScale.clamp(minScaleFactor: 1.3, maxScaleFactor: 2.0)
            : platformScale;
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: scaled.scale(1),
          maxScaleFactor: 2.0,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
