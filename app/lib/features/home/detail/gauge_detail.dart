import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import '../renderers/charts.dart';
import '../renderers/gauge.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Full-screen body for the `gauge` renderer (docs/02 cards 7 `aqi`, 24 `soil_moisture`,
/// 33 `comfort_index`): the same arc drawn large, the scale's band legend, and the card's own
/// series — hourly AQI, the 7-day comfort index — as an fl_chart line.
class GaugeDetail extends StatelessWidget {
  const GaugeDetail({super.key, required this.card});

  final HomeCard card;

  /// `hourly[{time, aqi}]` / `daily[{date, index}]` → chart points, whichever the card carries.
  static ({List<SeriesPoint> points, String title, int labelEvery})? _series(
      HomeCard card, L l) {
    final d = card.data;

    List<Map<String, dynamic>> rows(Object? raw) => raw is List
        ? raw.map(asMapOrNull).whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];

    final hourly = rows(d['hourly']);
    if (hourly.isNotEmpty) {
      final points = <SeriesPoint>[];
      for (final h in hourly) {
        final v = asDouble(h['aqi']) ?? asDouble(h['value']) ?? asDouble(h['index']);
        if (v == null) continue;
        points.add(SeriesPoint(value: v, label: Fmt.hourLabel(asStringOrNull(h['time']))));
      }
      if (points.length >= 2) {
        return (points: points, title: l.nextHours, labelEvery: 3);
      }
    }

    final daily = rows(d['daily']);
    if (daily.isNotEmpty) {
      final points = <SeriesPoint>[];
      for (final day in daily) {
        final v = asDouble(day['index']) ?? asDouble(day['value']);
        if (v == null) continue;
        points.add(SeriesPoint(value: v, label: Fmt.dayShort(asStringOrNull(day['date']))));
      }
      if (points.length >= 2) {
        return (points: points, title: l.next7Days, labelEvery: 1);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final spec = GaugeSpec.of(card, l);
    final series = _series(card, l);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GaugeRenderer(card: card, large: true),
        if (spec != null) ...[
          const SizedBox(height: 18),
          Text(l.scale, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          GaugeLegend(spec: spec),
        ],
        if (series != null) ...[
          const SizedBox(height: 22),
          Text(series.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          SeriesLineChart(
            points: series.points,
            color: spec == null ? theme.colorScheme.primary : spec.colorFor(spec.value),
            height: 170,
            labelEvery: series.labelEvery,
          ),
        ],
        _BestHours(card: card),
      ],
    );
  }
}

/// `comfort_index.best_hours_today[≤2]: {start, end, index}` (docs/02 card 33).
class _BestHours extends StatelessWidget {
  const _BestHours({required this.card});

  final HomeCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = card.data['best_hours_today'];
    final rows = raw is List
        ? raw.map(asMapOrNull).whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Text(L.of(context).bestHoursToday, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${Fmt.time(asStringOrNull(row['start']))} – '
                  '${Fmt.time(asStringOrNull(row['end']))}',
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                Text(Fmt.num1(asNum(row['index'])), style: theme.textTheme.titleSmall),
              ],
            ),
          ),
      ],
    );
  }
}
