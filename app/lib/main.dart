import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/home/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One container is created up front so persisted settings (language, backend URL, saved
  // location) are loaded before the first frame — otherwise the router would briefly bounce a
  // returning user back into onboarding.
  final container = ProviderContainer();
  await container.read(settingsProvider.notifier).hydrate();

  // Best-effort guest token (docs/04 `POST /auth/guest`). A missing backend is not fatal: the
  // home repository falls back to cache and then to the bundled sample payload.
  unawaited(
    container.read(authRepoProvider).ensureGuestToken().catchError((Object _) => null),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MausamApp(),
    ),
  );
}
