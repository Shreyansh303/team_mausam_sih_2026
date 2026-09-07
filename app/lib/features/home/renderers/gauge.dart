import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import 'parts.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `gauge`:
/// "semicircular gauge with category colour and value (aqi CPCB colours, comfort, soil moisture)".
///
/// Three card types share this renderer and none of them share a key
/// (docs/02 cards 7 `aqi`, 24 `soil_moisture`, 33 `comfort_index`), so the widget resolves a
/// [GaugeSpec] first — value, scale, colour stops, unit, sub-stats — and then draws one arc.
/// The colour stops are the card's own published bands, which is what makes the AQI arc read as
/// the CPCB strip Good → Severe rather than a generic red-to-green ramp.
class GaugeRenderer extends StatelessWidget {
  const GaugeRenderer({super.key, required this.card, this.large = false});

  final HomeCard card;

  /// The detail page draws the same gauge bigger and keeps every sub-stat.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = GaugeSpec.of(card);
    if (spec == null) {
      return const RendererEmpty(message: 'No reading available.');
    }
    final advice = asStringOrNull(card.data['advice']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SizedBox(
            height: large ? 168 : 122,
            width: large ? 320 : 236,
            child: CustomPaint(
              painter: GaugeArcPainter(
                spec: spec,
                trackColor: theme.colorScheme.surfaceContainerHighest,
                needleColor: theme.colorScheme.onSurface,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: large ? 44 : 30),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          spec.valueText,
                          style: (large
                                  ? theme.textTheme.displaySmall
                                  : theme.textTheme.headlineMedium)
                              ?.copyWith(
                                  fontWeight: FontWeight.w400, color: spec.colorFor(spec.value)),
                        ),
                        if (spec.unit.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, left: 2),
                            child: Text(spec.unit, style: theme.textTheme.labelLarge),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Pill(label: spec.category, color: spec.colorFor(spec.value), dense: !large),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (spec.scaleNote != null)
          Center(
            child: Text(
              spec.scaleNote!,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        if (spec.stats.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final s in (large ? spec.stats : spec.stats.take(4)))
                StatCell(label: s.label, value: s.value),
            ],
          ),
        ],
        if (advice != null) ...[
          const SizedBox(height: 10),
          Text(advice,
              maxLines: large ? 6 : 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// One (upper bound, colour, name) band of a gauge scale.
class GaugeStop {
  const GaugeStop(this.max, this.color, this.name);

  final double max;
  final Color color;
  final String name;
}

/// A `label: value` pair shown under the arc.
class GaugeStat {
  const GaugeStat(this.label, this.value);

  final String label;
  final String value;
}

/// Everything the gauge needs, resolved from one card's `data`.
class GaugeSpec {
  const GaugeSpec({
    required this.value,
    required this.min,
    required this.max,
    required this.valueText,
    required this.category,
    required this.stops,
    this.unit = '',
    this.scaleNote,
    this.stats = const <GaugeStat>[],
  });

  final double value;
  final double min;
  final double max;
  final String valueText;
  final String category;
  final String unit;
  final String? scaleNote;
  final List<GaugeStop> stops;
  final List<GaugeStat> stats;

  double get fraction {
    final span = max - min;
    if (span <= 0) return 0;
    return ((value - min) / span).clamp(0.0, 1.0);
  }

  Color colorFor(double v) {
    for (final stop in stops) {
      if (v <= stop.max) return stop.color;
    }
    return stops.isEmpty ? const Color(0xFF1565C0) : stops.last.color;
  }

  /// docs/02 card 7 — the CPCB bands, which are also `AppTheme.aqiColor`.
  static const List<GaugeStop> cpcb = <GaugeStop>[
    GaugeStop(50, Color(0xFF2E7D32), 'Good'),
    GaugeStop(100, Color(0xFF9CCC65), 'Satisfactory'),
    GaugeStop(200, Color(0xFFF5C518), 'Moderate'),
    GaugeStop(300, Color(0xFFF28C28), 'Poor'),
    GaugeStop(400, Color(0xFFD32F2F), 'Very Poor'),
    GaugeStop(500, Color(0xFF7B1FA2), 'Severe'),
  ];

  /// docs/02 card 33 — Uncomfortable < 40 · Fair < 60 · Comfortable < 80 · Ideal.
  static const List<GaugeStop> comfort = <GaugeStop>[
    GaugeStop(40, Color(0xFFD32F2F), 'Uncomfortable'),
    GaugeStop(60, Color(0xFFF28C28), 'Fair'),
    GaugeStop(80, Color(0xFF9CCC65), 'Comfortable'),
    GaugeStop(100, Color(0xFF2E7D32), 'Ideal'),
  ];

  /// docs/02 card 24 — very_dry < 0.10 · dry < 0.18 · adequate < 0.30 · wet < 0.40 · saturated.
  /// Drawn on a 0–60 % volumetric scale so the useful range fills the arc.
  static const List<GaugeStop> soil = <GaugeStop>[
    GaugeStop(10, Color(0xFFB25E19), 'Very dry'),
    GaugeStop(18, Color(0xFFF28C28), 'Dry'),
    GaugeStop(30, Color(0xFF2E7D32), 'Adequate'),
    GaugeStop(40, Color(0xFF29B6F6), 'Wet'),
    GaugeStop(60, Color(0xFF1565C0), 'Saturated'),
  ];

  static GaugeSpec? of(HomeCard card) {
    final d = card.data;

    switch (card.type) {
      case 'aqi':
        final aqi = asDouble(d['aqi']);
        if (aqi == null) break;
        final dominant = asStringOrNull(d['dominant_pollutant']);
        return GaugeSpec(
          value: aqi,
          min: 0,
          max: 500,
          valueText: '${aqi.round()}',
          category: asStringOrNull(d['category']) ?? _bandName(cpcb, aqi),
          scaleNote: '${asStringOrNull(d['scale']) ?? 'CPCB'} AQI · 0–500',
          stops: cpcb,
          stats: <GaugeStat>[
            if (dominant != null) GaugeStat('Dominant', dominant),
            if (asNum(d['pm2_5']) != null) GaugeStat('PM2.5', '${Fmt.num1(asNum(d['pm2_5']))} µg/m³'),
            if (asNum(d['pm10']) != null) GaugeStat('PM10', '${Fmt.num1(asNum(d['pm10']))} µg/m³'),
            if (asNum(d['o3']) != null) GaugeStat('O₃', '${Fmt.num1(asNum(d['o3']))} µg/m³'),
            if (asNum(d['no2']) != null) GaugeStat('NO₂', '${Fmt.num1(asNum(d['no2']))} µg/m³'),
            if (asNum(d['so2']) != null) GaugeStat('SO₂', '${Fmt.num1(asNum(d['so2']))} µg/m³'),
            if (asNum(d['co']) != null) GaugeStat('CO', '${Fmt.num1(asNum(d['co']))} mg/m³'),
          ],
        );

      case 'comfort_index':
        final index = asDouble(d['index']);
        if (index == null) break;
        return GaugeSpec(
          value: index,
          min: 0,
          max: 100,
          valueText: '${index.round()}',
          category: asStringOrNull(d['category']) ?? _bandName(comfort, index),
          scaleNote: 'Comfort index · 0–100',
          stops: comfort,
          stats: <GaugeStat>[
            if (asNum(d['feels_like_c']) != null)
              GaugeStat('Feels like', Fmt.temp(asNum(d['feels_like_c']))),
            if (asNum(d['humidity_pct']) != null)
              GaugeStat('Humidity', Fmt.pct(asNum(d['humidity_pct']))),
            if (asNum(d['wind_kph']) != null) GaugeStat('Wind', Fmt.kph(asNum(d['wind_kph']))),
            if (asNum(d['uv']) != null) GaugeStat('UV', Fmt.num1(asNum(d['uv']))),
          ],
        );

      case 'soil_moisture':
        final surface = asDouble(d['surface_m3m3']);
        if (surface == null) break;
        final pct = surface * 100;
        final root = asDouble(d['root_zone_m3m3']);
        return GaugeSpec(
          value: pct,
          min: 0,
          max: 60,
          valueText: '${pct.round()}',
          unit: '%',
          category: Fmt.humanize(asStringOrNull(d['status'])),
          scaleNote: 'Volumetric water content, surface 0–1 cm',
          stops: soil,
          stats: <GaugeStat>[
            if (root != null) GaugeStat('Root zone', '${(root * 100).round()}%'),
            if (asNum(d['soil_temp_c']) != null)
              GaugeStat('Soil temp', Fmt.temp(asNum(d['soil_temp_c']))),
            if (asNum(d['days_since_rain']) != null)
              GaugeStat('Since rain', '${asInt(d['days_since_rain'])} d'),
          ],
        );
    }

    // Unknown gauge card: show whatever scalar looks like the reading, on a 0–100 scale.
    final fallback = asDouble(d['value']) ?? asDouble(d['index']) ?? asDouble(d['aqi']);
    if (fallback == null) return null;
    return GaugeSpec(
      value: fallback,
      min: 0,
      max: fallback > 100 ? 500 : 100,
      valueText: Fmt.num1(fallback),
      category: asStringOrNull(d['category']) ?? asStringOrNull(d['status']) ?? '',
      stops: fallback > 100 ? cpcb : comfort,
    );
  }

  static String _bandName(List<GaugeStop> stops, double v) {
    for (final s in stops) {
      if (v <= s.max) return s.name;
    }
    return stops.isEmpty ? '' : stops.last.name;
  }
}

/// Paints the 180° track as the scale's own colour bands plus a needle at the value.
class GaugeArcPainter extends CustomPainter {
  GaugeArcPainter({required this.spec, required this.trackColor, required this.needleColor});

  final GaugeSpec spec;
  final Color trackColor;
  final Color needleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * 0.13;
    final radius = math.min(size.width / 2, size.height) - stroke;
    if (radius <= 0) return;
    final center = Offset(size.width / 2, size.height - stroke / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // Colour bands, each occupying its share of [min, max].
    final span = spec.max - spec.min;
    var from = spec.min;
    for (final stop in spec.stops) {
      final to = stop.max.clamp(spec.min, spec.max).toDouble();
      if (to <= from || span <= 0) continue;
      final start = math.pi + ((from - spec.min) / span) * math.pi;
      final sweep = ((to - from) / span) * math.pi;
      canvas.drawArc(
        rect,
        start + 0.008,
        math.max(sweep - 0.016, 0.004),
        false,
        Paint()
          ..color = stop.color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
      from = to;
    }

    // Needle.
    final angle = math.pi + spec.fraction * math.pi;
    final tip = Offset(
      center.dx + math.cos(angle) * (radius + stroke * 0.55),
      center.dy + math.sin(angle) * (radius + stroke * 0.55),
    );
    final tail = Offset(
      center.dx + math.cos(angle) * (radius - stroke * 1.35),
      center.dy + math.sin(angle) * (radius - stroke * 1.35),
    );
    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..color = needleColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(tip, stroke * 0.42, Paint()..color = needleColor);
  }

  @override
  bool shouldRepaint(covariant GaugeArcPainter old) =>
      old.spec.value != spec.value ||
      old.spec.stops != spec.stops ||
      old.trackColor != trackColor ||
      old.needleColor != needleColor;
}

/// The CPCB / comfort / soil band strip, drawn under the detail-page gauge as a legend.
class GaugeLegend extends StatelessWidget {
  const GaugeLegend({super.key, required this.spec});

  final GaugeSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        for (final stop in spec.stops)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: stop.color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 5),
              Text('${stop.name} ≤ ${Fmt.num1(stop.max)}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
      ],
    );
  }
}
