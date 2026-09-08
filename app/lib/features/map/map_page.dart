import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models/card.dart';
import '../../data/models/json.dart';
import '../../data/models/warning.dart';
import '../../data/repositories/radar_repo.dart';
import '../../l10n/gen/app_localizations.dart';
import '../home/providers.dart';
import '../home/renderers/radar.dart' show RadarRenderer;

/// docs/06_MOBILE_SPEC.md §Layout `map/ map_page (flutter_map: OSM tiles, RainViewer radar
/// overlay with frame slider, warning circles/markers, user marker)`.
///
/// Radar frames come from `GET /weather/radar` (docs/04); the warnings are the ones already on
/// screen — the `warnings` card of the current `/home` payload (docs/02 card 2) plus anything
/// that arrived over the WebSocket since.
///
/// Low-bandwidth mode (`?lite=1`) draws the base map and the warnings but **no radar tiles**,
/// which is the whole point of the setting (docs/06 §Home behaviour).
class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  static const String osmTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String userAgent = 'com.teammausam.mausam_app';

  RadarFrames? _frames;
  int _index = 0;
  bool _loading = true;
  bool _playing = false;
  bool _showRadar = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (ref.read(settingsProvider).lowBandwidth) {
      setState(() {
        _loading = false;
        _showRadar = false;
      });
      return;
    }
    final frames = await ref.read(radarRepoProvider).load();
    if (!mounted) return;
    setState(() {
      _frames = frames;
      _index = frames == null ? 0 : (frames.past.length - 1).clamp(0, frames.all.length - 1);
      _loading = false;
    });
  }

  void _togglePlay() {
    final frames = _frames;
    if (frames == null || frames.all.length < 2) return;
    setState(() => _playing = !_playing);
    _ticker?.cancel();
    if (!_playing) return;
    _ticker = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % frames.all.length);
    });
  }

  /// The warnings drawn on the map: whatever the `warnings` card is carrying, plus a warning
  /// that arrived over `/ws/alerts` and is not in the payload yet.
  List<WeatherWarning> _warnings() {
    final result = ref.watch(homeProvider(ref.watch(homeQueryProvider))).value;
    final out = <WeatherWarning>[];
    final seen = <String>{};
    for (final card in result?.home.allCards ?? const <HomeCard>[]) {
      if (card.renderer != 'warnings') continue;
      final raw = card.data['warnings'];
      if (raw is! List) continue;
      for (final item in raw) {
        final map = asMapOrNull(item);
        if (map == null) continue;
        final warning = WeatherWarning.fromJson(map);
        if (seen.add(warning.id)) out.add(warning);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final query = ref.watch(homeQueryProvider);
    final settings = ref.watch(settingsProvider);
    final frames = _frames;
    final all = frames?.all ?? const <RadarTileFrame>[];
    final index = all.isEmpty ? 0 : _index.clamp(0, all.length - 1);
    final warnings = _warnings();
    final center = LatLng(query.lat, query.lon);
    final tileProvider = RadarRenderer.tileProviderFactory?.call();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.mapTitle),
        actions: [
          IconButton(
            tooltip: l.mapToggleRadar,
            onPressed: all.isEmpty ? null : () => setState(() => _showRadar = !_showRadar),
            icon: Icon(_showRadar ? Icons.layers : Icons.layers_clear_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: 7),
                  children: <Widget>[
                    TileLayer(
                      urlTemplate: osmTemplate,
                      userAgentPackageName: userAgent,
                      tileProvider: tileProvider,
                      errorTileCallback: (_, _, _) {},
                    ),
                    if (_showRadar && frames != null && all.isNotEmpty)
                      TileLayer(
                        urlTemplate: frames.tileUrlFor(all[index]),
                        userAgentPackageName: userAgent,
                        tileProvider: tileProvider,
                        errorTileCallback: (_, _, _) {},
                      ),
                    CircleLayer(
                      circles: <CircleMarker>[
                        for (final w in warnings)
                          if (w.lat != null && w.lon != null)
                            CircleMarker(
                              point: LatLng(w.lat!, w.lon!),
                              radius: ((w.radiusKm ?? 75) * 1000).toDouble(),
                              useRadiusInMeter: true,
                              color: AppTheme.warningSeverityColor(w.severity)
                                  .withValues(alpha: 0.18),
                              borderColor: AppTheme.warningSeverityColor(w.severity),
                              borderStrokeWidth: 2,
                            ),
                      ],
                    ),
                    MarkerLayer(
                      markers: <Marker>[
                        for (final w in warnings)
                          if (w.lat != null && w.lon != null)
                            Marker(
                              point: LatLng(w.lat!, w.lon!),
                              width: 34,
                              height: 34,
                              child: Tooltip(
                                message: w.title,
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppTheme.warningSeverityColor(w.severity),
                                  size: 28,
                                ),
                              ),
                            ),
                        Marker(
                          point: center,
                          width: 26,
                          height: 26,
                          child: Icon(Icons.my_location,
                              size: 22, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_loading)
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                if (settings.lowBandwidth)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _Chip(icon: Icons.data_saver_on, label: l.lowBandwidthRadarOff),
                  ),
              ],
            ),
          ),
          Material(
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: _playing ? l.pause : l.play,
                        onPressed: all.length < 2 ? null : _togglePlay,
                        icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle),
                      ),
                      Expanded(
                        child: all.isEmpty
                            ? Text(
                                settings.lowBandwidth ? l.lowBandwidthRadarOff : l.radarNoFrames,
                                style: theme.textTheme.bodySmall,
                              )
                            : Text(
                                '${Fmt.dateTime(all[index].time)} · '
                                '${all[index].isForecast ? l.radarForecastFrame : l.radarPastFrame}',
                                style: theme.textTheme.bodySmall,
                              ),
                      ),
                      if (all.isNotEmpty)
                        Text('${index + 1}/${all.length}',
                            style: theme.textTheme.labelSmall),
                    ],
                  ),
                  if (all.length > 1)
                    Slider(
                      value: index.toDouble(),
                      min: 0,
                      max: (all.length - 1).toDouble(),
                      divisions: all.length - 1,
                      label: Fmt.time(all[index].time),
                      onChanged: (v) => setState(() {
                        _playing = false;
                        _ticker?.cancel();
                        _index = v.round();
                      }),
                    ),
                  if (warnings.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final w in warnings)
                          _Chip(
                            icon: Icons.warning_amber_rounded,
                            label: w.title,
                            color: AppTheme.warningSeverityColor(w.severity),
                          ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text(
                    l.mapAttribution,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        border: Border.all(color: tint),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}
