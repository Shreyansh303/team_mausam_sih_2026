import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_page.dart';
import '../features/home/providers.dart';
import '../features/onboarding/language_page.dart';
import '../features/onboarding/location_page.dart';
import '../features/map/map_page.dart';
import '../features/onboarding/persona_page.dart';
import '../features/places/places_page.dart';
import '../features/settings/settings_page.dart';

/// docs/06_MOBILE_SPEC.md §Layout — `MaterialApp.router` + go_router.
///
/// Onboarding is a hard redirect: until the user has picked personas and a location there is
/// nothing to personalise, so `/` bounces to `/onboarding/language`.
GoRouter buildRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final settings = ref.read(settingsProvider);
      final path = state.uri.path;
      final inOnboarding = path.startsWith('/onboarding');
      final ready = settings.onboarded &&
          settings.personas.isNotEmpty &&
          settings.homeLocation != null;
      if (!ready && !inOnboarding) return '/onboarding/language';
      if (ready && inOnboarding) return '/';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/', name: 'home', builder: (_, _) => const HomePage()),
      GoRoute(path: '/settings', name: 'settings', builder: (_, _) => const SettingsPage()),
      GoRoute(path: '/places', name: 'places', builder: (_, _) => const PlacesPage()),
      GoRoute(path: '/map', name: 'map', builder: (_, _) => const MapPage()),
      GoRoute(
        path: '/onboarding/language',
        name: 'onboardingLanguage',
        builder: (_, _) => const LanguagePage(),
      ),
      GoRoute(
        path: '/onboarding/personas',
        name: 'onboardingPersonas',
        builder: (_, _) => const PersonaPage(),
      ),
      GoRoute(
        path: '/onboarding/location',
        name: 'onboardingLocation',
        builder: (_, _) => const LocationPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('No route for ${state.uri}')),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter(ref);
  // Re-evaluate the onboarding redirect whenever settings change.
  ref.listen<dynamic>(settingsProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});
