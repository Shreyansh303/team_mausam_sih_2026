import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import '../renderers/bar_chart.dart';
import '../renderers/charts.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Full-screen body for the `bar_chart` renderer (docs/02 cards 25 `rainfall_outlook`,
/// 32 `rain_probability`): the daily bars at full height, the *other* daily series the card
/// had to drop (mm next to probability), and the hour-by-hour curve for the focus day.
class BarChartDetail extends StatelessWidget {
  const BarChartDetail({super.key, required this.card});

  final HomeCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = card.data;
    final isProbability = card.type == 'rain_probability';
    final days = BarChartSpec.rows(isProbability ? d['by_day'] : d['daily']);

    // The series the card body did not draw: mm for rain_probability, % for rainfall_outlook.
    final secondary = <SeriesPoint>[];
    for (final day in days) {
      final v = asDouble(day[isProbability ? 'mm' : 'prob_pct']);
      if (v == null) continue;
      secondary.add(SeriesPoint(value: v, label: Fmt.dayShort(asStringOrNull(day['date']))));
    }

    final hourly = <SeriesPoint>[];
    for (final h in BarChartSpec.rows(d['hourly_focus'])) {
      final v = asDouble(h['prob_pct']);
      if (v == null) continue;
      hourly.add(SeriesPoint(value: v, label: Fmt.hourLabel(asStringOrNull(h['time']))));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BarChartRenderer(card: card, expanded: true),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(isProbability ? L.of(context).expectedRainfallMm : L.of(context).rainChancePct,
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          SeriesBarChart(
            points: secondary,
            color: theme.colorScheme.primary,
            height: 150,
            maxY: isProbability ? null : 100,
            barWidth: 18,
          ),
        ],
        if (hourly.length >= 2) ...[
          const SizedBox(height: 24),
          Text(L.of(context).hourByHourFocus, style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          SeriesLineChart(
            points: hourly,
            color: theme.colorScheme.primary,
            height: 160,
            minY: 0,
            maxY: 100,
            labelEvery: 3,
          ),
        ],
      ],
    );
  }
}
