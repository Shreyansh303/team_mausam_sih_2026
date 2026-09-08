import '../api_client.dart';
import '../models/json.dart';

/// One RainViewer frame: `{time, path}` (docs/04 `GET /weather/radar`).
class RadarTileFrame {
  const RadarTileFrame({required this.time, required this.path, this.isForecast = false});

  final String time;
  final String path;

  /// `true` for the `nowcast` half of the response — drawn with a "forecast" label so a
  /// predicted echo is never presented as an observation (CLAUDE.md §6).
  final bool isForecast;
}

/// docs/04 `GET /weather/radar` → `{host, past:[{time,path}], nowcast:[{time,path}],
/// tile_template}`.
class RadarFrames {
  const RadarFrames({
    required this.host,
    required this.tileTemplate,
    this.past = const <RadarTileFrame>[],
    this.nowcast = const <RadarTileFrame>[],
  });

  final String host;
  final String tileTemplate;
  final List<RadarTileFrame> past;
  final List<RadarTileFrame> nowcast;

  /// Past frames then nowcast frames — the order the map's slider scrubs through.
  List<RadarTileFrame> get all => <RadarTileFrame>[...past, ...nowcast];

  bool get isEmpty => all.isEmpty || tileTemplate.isEmpty;

  /// The template carries a literal `{path}` placeholder that one frame fills in.
  String tileUrlFor(RadarTileFrame frame) => tileTemplate.replaceAll('{path}', frame.path);

  factory RadarFrames.fromJson(Map<String, dynamic> json) => RadarFrames(
        host: asString(json['host']),
        tileTemplate: asString(json['tile_template']),
        past: _frames(json['past']),
        nowcast: _frames(json['nowcast'], isForecast: true),
      );

  static List<RadarTileFrame> _frames(Object? raw, {bool isForecast = false}) {
    if (raw is! List) return const <RadarTileFrame>[];
    final out = <RadarTileFrame>[];
    for (final item in raw) {
      final m = asMapOrNull(item);
      final path = asStringOrNull(m?['path']);
      if (m == null || path == null) continue;
      out.add(RadarTileFrame(
        time: asString(m['time']),
        path: path,
        isForecast: isForecast,
      ));
    }
    return out;
  }
}

/// docs/06_MOBILE_SPEC.md §Layout `radar_repo`. Returns `null` rather than throwing: the map
/// page has to open with the base map even when the backend is down.
class RadarRepo {
  RadarRepo({required ApiClient api}) : _api = api; // ignore: prefer_initializing_formals

  final ApiClient _api;

  Future<RadarFrames?> load() async {
    try {
      final frames = RadarFrames.fromJson(await _api.getJson('/weather/radar'));
      return frames.isEmpty ? null : frames;
    } on ApiException {
      return null;
    }
  }
}
