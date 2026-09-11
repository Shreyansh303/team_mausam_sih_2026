// Thin `fl_chart` wrappers shared by the card renderers and their detail pages.
//
// docs/06 §Layout puts charts in the detail pages ("charts via fl_chart"); the card bodies use
// the same widgets at a smaller height. Everything here is display-only — no touch handling,
// no animation — because a card body must never steal the shell's tap gesture.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// One labelled point of a series.
class SeriesPoint {
  const SeriesPoint({required this.value, this.label = '', this.color});

  final double value;
  final String label;
  final Color? color;
}

/// A filled line chart over an evenly spaced series (hourly AQI, wave height, tide curve…).
class SeriesLineChart extends StatelessWidget {
  const SeriesLineChart({
    super.key,
    required this.points,
    required this.color,
    this.height = 120,
    this.labelEvery = 4,
    this.showAxis = true,
    this.minY,
    this.maxY,
    this.markers = const <SeriesMarker>[],
    this.curved = true,
  });

  final List<SeriesPoint> points;
  final Color color;
  final double height;

  /// Draw a bottom label every N points (0 disables labels).
  final int labelEvery;
  final bool showAxis;
  final double? minY;
  final double? maxY;
  final List<SeriesMarker> markers;
  final bool curved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.length < 2) return SizedBox(height: height);

    var lo = minY ?? points.first.value;
    var hi = maxY ?? points.first.value;
    for (final p in points) {
      if (minY == null && p.value < lo) lo = p.value;
      if (maxY == null && p.value > hi) hi = p.value;
    }
    if ((hi - lo).abs() < 1e-6) {
      hi = lo + 1;
      lo = lo - 1;
    }
    final pad = (hi - lo) * 0.12;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: (minY ?? lo - pad),
          maxY: (maxY ?? hi + pad),
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          lineTouchData: const LineTouchData(enabled: false),
          gridData: FlGridData(
            show: showAxis,
            drawVerticalLine: false,
            horizontalInterval: ((hi - lo) / 2).abs() < 1e-6 ? 1 : (hi - lo) / 2,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 0.6),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: showAxis && labelEvery > 0,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: labelEvery > 0,
                reservedSize: 18,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  if (labelEvery > 0 && i % labelEvery != 0) return const SizedBox.shrink();
                  final label = points[i].label;
                  if (label.isEmpty) return const SizedBox.shrink();
                  return Text(
                    label,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 9),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            verticalLines: <VerticalLine>[
              for (final m in markers)
                if (m.index >= 0 && m.index < points.length)
                  VerticalLine(
                    x: m.index.toDouble(),
                    color: m.color.withValues(alpha: 0.6),
                    strokeWidth: 1.4,
                    dashArray: const <int>[4, 3],
                  ),
            ],
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: <FlSpot>[
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].value),
              ],
              isCurved: curved,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2.2,
              dotData: FlDotData(
                show: markers.isNotEmpty,
                checkToShowDot: (spot, _) => markers.any((m) => m.index == spot.x.round()),
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 3.4,
                  color: markers
                          .firstWhere((m) => m.index == spot.x.round(),
                              orElse: () => SeriesMarker(index: -1, color: color))
                          .color,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[color.withValues(alpha: 0.28), color.withValues(alpha: 0.02)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A highlighted x position on a [SeriesLineChart] (tide high/low, peak rain hour…).
class SeriesMarker {
  const SeriesMarker({required this.index, required this.color});

  final int index;
  final Color color;
}

/// A vertical bar chart over labelled values (daily rainfall mm, rain probability…).
class SeriesBarChart extends StatelessWidget {
  const SeriesBarChart({
    super.key,
    required this.points,
    required this.color,
    this.height = 140,
    this.highlightIndex,
    this.maxY,
    this.barWidth = 16,
  });

  final List<SeriesPoint> points;
  final Color color;
  final double height;

  /// Drawn opaque with a rounded outline; every other bar is dimmed. docs/06 §Renderers —
  /// "daily mm/probability bars with focus day highlighted".
  final int? highlightIndex;
  final double? maxY;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.isEmpty) return SizedBox(height: height);

    var hi = maxY ?? 0;
    if (maxY == null) {
      for (final p in points) {
        if (p.value > hi) hi = p.value;
      }
      hi = hi <= 0 ? 1 : hi * 1.35;
    }

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: hi,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: const BarTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  final focused = i == highlightIndex;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      points[i].label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: focused
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: focused ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: <BarChartGroupData>[
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: points[i].value <= 0 ? hi * 0.006 : points[i].value,
                    width: barWidth,
                    borderRadius: BorderRadius.circular(4),
                    color: (points[i].color ?? color)
                        .withValues(alpha: highlightIndex == null || i == highlightIndex ? 1 : 0.42),
                    borderSide: i == highlightIndex
                        ? BorderSide(color: theme.colorScheme.onSurface, width: 1.2)
                        : const BorderSide(color: Colors.transparent, width: 0),
                  ),
                ],
                showingTooltipIndicators: const <int>[],
              ),
          ],
        ),
      ),
    );
  }
}
