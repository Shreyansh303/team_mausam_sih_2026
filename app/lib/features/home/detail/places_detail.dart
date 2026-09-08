import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../../../data/models/card.dart';
import '../renderers/parts.dart';
import '../renderers/places.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../l10n/labels.dart';

/// Full-screen body for the `places` renderer (docs/02 card 19 `saved_places`): the same places
/// as a vertical list, where each row has room for the local time, the hi/lo, the rain chance
/// and the warning severity spelled out instead of a coloured dot.
class PlacesDetail extends StatelessWidget {
  const PlacesDetail({super.key, required this.card});

  final HomeCard card;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final places = PlacesRenderer.parse(card);
    if (places.isEmpty) {
      return RendererEmpty(message: l.noSavedPlaces);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in places)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(p.icon, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: theme.textTheme.titleMedium),
                          Text(
                            <String>[
                              if (p.country != null) p.country!,
                              l.localTimeAt(Fmt.time(p.localTime)),
                            ].join(' · '),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(Fmt.temp(p.tempC), style: theme.textTheme.headlineSmall),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    StatCell(
                      label: l.highLow,
                      value: '${Fmt.temp(p.tmaxC, degreeOnly: true)} / '
                          '${Fmt.temp(p.tminC, degreeOnly: true)}',
                    ),
                    if (p.precipProbPct != null)
                      StatCell(label: l.rainChance, value: Fmt.pct(p.precipProbPct)),
                    if (p.highestSeverity != null)
                      StatCell(
                        label: l.activeWarning,
                        value: severityLabel(l, p.highestSeverity),
                        color: AppTheme.warningSeverityColor(p.highestSeverity),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
