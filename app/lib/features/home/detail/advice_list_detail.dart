import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import '../renderers/advice_list.dart';

/// Full-screen body for the `advice_list` renderer (docs/02 cards 11 `health_advisory`,
/// 20 `travel_alerts`, 21 `packing_suggestions`, 27 `planting_guidance`): every row of every
/// group, plus the context line the card has no room for (season/zone/month for planting,
/// how many saved places the packing list covers).
class AdviceListDetail extends StatelessWidget {
  const AdviceListDetail({super.key, required this.card});

  final HomeCard card;

  static const List<String> _months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = card.data;
    final context_ = <String>[
      if (asStringOrNull(d['season']) != null) '${Fmt.humanize(asStringOrNull(d['season']))} season',
      if (asStringOrNull(d['zone']) != null) '${Fmt.humanize(asStringOrNull(d['zone']))} zone',
      if (asInt(d['month']) != null && asInt(d['month'])! >= 1 && asInt(d['month'])! <= 12)
        _months[asInt(d['month'])! - 1],
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
