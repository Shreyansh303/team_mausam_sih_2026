import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import 'charts.dart';
import 'parts.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../l10n/labels.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `sea`:
/// "sea-state badge, wave height/period, SST, swim/surf pills, 24-h wave sparkline".
///
/// docs/02 card 16 `sea_conditions`. The two pills are the whole point of the card for the beach
/// persona: `safe_for_swimming` is the backend's own rule (wave < 1.5 m, current < 3 kph, no
/// cyclone/strong-wind warning) and `surf_rating` is its 0–5 stars — the app states both plainly
/// rather than inventing a verdict of its own.
class SeaRenderer extends StatelessWidget {
  const SeaRenderer({super.key, required this.card, this.expanded = false});

  final HomeCard card;

  /// The detail page draws the wave curve full height with its axis.
  final bool expanded;

  /// Douglas sea-state names (docs/02 card 16) → colour.
  static Color seaStateColor(String? state) {
    switch (state?.toLowerCase()) {
      case 'calm':
      case 'smooth':
        return const Color(0xFF2E7D32);
      case 'slight':
        return const Color(0xFF9CCC65);
      case 'moderate':
        return const Color(0xFFF5C518);
      case 'rough':
        return const Color(0xFFF28C28);
      case 'very rough':
      case 'high':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF1565C0);
    }
  }

  /// Wave direction in degrees → the 8-point compass name sailors actually use.
  static String compass(num? deg) {
    if (deg == null) return '';
    const names = <String>['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final i = (((deg % 360) + 22.5) ~/ 45) % 8;
    return names[i];
  }

  static List<SeriesPoint> waveSeries(HomeCard card) {
    final raw = card.data['hourly'];
    if (raw is! List) return const <SeriesPoint>[];
    final out = <SeriesPoint>[];
    for (final item in raw) {
      final m = asMapOrNull(item);
      if (m == null) continue;
      final v = asDouble(m['wave_height_m']);
      if (v == null) continue;
      out.add(SeriesPoint(value: v, label: Fmt.hourLabel(asStringOrNull(m['time']))));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final d = card.data;
    final state = asStringOrNull(d['sea_state']);
    final waveHeight = asNum(d['wave_height_m']);
    if (state == null && waveHeight == null) {
      return RendererEmpty(message: l.noMarineData);
    }
    final color = seaStateColor(state);
    final series = waveSeries(card);
    final safe = d.containsKey('safe_for_swimming') ? asBool(d['safe_for_swimming']) : null;
    final surf = asInt(d['surf_rating']);
    final advisory = asStringOrNull(d['advisory']);
    final direction = compass(asNum(d['wave_direction_deg']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state != null)
                  Pill(
                      label: seaStateLabel(l, state),
                      color: color,
                      icon: Icons.waves,
                      filled: true),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Fmt.num1(waveHeight),
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w300)),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5, left: 2),
                      child: Text('m', style: theme.textTheme.titleSmall),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    if (asNum(d['wave_period_s']) != null)
                      StatCell(label: l.period, value: '${Fmt.num1(asNum(d['wave_period_s']))} s'),
                    if (asNum(d['sst_c']) != null)
                      StatCell(label: l.seaTemp, value: Fmt.temp(asNum(d['sst_c']))),
                    if (asNum(d['swell_height_m']) != null)
                      StatCell(label: l.swell, value: '${Fmt.num1(asNum(d['swell_height_m']))} m'),
                    if (asNum(d['current_kph']) != null)
                      StatCell(label: l.current, value: Fmt.kph(asNum(d['current_kph']))),
                    if (direction.isNotEmpty)
                      StatCell(label: l.fromDirection, value: direction),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (safe != null)
              Pill(
                label: safe ? l.safeSwim : l.notSafeSwim,
                color: safe ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                icon: safe ? Icons.pool : Icons.do_not_disturb_on_outlined,
                dense: true,
              ),
            if (surf != null) SurfStars(rating: surf),
          ],
        ),
        if (series.length >= 2) ...[
          const SizedBox(height: 12),
          Text(
            l.waveHeightNextHours(series.length),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          SeriesLineChart(
            points: series,
            color: color,
            height: expanded ? 180 : 78,
            labelEvery: expanded ? 3 : 6,
            showAxis: expanded,
          ),
        ],
        if (advisory != null && advisory.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(advisory,
              maxLines: expanded ? 6 : 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// `surf_rating` 0–5 as stars (docs/02 card 16).
class SurfStars extends StatelessWidget {
  const SurfStars({super.key, required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(L.of(context).surf,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 13,
              color: color,
            ),
        ],
      ),
    );
  }
}
