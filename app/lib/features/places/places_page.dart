import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/location.dart';
import '../../data/repositories/places_repo.dart';
import '../../l10n/gen/app_localizations.dart';
import '../home/providers.dart';

/// docs/06_MOBILE_SPEC.md §Layout `places/ places_page (list, add via search, delete, set kind)`
/// over docs/04 `/me/places` (max 8).
///
/// The saved places drive the traveller cards (`saved_places`, `packing_suggestions`,
/// `travel_alerts` in docs/02), so every change re-fetches `/home`.
class PlacesPage extends ConsumerStatefulWidget {
  const PlacesPage({super.key});

  @override
  ConsumerState<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends ConsumerState<PlacesPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<Place> _places = const <Place>[];
  List<LocationResult> _results = const <LocationResult>[];
  String _kind = 'travel';
  bool _loading = true;
  bool _searching = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await ref.read(placesRepoProvider).list();
    if (!mounted) return;
    setState(() {
      _places = list;
      _loading = false;
    });
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

  Future<void> _add(LocationResult location) async {
    final l = L.of(context);
    if (_places.length >= PlacesRepo.maxPlaces) {
      _toast(l.placesFull(PlacesRepo.maxPlaces));
      return;
    }
    setState(() => _busy = true);
    final place = await ref.read(placesRepoProvider).add(location, kind: _kind);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _controller.clear();
      _results = const <LocationResult>[];
    });
    if (place == null) {
      _toast(l.placesAddFailed);
      return;
    }
    await _load();
    _refreshHome();
  }

  Future<void> _remove(Place place) async {
    final l = L.of(context);
    setState(() => _busy = true);
    final ok = await ref.read(placesRepoProvider).remove(place.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      _toast(l.placesRemoveFailed);
      return;
    }
    await _load();
    _refreshHome();
  }

  /// docs/04 has no "update place" route, so changing the kind is delete + re-add. The place is
  /// re-created from its own fields, so nothing but `kind` changes.
  Future<void> _setKind(Place place, String kind) async {
    if (place.kind == kind) return;
    setState(() => _busy = true);
    final repo = ref.read(placesRepoProvider);
    await repo.remove(place.id);
    await repo.add(
      LocationResult(
        id: 'geo:${place.lat},${place.lon}',
        name: place.name,
        lat: place.lat,
        lon: place.lon,
        country: place.country,
        countryCode: place.countryCode,
        admin1: place.admin1,
        admin2: place.admin2,
      ),
      kind: kind,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
    _refreshHome();
  }

  void _refreshHome() => ref.invalidate(homeProvider(ref.read(homeQueryProvider)));

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static IconData iconForKind(String kind) => switch (kind) {
        'home' => Icons.home_outlined,
        'work' => Icons.work_outline,
        'school' => Icons.school_outlined,
        'travel' => Icons.flight_takeoff,
        _ => Icons.place_outlined,
      };

  static String labelForKind(L l, String kind) => switch (kind) {
        'home' => l.placeKindHome,
        'work' => l.placeKindWork,
        'school' => l.placeKindSchool,
        'travel' => l.placeKindTravel,
        _ => l.placeKindOther,
      };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final offline = ref.watch(offlineProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.placesTitle),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            l.placesSubtitle(PlacesRepo.maxPlaces),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_places.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.place_outlined, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l.placesEmpty)),
                  ],
                ),
              ),
            )
          else
            for (final place in _places)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(iconForKind(place.kind), color: theme.colorScheme.primary),
                  title: Text(place.name),
                  subtitle: Text(<String>[
                    if ((place.admin1 ?? '').isNotEmpty) place.admin1!,
                    if ((place.country ?? '').isNotEmpty) place.country!,
                    if (place.isCoastal) l.coastal,
                  ].join(' · ')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<String>(
                        value: PlacesRepo.kinds.contains(place.kind) ? place.kind : 'other',
                        underline: const SizedBox.shrink(),
                        onChanged: offline
                            ? null
                            : (v) {
                                if (v != null) unawaited(_setKind(place, v));
                              },
                        items: <DropdownMenuItem<String>>[
                          for (final kind in PlacesRepo.kinds)
                            DropdownMenuItem<String>(
                              value: kind,
                              child: Text(labelForKind(l, kind)),
                            ),
                        ],
                      ),
                      IconButton(
                        tooltip: l.remove,
                        onPressed: offline ? null : () => unawaited(_remove(place)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
          const Divider(height: 32),
          Text(l.placesAdd, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final kind in PlacesRepo.kinds)
                ChoiceChip(
                  avatar: Icon(iconForKind(kind), size: 16),
                  label: Text(labelForKind(l, kind)),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            onChanged: _onQueryChanged,
            enabled: !offline && _places.length < PlacesRepo.maxPlaces,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l.searchCity,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_places.length >= PlacesRepo.maxPlaces) ...[
            const SizedBox(height: 8),
            Text(l.placesFull(PlacesRepo.maxPlaces),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 8),
          for (final result in _results)
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: Text(result.name),
              subtitle: Text(result.subtitle),
              onTap: _busy ? null : () => unawaited(_add(result)),
            ),
        ],
      ),
    );
  }
}
