import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import '../../../l10n/gen/app_localizations.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `hero`:
/// "big temp, condition icon, feels-like, hi/lo, 4 micro-stats (humidity, wind, UV, AQI),
/// sunrise/sunset strip, 'All clear' pill or warning pill".
///
/// `data` shape is docs/02 card 1 (`current_conditions`).
class HeroRenderer extends StatelessWidget {
  const HeroRenderer({super.key, required this.card});

  final HomeCard card;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final d = card.data;

    final temp = asNum(d['temp_c']);
    final feels = asNum(d['feels_like_c']);
    final tmax = asNum(d['tmax_c']);
    final tmin = asNum(d['tmin_c']);
    final isDay = asBool(d['is_day'], fallback: true);
    final code = asInt(d['condition_code']);
    final iconName = asStringOrNull(d['icon']) ?? AppIcons.conditionIconName(code, isDay: isDay);
    final allClear = asBool(d['all_clear']);
    final aqi = asNum(d['aqi']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(AppIcons.byName(iconName), size: 56, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Fmt.temp(temp, degreeOnly: true),
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w300),
                ),
                Text(
                  asString(d['condition_text'], fallback: card.subtitle),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (feels != null)
                  Text('${l.feelsLike} ${Fmt.temp(feels, degreeOnly: true)}',
                      style: theme.textTheme.bodyMedium),
                if (tmax != null || tmin != null)
                  Text(
                    '${l.high} ${Fmt.temp(tmax, degreeOnly: true)} · ${l.low} ${Fmt.temp(tmin, degreeOnly: true)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Micro(label: l.humidity, value: Fmt.pct(asNum(d['humidity_pct']))),
            _Micro(label: l.wind, value: Fmt.kph(asNum(d['wind_kph']))),
            _Micro(label: l.uv, value: Fmt.num1(asNum(d['uv_index']))),
            _Micro(
              label: l.aqi,
              value: aqi == null ? '--' : '${aqi.round()}',
              color: aqi == null ? null : AppTheme.aqiColor(aqi),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(AppIcons.byName('sunrise'), size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(Fmt.time(asStringOrNull(d['sunrise'])), style: theme.textTheme.bodySmall),
            const SizedBox(width: 14),
            Icon(AppIcons.byName('sunset'), size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(Fmt.time(asStringOrNull(d['sunset'])), style: theme.textTheme.bodySmall),
            const Spacer(),
            _StatusPill(allClear: allClear, label: allClear ? l.allClear : card.subtitle),
          ],
        ),
      ],
    );
  }
}

class _Micro extends StatelessWidget {
  const _Micro({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value,
              style: theme.textTheme.titleSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.allClear, required this.label});

  final bool allClear;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = allClear ? AppTheme.green : AppTheme.orange;
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(allClear ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
