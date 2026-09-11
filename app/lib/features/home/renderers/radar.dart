import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'parts.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `radar`:
/// "small `flutter_map` with latest RainViewer frame + 'Open map'".
///
/// docs/02 card 6 publishes `host`, `frames[]: {time, path}`, `tile_template`, `center`, `zoom`
/// and `rain_within_2h_prob_pct`; the template contains a literal `{path}` placeholder that the
/// app fills with one frame's path — see [RadarSpec.tileUrlFor].
///
/// Offline behaviour is part of the spec, not an afterthought: with no frames the card draws
/// [RadarUnavailable] instead of an empty map, and when frames exist but the tiles cannot be
/// fetched flutter_map simply leaves them blank over the base map — no exception reaches the
/// card shell either way.
class RadarRenderer extends StatelessWidget {
  const RadarRenderer({super.key, required this.card, this.height = 170, this.frameIndex});

  final HomeCard card;
  final double height;

  /// Which frame to paint; defaults to the latest one the backend sent.
  final int? frameIndex;

  /// Tile provider used by both layers. Tests set this to keep the widget off the network;
  /// production leaves it null, which gives flutter_map's own network provider.
  static TileProvider Function()? tileProviderFactory;

  /// docs/06 §Home behaviour — "Low-bandwidth mode: `lite=1`, no radar tiles, no images".
  /// A static rather than a provider read, so the renderer keeps working in the widget tests
  /// that build it without a ProviderScope; `SettingsNotifier` keeps it in step.
  static bool tilesEnabled = true;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final spec = RadarSpec.of(card);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: height,
            child: spec == null || !spec.hasFrames || !tilesEnabled
                ? RadarUnavailable(spec: spec, lite: !tilesEnabled)
                : RadarMap(spec: spec, frameIndex: frameIndex ?? spec.frames.length - 1),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (spec?.rainWithin2hPct != null)
              Pill(
                label: l.rainWithin2hValue(Fmt.pct(spec!.rainWithin2hPct)),
                color: (spec.rainWithin2hPct ?? 0) >= 60
                    ? const Color(0xFFF28C28)
                    : theme.colorScheme.primary,
                icon: Icons.radar,
                dense: true,
              ),
            const Spacer(),
            TextButton.icon(
              // This used to open the card's detail page; there is now a real map route
              // (docs/06 §Layout `map/ map_page`), which is where "Open map" belongs.
              onPressed: () => context.push('/map'),
              icon: const Icon(Icons.open_in_full, size: 16),
              label: Text(l.openMap),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        if (spec != null && spec.hasFrames && tilesEnabled)
          Text(
            l.radarFrameAt(Fmt.dateTime(
                spec.frames[(frameIndex ?? spec.frames.length - 1)].time)),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// The map itself: OSM base tiles + one RainViewer frame on top.
class RadarMap extends StatelessWidget {
  const RadarMap({
    super.key,
    required this.spec,
    required this.frameIndex,
    this.interactive = false,
  });

  final RadarSpec spec;
  final int frameIndex;
  final bool interactive;

  static const String osmTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Highest zoom each tile server actually renders.
  ///
  /// RainViewer stops at z7: past that `tilecache.rainviewer.com` answers
  /// **HTTP 200** with a 256x256 PNG reading "Zoom Level Not Supported", so
  /// `errorTileCallback` never fires and flutter_map paints the placeholder over
  /// the map. `maxNativeZoom` makes it upscale the z7 tile instead of asking for
  /// one that does not exist. OSM serves to z19 and answers 400 above it.
  static const int radarMaxNativeZoom = 7;
  static const int osmMaxNativeZoom = 19;
  static const String userAgent = 'com.teammausam.mausam_app';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = frameIndex.clamp(0, spec.frames.length - 1);
    final provider = RadarRenderer.tileProviderFactory;

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(spec.lat, spec.lon),
          initialZoom: spec.zoom,
          interactionOptions: InteractionOptions(
            flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
          ),
        ),
        children: <Widget>[
          TileLayer(
            urlTemplate: osmTemplate,
            userAgentPackageName: userAgent,
            tileProvider: provider?.call(),
            maxNativeZoom: RadarMap.osmMaxNativeZoom,
            // Offline: a missing base tile leaves the surface colour, it does not throw.
            errorTileCallback: (_, _, _) {},
          ),
          TileLayer(
            urlTemplate: spec.tileUrlFor(index),
            userAgentPackageName: userAgent,
            tileProvider: provider?.call(),
            maxNativeZoom: RadarMap.radarMaxNativeZoom,
            errorTileCallback: (_, _, _) {},
          ),
          MarkerLayer(
            markers: <Marker>[
              Marker(
                point: LatLng(spec.lat, spec.lon),
                width: 22,
                height: 22,
                child: Icon(Icons.place, size: 22, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown when there is no frame to paint — no radar coverage, `?lite=1`, or offline.
class RadarUnavailable extends StatelessWidget {
  const RadarUnavailable({super.key, this.spec, this.lite = false});

  final RadarSpec? spec;

  /// `true` when the tiles were suppressed on purpose by low-bandwidth mode.
  final bool lite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radar, size: 26, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(
            lite ? L.of(context).lowBandwidthRadarOff : L.of(context).radarNoFrames,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// One radar frame.
class RadarFrame {
  const RadarFrame({required this.time, required this.path});

  final String time;
  final String path;
}

/// docs/02 card 6 `radar`, normalised.
class RadarSpec {
  const RadarSpec({
    required this.frames,
    required this.lat,
    required this.lon,
    required this.zoom,
    required this.tileTemplate,
    this.rainWithin2hPct,
  });

  final List<RadarFrame> frames;
  final double lat;
  final double lon;
  final double zoom;
  final String? tileTemplate;
  final num? rainWithin2hPct;

  bool get hasFrames => frames.isNotEmpty && tileTemplate != null;

  /// `https://…{path}/256/{z}/{x}/{y}/2/1_1.png` + `/v2/radar/<id>` → a flutter_map template.
  String tileUrlFor(int index) {
    final template = tileTemplate ?? '';
    if (frames.isEmpty) return template;
    final frame = frames[index.clamp(0, frames.length - 1)];
    return template.replaceAll('{path}', frame.path);
  }

  static RadarSpec? of(HomeCard card) {
    final d = card.data;
    final raw = d['frames'];
    final frames = <RadarFrame>[];
    if (raw is List) {
      for (final item in raw) {
        final m = asMapOrNull(item);
        if (m == null) continue;
        final path = asStringOrNull(m['path']);
        if (path == null) continue;
        frames.add(RadarFrame(time: asString(m['time']), path: path));
      }
    }
    final center = asMapOrNull(d['center']);
    final lat = asDouble(center?['lat']);
    final lon = asDouble(center?['lon']);
    if (lat == null || lon == null) return null;
    return RadarSpec(
      frames: frames,
      lat: lat,
      lon: lon,
      zoom: asDouble(d['zoom']) ?? 7,
      tileTemplate: asStringOrNull(d['tile_template']),
      rainWithin2hPct: asNum(d['rain_within_2h_prob_pct']),
    );
  }
}
