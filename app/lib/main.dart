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

  // Best-effort guest token, then the preferences that token unlocks. Deliberately not awaited:
  // a missing backend is not fatal and must not hold up the first frame — the home repository
  // falls back to cache and then to the bundled sample payload.
  unawaited(_restoreServerState(container));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MausamApp(),
    ),
  );
}

/// The two start-up round trips, in order: the guest token (docs/04 `POST /auth/guest` — a fresh
/// install has none, and an existing one is reused, which is also what merges a guest's history
/// into the account), then the card preferences it authorises (docs/04 `GET /me/card-prefs`).
/// Without the second call a reinstall showed every card the user had hidden.
///
/// Both steps swallow their own failures, so this future never completes with an error.
Future<void> _restoreServerState(ProviderContainer container) async {
  await container.read(authRepoProvider).ensureGuestToken().catchError((Object _) => null);
  await seedCardPrefs(container);
}
