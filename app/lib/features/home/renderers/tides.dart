import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import 'charts.dart';
import 'parts.dart';
import '../../../l10n/gen/app_localizations.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `tides`:
/// "24-h tide curve with high/low markers and 'Estimated' chip".
///
/// docs/02 card 17 publishes the four turning points (`events[]: {time, type, height_m}`), not a
/// curve, so [TideCurve.of] fills the gaps the way the backend's own model does: a half-cosine
/// between consecutive extremes. That is an interpolation of an estimate, which is why the chip
/// and the backend's `disclaimer` are not optional here — docs/00 principle 6, honest data.
class TidesRenderer extends StatelessWidget {
  const TidesRenderer({super.key, required this.card, this.expanded = false});

  final HomeCard card;

  /// The detail page draws the curve full height and lists every turning point.
  final bool expanded;

  static const Color high = Color(0xFF1565C0);
  static const Color low = Color(0xFF00897B);

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final d = card.data;
    final curve = TideCurve.of(card);
    final next = asMapOrNull(d['next']);
    final trend = asStringOrNull(d['trend']);
    final nowHeight = asNum(d['now_height_m']);
    final disclaimer = asStringOrNull(d['disclaimer']);

    if (curve == null) {
      return RendererEmpty(message: l.noTideTable);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (nowHeight != null)
              Text(l.metresNow(Fmt.num1(nowHeight)),
                  style: theme.textTheme.titleSmall),
            if (trend != null) ...[
              const SizedBox(width: 8),
              Pill(
                label: Fmt.humanize(trend),
                color: trend == 'rising' ? high : low,
                icon: trend == 'rising' ? Icons.trending_up : Icons.trending_down,
                dense: true,
              ),
            ],
            const Spacer(),
            // The `Estimated` chip lives in the card header (docs/06 §Card shell) and in the
            // detail page's own header, so drawing it here too showed it twice on one card.
            // Kept for any host that renders the body on its own — C1.
            if (!card.isEstimated)
              Pill(
                label: l.estimated,
                color: const Color(0xFF8E8E8E),
                icon: Icons.calculate_outlined,
                dense: true,
              ),
          ],
        ),
        const SizedBox(height: 10),
        SeriesLineChart(
          points: curve.points,
          color: high,
          height: expanded ? 200 : 118,
          labelEvery: expanded ? 6 : 12,
          markers: curve.markers,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final e in (expanded ? curve.events : curve.events.take(4)))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    e.isHigh ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 13,
                    color: e.isHigh ? high : low,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${e.isHigh ? l.tideHigh : l.tideLow} '
                    '${Fmt.time(e.time.toIso8601String())}',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${Fmt.num1(e.height)} m',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
          ],
        ),
        if (next != null) ...[
          const SizedBox(height: 8),
          Text(
            l.nextTide(
              asStringOrNull(next['type']) == 'high' ? l.tideHigh : l.tideLow,
              Fmt.time(asStringOrNull(next['time'])),
              Fmt.num1(asNum(next['height_m'])),
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (disclaimer != null) ...[
          const SizedBox(height: 8),
          Text(
            disclaimer,
            maxLines: expanded ? 6 : 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// One turning point of the tide.
class TideEvent {
  const TideEvent({required this.time, required this.height, required this.isHigh});

  final DateTime time;
  final double height;
  final bool isHigh;
}

/// The interpolated curve plus the markers that sit on the real published extremes.
class TideCurve {
  const TideCurve({required this.points, required this.markers, required this.events});

  final List<SeriesPoint> points;
  final List<SeriesMarker> markers;
  final List<TideEvent> events;

  /// Sample step of the interpolated curve.
  static const Duration step = Duration(minutes: 20);

  static TideCurve? of(HomeCard card) {
    final raw = card.data['events'];
    if (raw is! List) return null;

    final events = <TideEvent>[];
    for (final item in raw) {
      final m = asMapOrNull(item);
      if (m == null) continue;
      final t = Fmt.wallClock(asStringOrNull(m['time']));
      final h = asDouble(m['height_m']);
      if (t == null || h == null) continue;
      events.add(TideEvent(time: t, height: h, isHigh: asStringOrNull(m['type']) == 'high'));
    }
    if (events.length < 2) return null;
    events.sort((a, b) => a.time.compareTo(b.time));

    final points = <SeriesPoint>[];
    final markers = <SeriesMarker>[];
    for (var i = 0; i < events.length - 1; i++) {
      final a = events[i];
      final b = events[i + 1];
      final span = b.time.difference(a.time).inMinutes;
      if (span <= 0) continue;
      final steps = math.max(1, span ~/ step.inMinutes);
      for (var s = 0; s < steps; s++) {
        final f = s / steps;
        // Half-cosine between two extremes — the shape a single harmonic produces.
        final value = (a.height + b.height) / 2 +
            (a.height - b.height) / 2 * math.cos(math.pi * f);
        final at = a.time.add(Duration(minutes: (span * f).round()));
        if (s == 0) {
          markers.add(SeriesMarker(
            index: points.length,
            color: a.isHigh ? TidesRenderer.high : TidesRenderer.low,
          ));
        }
        points.add(SeriesPoint(value: value, label: Fmt.hourLabel(at.toIso8601String())));
      }
    }
    final last = events.last;
    markers.add(SeriesMarker(
      index: points.length,
      color: last.isHigh ? TidesRenderer.high : TidesRenderer.low,
    ));
    points.add(SeriesPoint(
      value: last.height,
      label: Fmt.hourLabel(last.time.toIso8601String()),
    ));

    return TideCurve(points: points, markers: markers, events: events);
  }
}
