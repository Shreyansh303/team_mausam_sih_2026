import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import '../renderers/alert.dart';
import '../renderers/charts.dart';

/// Full-screen body for the `alert` renderer (docs/02 cards 15 `heat_alert`, 23 `rain_alert`,
/// 26 `frost_alert`, 30 `storm_fog_alert`): the whole advice list, every stat, and — for the
/// rain alert — the hour-by-hour rain the card only summarises as "peak 80 %".
class AlertDetail extends StatelessWidget {
  const AlertDetail({super.key, required this.card});

  final HomeCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = AlertSpec.of(card);
    final rows = _rows(card.data['hourly']);

    final mm = <SeriesPoint>[];
    final prob = <SeriesPoint>[];
    for (final h in rows) {
      final label = Fmt.hourLabel(asStringOrNull(h['time']));
      final v = asDouble(h['precip_mm']);
      final p = asDouble(h['precip_prob_pct']);
      if (v != null) mm.add(SeriesPoint(value: v, label: label));
      if (p != null) prob.add(SeriesPoint(value: p, label: label));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AlertRenderer(card: card, expanded: true),
        if (mm.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Rain per hour (mm)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          SeriesBarChart(points: mm, color: spec.color, height: 150, barWidth: 12),
        ],
        if (prob.length >= 2) ...[
          const SizedBox(height: 24),
          Text('Chance of rain (%)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          SeriesLineChart(
            points: prob,
            color: theme.colorScheme.primary,
            height: 150,
            minY: 0,
            maxY: 100,
            labelEvery: 2,
          ),
        ],
      ],
    );
  }

  static List<Map<String, dynamic>> _rows(Object? raw) => raw is List
      ? raw.map(asMapOrNull).whereType<Map<String, dynamic>>().toList()
      : const <Map<String, dynamic>>[];
}
