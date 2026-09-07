import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import 'charts.dart';
import 'parts.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `bar_chart`:
/// "daily mm/probability bars with focus day highlighted".
///
/// docs/02 cards 25 `rainfall_outlook` (`daily[7]: {date, mm, prob_pct}` + 24 h/72 h/7 d totals)
/// and 32 `rain_probability` (`by_day[7]: {date, prob_pct, mm}` + a `focus_date`, which is the
/// event the user is planning around). Both are drawn with the same fl_chart bars; what differs
/// is which number is the bar — millimetres for the farmer, probability for the event planner —
/// and which day carries the outline.
class BarChartRenderer extends StatelessWidget {
  const BarChartRenderer({super.key, required this.card, this.expanded = false});

  final HomeCard card;

  /// The detail page adds the second series and keeps every summary stat.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = BarChartSpec.of(card);
    if (spec == null || spec.points.isEmpty) {
      return const RendererEmpty(message: 'No daily rainfall data.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (spec.verdict != null)
              Pill(
                label: Fmt.humanize(spec.verdict),
                color: spec.color,
                icon: Icons.umbrella_outlined,
                dense: true,
              ),
            const Spacer(),
            Text(
              spec.axisNote,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SeriesBarChart(
          points: spec.points,
          color: spec.color,
          highlightIndex: spec.focusIndex,
          height: expanded ? 190 : 132,
          maxY: spec.maxY,
          barWidth: expanded ? 22 : 16,
        ),
        if (spec.focusLabel != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 13, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                spec.focusLabel!,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
        if (spec.stats.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              for (final s in spec.stats) StatCell(label: s.label, value: s.value),
            ],
          ),
        ],
        if (spec.advice != null) ...[
          const SizedBox(height: 10),
          Text(spec.advice!,
              maxLines: expanded ? 6 : 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// The bars plus everything drawn around them, resolved from one card's `data`.
class BarChartSpec {
  const BarChartSpec({
    required this.points,
    required this.color,
    required this.axisNote,
    this.focusIndex,
    this.focusLabel,
    this.verdict,
    this.advice,
    this.maxY,
    this.stats = const <KeyValue>[],
  });

  final List<SeriesPoint> points;
  final Color color;
  final String axisNote;
  final int? focusIndex;
  final String? focusLabel;
  final String? verdict;
  final String? advice;
  final double? maxY;
  final List<KeyValue> stats;

  static const Color _blue = Color(0xFF1565C0);

  /// docs/02 card 32 — `dry < 20 | possible < 50 | likely < 75 | wet`.
  static Color verdictColor(String? verdict) {
    switch (verdict) {
      case 'wet':
        return const Color(0xFFD32F2F);
      case 'likely':
        return const Color(0xFFF28C28);
      case 'possible':
        return const Color(0xFFF5C518);
      case 'dry':
        return const Color(0xFF2E7D32);
      default:
        return _blue;
    }
  }

  static List<Map<String, dynamic>> rows(Object? raw) => raw is List
      ? raw.map(asMapOrNull).whereType<Map<String, dynamic>>().toList()
      : const <Map<String, dynamic>>[];

  static BarChartSpec? of(HomeCard card) {
    final d = card.data;

    if (card.type == 'rain_probability') {
      final days = rows(d['by_day']);
      if (days.isEmpty) return null;
      final focusDate = asStringOrNull(d['focus_date']);
      var focusIndex = -1;
      final points = <SeriesPoint>[];
      for (var i = 0; i < days.length; i++) {
        final date = asStringOrNull(days[i]['date']);
        if (date != null && date == focusDate) focusIndex = i;
        points.add(SeriesPoint(
          value: asDouble(days[i]['prob_pct']) ?? 0,
          label: Fmt.dayShort(date),
        ));
      }
      final verdict = asStringOrNull(d['verdict']);
      return BarChartSpec(
        points: points,
        color: verdictColor(verdict),
        axisNote: 'Chance of rain, % per day',
        maxY: 100,
        focusIndex: focusIndex < 0 ? null : focusIndex,
        focusLabel: asStringOrNull(d['focus_label']) == null
            ? null
            : 'Focus day · ${asStringOrNull(d['focus_label'])}',
        verdict: verdict,
        advice: asStringOrNull(d['advice']),
        stats: <KeyValue>[
          if (focusIndex >= 0)
            KeyValue('On the day', Fmt.pct(asNum(days[focusIndex]['prob_pct']))),
          if (focusIndex >= 0 && asNum(days[focusIndex]['mm']) != null)
            KeyValue('Expected', Fmt.mm(asNum(days[focusIndex]['mm']))),
        ],
      );
    }

    // rainfall_outlook and anything else publishing `daily[{date, mm}]`.
    final days = rows(d['daily']);
    if (days.isEmpty) return null;
    var wettest = 0;
    final points = <SeriesPoint>[];
    for (var i = 0; i < days.length; i++) {
      final mm = asDouble(days[i]['mm']) ?? 0;
      if (mm > (asDouble(days[wettest]['mm']) ?? 0)) wettest = i;
      points.add(SeriesPoint(value: mm, label: Fmt.dayShort(asStringOrNull(days[i]['date']))));
    }
    final anyRain = points.any((p) => p.value > 0);
    return BarChartSpec(
      points: points,
      color: _blue,
      axisNote: 'Rainfall, mm per day',
      focusIndex: anyRain ? wettest : null,
      focusLabel: anyRain
          ? 'Wettest day · ${Fmt.dayLong(asStringOrNull(days[wettest]['date']))}'
          : null,
      advice: asStringOrNull(d['advice']),
      stats: <KeyValue>[
        if (asNum(d['next_24h_mm']) != null)
          KeyValue('Next 24 h', Fmt.mm(asNum(d['next_24h_mm']))),
        if (asNum(d['next_72h_mm']) != null)
          KeyValue('Next 72 h', Fmt.mm(asNum(d['next_72h_mm']))),
        if (asNum(d['next_7d_mm']) != null)
          KeyValue('Next 7 d', Fmt.mm(asNum(d['next_7d_mm']))),
        if (asNum(d['rain_days']) != null)
          KeyValue('Rain days', '${asInt(d['rain_days'])} of ${days.length}'),
      ],
    );
  }
}
