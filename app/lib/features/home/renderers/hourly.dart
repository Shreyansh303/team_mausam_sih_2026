import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/icons.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import '../../../l10n/gen/app_localizations.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `hourly`:
/// "horizontal 24-h strip (icon, temp, rain %)".
/// `data.hours[24]` per docs/02 card 4.
class HourlyRenderer extends StatelessWidget {
  const HourlyRenderer({super.key, required this.card});

  final HomeCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = card.data['hours'];
    final hours = raw is List
        ? raw.map(asMapOrNull).whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];
    if (hours.isEmpty) {
      return Text(L.of(context).noHourlyData, style: theme.textTheme.bodySmall);
    }

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final h = hours[i];
          final prob = asNum(h['precip_prob_pct']);
          final code = asInt(h['condition_code']);
          final isDay = asBool(h['is_day'], fallback: true);
          final iconName =
              asStringOrNull(h['icon']) ?? AppIcons.conditionIconName(code, isDay: isDay);
          return SizedBox(
            width: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  i == 0 ? L.of(context).now : Fmt.hourLabel(asStringOrNull(h['time'])),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Icon(AppIcons.byName(iconName), size: 22, color: theme.colorScheme.primary),
                const SizedBox(height: 6),
                Text(Fmt.temp(asNum(h['temp_c']), degreeOnly: true),
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.water_drop_outlined,
                        size: 11,
                        color: (prob ?? 0) >= 40
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text(
                      Fmt.pct(prob),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: (prob ?? 0) >= 40
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: (prob ?? 0) >= 40 ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
