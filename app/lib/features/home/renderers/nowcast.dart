import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/icons.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import 'parts.dart';

/// docs/06_MOBILE_SPEC.md §Renderers — `nowcast`: "3-h text with severity chip".
///
/// docs/02 card 3: `issued_at, valid_till, text, severity (none|moderate|severe), hazards[],
/// source`. The nowcast is the one card whose whole content is a sentence, so the renderer's
/// job is to frame it: how severe, what hazards, and until when it is valid — a three-hour
/// statement that has expired is worse than no statement.
class NowcastRenderer extends StatelessWidget {
  const NowcastRenderer({super.key, required this.card});

  final HomeCard card;

  /// docs/02 card 3 — `none|moderate|severe`.
  static Color severityColor(String? severity) {
    switch (severity) {
      case 'severe':
        return const Color(0xFFD32F2F);
      case 'moderate':
        return const Color(0xFFF28C28);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  static IconData severityIcon(String? severity) {
    switch (severity) {
      case 'severe':
        return Icons.warning_amber_rounded;
      case 'moderate':
        return Icons.info_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = card.data;
    final text = asStringOrNull(d['text']);
    if (text == null) {
      return const RendererEmpty(message: 'No nowcast issued for this location.');
    }
    final severity = asStringOrNull(d['severity']) ?? 'none';
    final color = severityColor(severity);
    final hazards = asStringList(d['hazards']);
    final validTill = asStringOrNull(d['valid_till']);
    final issuedAt = asStringOrNull(d['issued_at']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Pill(
              label: severity == 'none' ? 'All clear' : Fmt.humanize(severity),
              color: color,
              icon: severityIcon(severity),
            ),
            const Spacer(),
            if (validTill != null)
              Text(
                'Valid till ${Fmt.time(validTill)}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(text, style: theme.textTheme.titleSmall?.copyWith(height: 1.3)),
        if (hazards.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final h in hazards)
                Pill(
                  label: Fmt.humanize(h),
                  color: color,
                  icon: AppIcons.hazard(h),
                  dense: true,
                ),
            ],
          ),
        ],
        if (issuedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            'Issued ${Fmt.time(issuedAt)}'
            '${asStringOrNull(d['source']) == null ? '' : ' · ${Fmt.humanize(asStringOrNull(d['source']))}'}',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
