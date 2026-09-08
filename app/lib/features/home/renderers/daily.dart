import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/icons.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import '../../../l10n/gen/app_localizations.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `daily`: "7 rows (icon, hi/lo bar, rain %)".
/// `data.days[]` per docs/02 cards 5 and 31 (`extended_forecast` uses the same renderer with
/// 14 days, so the row count comes from the payload, not a constant).
class DailyRenderer extends StatelessWidget {
  const DailyRenderer({super.key, required this.card, this.maxRows = 7});

  final HomeCard card;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = card.data['days'];
    final days = raw is List
        ? raw.map(asMapOrNull).whereType<Map<String, dynamic>>().take(maxRows).toList()
        : const <Map<String, dynamic>>[];
    if (days.isEmpty) {
      return Text(L.of(context).noDailyData, style: theme.textTheme.bodySmall);
    }

    // Shared scale so the hi/lo bars are comparable across rows.
    var lo = double.infinity;
    var hi = -double.infinity;
    for (final d in days) {
      final tmin = asDouble(d['tmin_c']);
      final tmax = asDouble(d['tmax_c']);
      if (tmin != null && tmin < lo) lo = tmin;
      if (tmax != null && tmax > hi) hi = tmax;
    }
    if (!lo.isFinite || !hi.isFinite || hi <= lo) {
      lo = 0;
      hi = 1;
    }

    return Column(
      children: [
        for (final d in days)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: _DayRow(day: d, scaleMin: lo, scaleMax: hi),
          ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.scaleMin, required this.scaleMax});

  final Map<String, dynamic> day;
  final double scaleMin;
  final double scaleMax;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tmin = asDouble(day['tmin_c']);
    final tmax = asDouble(day['tmax_c']);
    final prob = asNum(day['precip_prob_max_pct']);
    final code = asInt(day['condition_code']);
    final iconName = asStringOrNull(day['icon']) ?? AppIcons.conditionIconName(code);

    final span = scaleMax - scaleMin;
    final start = tmin == null ? 0.0 : ((tmin - scaleMin) / span).clamp(0.0, 1.0);
    final end = tmax == null ? 1.0 : ((tmax - scaleMin) / span).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            Fmt.dayShort(asStringOrNull(day['date'])),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Icon(AppIcons.byName(iconName), size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.water_drop_outlined,
                  size: 11, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  Fmt.pct(prob),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 42,
          child: Text(
            Fmt.temp(tmin, degreeOnly: true),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Positioned(
                      left: w * start,
                      width: (w * (end - start)).clamp(4.0, w),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: <Color>[
                            theme.colorScheme.primary.withValues(alpha: 0.55),
                            theme.colorScheme.error.withValues(alpha: 0.75),
                          ]),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 42,
          child: Text(
            Fmt.temp(tmax, degreeOnly: true),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
