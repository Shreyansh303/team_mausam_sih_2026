import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import '../renderers/tides.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Full-screen body for the `tides` renderer (docs/02 card 17 `tides`): the curve at full
/// height, the published turning points as a table, and the model disclaimer spelled out rather
/// than clipped to two lines — CLAUDE.md §6, an estimate must say so where the user can read it.
class TidesDetail extends StatelessWidget {
  const TidesDetail({super.key, required this.card});

  final HomeCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final curve = TideCurve.of(card);
    final disclaimer = asStringOrNull(card.data['disclaimer']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TidesRenderer(card: card, expanded: true),
        if (curve != null) ...[
          const SizedBox(height: 24),
          Text(L.of(context).turningPoints, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final e in curve.events)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    e.isHigh ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 15,
                    color: e.isHigh ? TidesRenderer.high : TidesRenderer.low,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: Text(
                        e.isHigh ? L.of(context).tideHigh : L.of(context).tideLow,
                        style: theme.textTheme.bodyMedium),
                  ),
                  Expanded(
                    child: Text(Fmt.dateTime(e.time.toIso8601String()),
                        style: theme.textTheme.bodyMedium),
                  ),
                  Text('${Fmt.num1(e.height)} m', style: theme.textTheme.titleSmall),
                ],
              ),
            ),
        ],
        if (disclaimer != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calculate_outlined, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(disclaimer, style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
