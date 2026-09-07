import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/location.dart';
import '../../data/repositories/locations_repo.dart';
import '../../l10n/gen/app_localizations.dart';
import '../home/providers.dart';
import 'onboarding_scaffold.dart';

/// docs/06_MOBILE_SPEC.md §onboarding — "GPS button + search + popular cities",
/// then guest token + `PUT /me/profile`.
class LocationPage extends ConsumerStatefulWidget {
  const LocationPage({super.key});

  @override
  ConsumerState<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends ConsumerState<LocationPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<LocationResult> _results = const <LocationResult>[];
  List<LocationResult> _popular = LocationsRepo.fallbackCities;
  LocationResult? _selected;
  bool _locating = false;
  bool _searching = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(settingsProvider).homeLocation;
    unawaited(_loadPopular());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPopular() async {
    final list = await ref.read(locationsRepoProvider).popular();
    if (!mounted) return;
    setState(() => _popular = list.take(18).toList());
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = const <LocationResult>[]);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      final list = await ref.read(locationsRepoProvider).search(q);
      if (!mounted) return;
      setState(() {
        _results = list;
        _searching = false;
      });
    });
  }

  /// GPS → reverse geocode. Denied permission is not an error state: the user searches instead.
  Future<void> _useMyLocation() async {
    final l = L.of(context);
    setState(() {
      _locating = true;
      _message = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _message = l.locationServicesOff);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _message = l.locationPermissionDenied);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final resolved =
          await ref.read(locationsRepoProvider).reverse(pos.latitude, pos.longitude);
      if (!mounted || resolved == null) return;
      setState(() => _selected = resolved);
    } catch (e) {
      if (mounted) setState(() => _message = L.of(context).locationPermissionDenied);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Persist the choice, then create the guest user and push the profile (docs/06 §onboarding).
  Future<void> _finish() async {
    final selected = _selected;
    if (selected == null) return;
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    await notifier.setHomeLocation(selected);

    final auth = ref.read(authRepoProvider);
    await auth.ensureGuestToken();
    await auth.updateProfile(<String, dynamic>{
      'personas': [
        for (var i = 0; i < settings.personas.length; i++)
          <String, dynamic>{'id': settings.personas[i], 'weight': i == 0 ? 1.0 : 0.7},
      ],
      'language': settings.language,
      'units': 'metric',
      'home_location': selected.toJson(),
    });

    await notifier.completeOnboarding();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final showing = _results.isNotEmpty ? _results : _popular;

    return OnboardingScaffold(
      step: 2,
      title: l.onboardingLocationTitle,
      subtitle: l.onboardingLocationSubtitle,
      primaryLabel: l.finish,
      onPrimary: _selected == null ? null : _finish,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _locating ? null : _useMyLocation,
            icon: _locating
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            label: Text(_locating ? l.locatingYou : l.useMyLocation),
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(_message!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l.searchCity,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                          width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          if (_selected != null)
            Card(
              child: ListTile(
                leading: Icon(Icons.place, color: theme.colorScheme.primary),
                title: Text(_selected!.name),
                subtitle: Text(_selected!.subtitle),
                trailing: Icon(Icons.check_circle, color: theme.colorScheme.primary),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _results.isNotEmpty ? l.searchCity : l.popularCities,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final city in showing)
                ChoiceChip(
                  label: Text(city.name),
                  avatar: city.isCoastal ? const Icon(Icons.waves, size: 16) : null,
                  selected: _selected?.id == city.id,
                  onSelected: (_) => setState(() => _selected = city),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
