import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import 'parts.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../l10n/labels.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `timeline`:
/// "horizontal bar of windows with verdict colours and labels".
///
/// Three card types share it and each names its verdict differently (docs/02 cards 12
/// `best_workout_window` → `score`/`label`, 22 `school_commute` → `verdict`, 28
/// `commute_conditions` → `impact`), so [TimelineWindow.parse] normalises them to one shape:
/// a time range, a coloured verdict, a few stats and the backend's own reasons.
///
/// The bar itself is drawn to scale: every window sits at its real position inside the span the
/// card covers, which is what makes "the morning run is fine, the pickup is not" readable at a
/// glance instead of being two equal boxes.
class TimelineRenderer extends StatelessWidget {
  const TimelineRenderer({super.key, required this.card, this.expanded = false});

  final HomeCard card;

  /// The detail page keeps every stat and every reason line.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final windows = TimelineWindow.parse(card, l);
    if (windows.isEmpty) {
      final reason = asStringOrNull(card.data['no_good_window_reason']) ??
          asStringOrNull(card.data['advice']);
      return RendererEmpty(message: reason ?? l.noWindow);
    }
    final overall = asStringOrNull(card.data['overall_verdict']);
    final advice = asStringOrNull(card.data['advice']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (overall != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Pill(
              label: l.overallWithVerdict(qualityLabel(l, overall)),
              color: TimelineWindow.verdictColor(overall),
              icon: TimelineWindow.verdictIcon(overall),
              dense: true,
            ),
          ),
        TimelineBar(windows: windows),
        const SizedBox(height: 12),
        for (final w in windows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TimelineWindowRow(window: w, expanded: expanded),
          ),
        // The card shell already prints `insight.detail` under the headline, and the engine
        // usually reuses the same sentence for both (school_commute, commute_conditions).
        // Printing it twice in one card reads like a rendering bug — C1.
        if (advice != null && advice.isNotEmpty && advice != card.insight?.detail) ...[
          const SizedBox(height: 2),
          Text(advice,
              maxLines: expanded ? 8 : 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// One normalised window of a timeline card.
class TimelineWindow {
  const TimelineWindow({
    required this.title,
    required this.verdict,
    required this.color,
    this.start,
    this.end,
    this.stats = const <KeyValue>[],
    this.reasons = const <String>[],
    this.icon,
  });

  final String title;
  final String verdict;
  final Color color;
  final DateTime? start;
  final DateTime? end;
  final List<KeyValue> stats;
  final List<String> reasons;
  final IconData? icon;

  String get range => start == null
      ? ''
      : '${Fmt.time(start!.toIso8601String())} – ${Fmt.time(end?.toIso8601String())}';

  /// docs/02 — `good|caution|poor|avoid` (school run) and `low|moderate|high|severe` (commute)
  /// map onto the same IMD-style ladder as the card severities.
  static Color verdictColor(String? v) {
    switch (v?.toLowerCase()) {
      case 'good':
      case 'low':
      case 'great':
        return const Color(0xFF2E7D32);
      case 'caution':
      case 'moderate':
      case 'fair':
        return const Color(0xFFF5C518);
      case 'poor':
      case 'high':
        return const Color(0xFFF28C28);
      case 'avoid':
      case 'severe':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF9CCC65);
    }
  }

  static IconData verdictIcon(String? v) {
    switch (v?.toLowerCase()) {
      case 'good':
      case 'low':
      case 'great':
        return Icons.check_circle_outline;
      case 'avoid':
      case 'severe':
        return Icons.block;
      case 'poor':
      case 'high':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  /// Score → the docs/02 card 12 label bands, used when the backend omits `label`. The key
  /// is resolved through the ARBs by `qualityLabel` (docs/06 §i18n).
  static String scoreLabelKey(double score) {
    if (score >= 80) return 'great';
    if (score >= 65) return 'good';
    if (score >= 55) return 'fair';
    return 'poor';
  }

  static List<TimelineWindow> parse(HomeCard card, L l) {
    final raw = card.data['windows'];
    final rows = raw is List
        ? raw.map(asMapOrNull).whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];
    final out = <TimelineWindow>[];

    for (final w in rows) {
      final start = Fmt.wallClock(asStringOrNull(w['start']));
      final end = Fmt.wallClock(asStringOrNull(w['end']));
      final reasons = asStringList(w['reasons']);
      final label = asStringOrNull(w['label']);

      switch (card.type) {
        case 'best_workout_window':
          final score = asDouble(w['score']) ?? 0;
          final verdictKey = label ?? scoreLabelKey(score);
          out.add(TimelineWindow(
            title: qualityLabel(l, verdictKey),
            verdict: '${score.round()}/100',
            color: verdictColor(verdictKey),
            start: start,
            end: end,
            icon: Icons.directions_run,
            stats: <KeyValue>[
              if (asNum(w['temp_c']) != null) KeyValue(l.temp, Fmt.temp(asNum(w['temp_c']))),
              if (asNum(w['aqi']) != null) KeyValue(l.aqi, '${asInt(w['aqi'])}'),
              if (asNum(w['uv']) != null) KeyValue(l.uv, Fmt.num1(asNum(w['uv']))),
              if (asNum(w['humidity_pct']) != null)
                KeyValue(l.humidity, Fmt.pct(asNum(w['humidity_pct']))),
            ],
            reasons: reasons,
          ));

        case 'commute_conditions':
          final impact = asStringOrNull(w['impact']) ?? 'low';
          final delay = asNum(w['delay_min']);
          out.add(TimelineWindow(
            title: windowLabel(l, label),
            verdict: l.impactWithLevel(levelLabel(l, impact)),
            color: verdictColor(impact),
            start: start,
            end: end,
            icon: Icons.directions_bus_outlined,
            stats: <KeyValue>[
              if (delay != null) KeyValue(l.delay, l.minutesShort(delay.round())),
              if (asNum(w['rain_prob_pct']) != null)
                KeyValue(l.rainChance, Fmt.pct(asNum(w['rain_prob_pct']))),
              if (asNum(w['visibility_km']) != null)
                KeyValue(l.visibility, Fmt.km(asNum(w['visibility_km']))),
              if (asNum(w['temp_c']) != null) KeyValue(l.temp, Fmt.temp(asNum(w['temp_c']))),
            ],
            reasons: reasons,
          ));

        default:
          // school_commute and anything else that speaks `verdict`.
          final verdict = asStringOrNull(w['verdict']) ?? asStringOrNull(w['impact']) ?? 'good';
          out.add(TimelineWindow(
            title: windowLabel(l, label),
            verdict: qualityLabel(l, verdict),
            color: verdictColor(verdict),
            start: start,
            end: end,
            icon: Icons.school_outlined,
            stats: <KeyValue>[
              if (asNum(w['temp_c']) != null) KeyValue(l.temp, Fmt.temp(asNum(w['temp_c']))),
              if (asNum(w['precip_prob_pct']) != null)
                KeyValue(l.rainChance, Fmt.pct(asNum(w['precip_prob_pct']))),
              if (asNum(w['visibility_km']) != null)
                KeyValue(l.visibility, Fmt.km(asNum(w['visibility_km']))),
              if (asNum(w['aqi']) != null) KeyValue(l.aqi, '${asInt(w['aqi'])}'),
            ],
            reasons: reasons,
          ));
      }
    }
    return out;
  }
}

/// The horizontal bar: one track spanning the whole period, each window drawn to scale.
class TimelineBar extends StatelessWidget {
  const TimelineBar({super.key, required this.windows, this.height = 34});

  final List<TimelineWindow> windows;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dated = windows.where((w) => w.start != null && w.end != null).toList();
    if (dated.isEmpty) {
      // No usable times — fall back to equal shares so the bar still communicates the verdicts.
      return SizedBox(
        height: height,
        child: Row(
          children: [
            for (final w in windows)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: w.color.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(w.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.white)),
                ),
              ),
          ],
        ),
      );
    }

    var axisStart = dated.first.start!;
    var axisEnd = dated.first.end!;
    for (final w in dated) {
      if (w.start!.isBefore(axisStart)) axisStart = w.start!;
      if (w.end!.isAfter(axisEnd)) axisEnd = w.end!;
    }
    // Breathing room on both sides so a window never touches the rounded ends.
    axisStart = axisStart.subtract(const Duration(minutes: 30));
    axisEnd = axisEnd.add(const Duration(minutes: 30));
    final total = axisEnd.difference(axisStart).inMinutes.toDouble();
    if (total <= 0) return SizedBox(height: height);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: height,
              width: width,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  for (final w in dated)
                    Positioned(
                      left: (w.start!.difference(axisStart).inMinutes / total) * width,
                      width: (w.end!.difference(w.start!).inMinutes / total * width)
                          .clamp(14.0, width),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: w.color.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          w.title,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(Fmt.time(axisStart.toIso8601String()),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text(Fmt.time(axisEnd.toIso8601String()),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

/// One window under the bar: name, clock range, verdict pill and its stats.
class TimelineWindowRow extends StatelessWidget {
  const TimelineWindowRow({super.key, required this.window, this.expanded = false});

  final TimelineWindow window;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = expanded ? window.stats : window.stats.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: window.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(window.title, style: theme.textTheme.titleSmall),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                window.range,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Pill(label: window.verdict, color: window.color, dense: true),
          ],
        ),
        if (stats.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 15, top: 4),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (final s in stats)
                  Text.rich(
                    TextSpan(children: <InlineSpan>[
                      TextSpan(
                        text: '${s.label} ',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      TextSpan(text: s.value, style: theme.textTheme.labelMedium),
                    ]),
                  ),
              ],
            ),
          ),
        if (window.reasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 15, top: 4),
            child: AdviceBullets(
              lines: window.reasons,
              max: expanded ? 6 : 1,
              color: window.color,
            ),
          ),
      ],
    );
  }
}
