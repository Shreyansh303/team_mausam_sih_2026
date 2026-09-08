import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import '../renderers/advice_list.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../l10n/labels.dart';
import 'package:intl/intl.dart';

/// Full-screen body for the `advice_list` renderer (docs/02 cards 11 `health_advisory`,
/// 20 `travel_alerts`, 21 `packing_suggestions`, 27 `planting_guidance`): every row of every
/// group, plus the context line the card has no room for (season/zone/month for planting,
/// how many saved places the packing list covers).
class AdviceListDetail extends StatelessWidget {
  const AdviceListDetail({super.key, required this.card});

  final HomeCard card;

  /// Month names come from `intl` in the active locale rather than an ARB list of twelve.
  static String _monthName(BuildContext context, int month) =>
      DateFormat.MMMM(Localizations.localeOf(context).toLanguageTag())
          .format(DateTime(2026, month));

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final d = card.data;
    final context_ = <String>[
      if (asStringOrNull(d['season']) != null)
        l.seasonWithName(seasonLabel(l, asStringOrNull(d['season']))),
      if (asStringOrNull(d['zone']) != null)
        l.zoneWithName(Fmt.humanize(asStringOrNull(d['zone']))),
      if (asInt(d['month']) != null && asInt(d['month'])! >= 1 && asInt(d['month'])! <= 12)
        _monthName(context, asInt(d['month'])!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (context_.isNotEmpty) ...[
          Text(
            context_.join(' · '),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
        ],
        AdviceListRenderer(card: card, expanded: true),
      ],
    );
  }
}
