import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import '../../../data/models/warning.dart';
import '../../../l10n/gen/app_localizations.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `warnings`:
/// "list of severity-coloured tiles with validity, tap → detail".
/// `data` shape is docs/02 card 2: `{warnings: Warning[], district, highest_severity}`.
class WarningsRenderer extends StatelessWidget {
  const WarningsRenderer({super.key, required this.card});

  final HomeCard card;

  @override
  Widget build(BuildContext context) {
    final warnings = asList(card.data['warnings'], WeatherWarning.fromJson);
    if (warnings.isEmpty) {
      return Text(
        L.of(context).allClear,
        style: TextStyle(color: AppTheme.green),
      );
    }
    return Column(
      children: [
        for (final w in warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: WarningTile(warning: w),
          ),
      ],
    );
  }
}

/// One severity-coloured warning tile, reused by the banner target and the detail sheet.
class WarningTile extends StatelessWidget {
  const WarningTile({super.key, required this.warning, this.dense = false});

  final WeatherWarning warning;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final color = AppTheme.warningSeverityColor(warning.severity);

    return Container(
      padding: EdgeInsets.all(dense ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.hazard(warning.hazard), color: color, size: dense ? 18 : 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        warning.title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        Fmt.humanize(warning.severity),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (!dense && warning.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    warning.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  children: [
                    if (warning.validTo != null)
                      _Meta(
                        icon: Icons.schedule,
                        text: l.validUntil(Fmt.dateTime(warning.validTo)),
                      ),
                    if ((warning.district ?? '').isNotEmpty)
                      _Meta(icon: Icons.place_outlined, text: warning.district!),
                    if ((warning.source ?? '').isNotEmpty)
                      _Meta(icon: Icons.verified_outlined, text: warning.source!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(text,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
