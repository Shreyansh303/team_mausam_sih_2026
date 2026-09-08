import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import '../renderers/charts.dart';
import '../renderers/parts.dart';
import '../renderers/timeline.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Full-screen body for the `timeline` renderer (docs/02 cards 12 `best_workout_window`,
/// 22 `school_commute`, 28 `commute_conditions`): every window with all of its stats and
/// reasons, plus the hour-by-hour score curve the card only hints at.
class TimelineDetail extends StatelessWidget {
  const TimelineDetail({super.key, required this.card});

  final HomeCard card;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final d = card.data;
    final scores = _points(d['hourly_scores'], 'score');
    final traffic = asMapOrNull(d['traffic']);
    final isSchoolDay = d.containsKey('is_school_day') ? asBool(d['is_school_day']) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TimelineRenderer(card: card, expanded: true),
        if (scores.length >= 2) ...[
          const SizedBox(height: 24),
          Text(l.hourlyScore, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            l.hourlyScoreHelp,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          SeriesLineChart(
            points: scores,
            color: theme.colorScheme.primary,
            height: 170,
            minY: 0,
            maxY: 100,
            labelEvery: 3,
          ),
        ],
        if (traffic != null && traffic.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(l.traffic, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              StatCell(
                label: l.congestion,
                value: Fmt.pct(asNum(traffic['congestion_pct'])),
                icon: Icons.traffic_outlined,
              ),
              const SizedBox(width: 20),
              // CLAUDE.md §6 — the traffic index is modelled, and it says so.
              if (asStringOrNull(traffic['source']) == 'estimated')
                Pill(
                  label: l.estimated,
                  color: const Color(0xFF8E8E8E),
                  icon: Icons.calculate_outlined,
                  dense: true,
                ),
            ],
          ),
        ],
        if (isSchoolDay != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(isSchoolDay ? Icons.school_outlined : Icons.beach_access_outlined, size: 16),
              const SizedBox(width: 6),
              Text(isSchoolDay ? l.schoolDay : l.notSchoolDay,
                  style: theme.textTheme.bodyMedium),
            ],
          ),
        ],
      ],
    );
  }

  static List<SeriesPoint> _points(Object? raw, String key) {
    if (raw is! List) return const <SeriesPoint>[];
    final out = <SeriesPoint>[];
    for (final item in raw) {
      final m = asMapOrNull(item);
      if (m == null) continue;
      final v = asDouble(m[key]);
      if (v == null) continue;
      out.add(SeriesPoint(value: v, label: Fmt.hourLabel(asStringOrNull(m['time']))));
    }
    return out;
  }
}
