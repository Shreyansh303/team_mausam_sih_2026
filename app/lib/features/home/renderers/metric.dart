import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `metric`:
/// "value + unit + category + one-line advice (+ tiny sparkline if hourly present)".
///
/// Used by pollen, uv_index, humidity, sun_times, wind, visibility and water_temp (docs/02),
/// whose `data` maps have different key names — so the renderer picks the first key it
/// recognises rather than hardcoding one card's schema.
class MetricRenderer extends StatelessWidget {
  const MetricRenderer({super.key, required this.card});

  final HomeCard card;

  /// (value, unit) for the headline number, chosen by card type then by common key names.
  static ({String value, String unit})? _headline(HomeCard card) {
    final d = card.data;

    /// `convert` turns the payload's metric number into the displayed one, so the imperial
    /// setting changes the value and the unit together (docs/04 always answers in metric).
    ({String value, String unit})? pick(
      String key,
      String unit, {
      bool integer = false,
      num? Function(num?)? convert,
    }) {
      final raw = asNum(d[key]);
      if (raw == null) return null;
      final v = convert == null ? raw : (convert(raw) ?? raw);
      return (value: integer ? '${v.round()}' : Fmt.num1(v), unit: unit);
    }

    switch (card.type) {
      case 'uv_index':
        return pick('uv_now', '') ?? pick('uv_max_today', '');
      case 'humidity':
        return pick('humidity_pct', '%', integer: true);
      case 'visibility':
        return pick('visibility_km', 'km');
      case 'wind':
        return pick('speed_kph', Fmt.speedUnit,
            integer: true, convert: Fmt.toDisplaySpeed);
      case 'water_temp':
        return pick('sst_c', Fmt.tempUnit, convert: Fmt.toDisplayTemp);
      case 'pollen':
        return pick('index', '');
      case 'sun_times':
        final sunrise = asStringOrNull(d['sunrise']);
        if (sunrise != null) return (value: Fmt.time(sunrise), unit: '');
        return null;
    }

    for (final entry in <({String key, String unit})>[
      (key: 'value', unit: ''),
      (key: 'index', unit: ''),
      (key: 'visibility_km', unit: 'km'),
      (key: 'humidity_pct', unit: '%'),
      (key: 'speed_kph', unit: Fmt.speedUnit),
      (key: 'temp_c', unit: Fmt.tempUnit),
    ]) {
      final got = pick(
        entry.key,
        entry.unit,
        convert: switch (entry.key) {
          'speed_kph' => Fmt.toDisplaySpeed,
          'temp_c' => Fmt.toDisplayTemp,
          _ => null,
        },
      );
      if (got != null) return got;
    }
    return null;
  }

  static String? _category(Map<String, dynamic> d) =>
      asStringOrNull(d['category']) ?? asStringOrNull(d['level']) ?? asStringOrNull(d['status']);

  /// The first `hourly`-style list of `{time, <scalar>}` points, for the sparkline.
  static List<double> _series(Map<String, dynamic> d) {
    for (final key in <String>['hourly', 'hourly_scores', 'fog_expected_hours', 'daily']) {
      final raw = d[key];
      if (raw is! List || raw.isEmpty) continue;
      final points = <double>[];
      for (final item in raw) {
        final m = asMapOrNull(item);
        if (m == null) continue;
        for (final entry in m.entries) {
          if (entry.key == 'time' || entry.key == 'date') continue;
          final v = asDouble(entry.value);
          if (v != null) {
            points.add(v);
            break;
          }
        }
      }
      if (points.length >= 2) return points;
    }
    return const <double>[];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = card.data;
    final headline = _headline(card);
    final category = _category(d);
    final advice = asStringOrNull(d['advice']);
    final series = _series(d);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (headline != null) ...[
              Text(headline.value,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w300)),
              if (headline.unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5, left: 2),
                  child: Text(headline.unit, style: theme.textTheme.titleSmall),
                ),
              const SizedBox(width: 12),
            ],
            if (category != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    Fmt.humanize(category),
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ),
            const Spacer(),
            if (series.isNotEmpty)
              SizedBox(
                width: 74,
                height: 26,
                child: CustomPaint(
                  painter: _SparklinePainter(series, theme.colorScheme.primary),
                ),
              ),
          ],
        ),
        if (advice != null && advice.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(advice,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final span = (max - min).abs() < 1e-9 ? 1.0 : max - min;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - min) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}
