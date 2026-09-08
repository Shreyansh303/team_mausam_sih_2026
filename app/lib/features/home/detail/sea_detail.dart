import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../../../data/models/json.dart';
import '../renderers/parts.dart';
import '../renderers/sea.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../l10n/labels.dart';

/// Full-screen body for the `sea` renderer (docs/02 card 16 `sea_conditions`): the 24-h wave
/// curve at full height with its axis, plus the Douglas scale the `sea_state` badge comes from
/// so a judge can see why "Slight" is 1.14 m and not a guess.
class SeaDetail extends StatelessWidget {
  const SeaDetail({super.key, required this.card});

  final HomeCard card;

  /// docs/02 card 16 — the Douglas bands, in metres. The key is the payload's own
  /// `sea_state` value, so the highlight below can match it; the label is localized.
  static const List<({String key, String range})> douglas = <({String key, String range})>[
    (key: 'calm', range: '< 0.1 m'),
    (key: 'smooth', range: '< 0.5 m'),
    (key: 'slight', range: '< 1.25 m'),
    (key: 'moderate', range: '< 2.5 m'),
    (key: 'rough', range: '< 4 m'),
    (key: 'very_rough', range: '< 6 m'),
    (key: 'high', range: '≥ 6 m'),
  ];

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final series = SeaRenderer.waveSeries(card);
    final state = asStringOrNull(card.data['sea_state']);

    double? peak;
    String peakAt = '';
    for (final p in series) {
      if (peak == null || p.value > peak) {
        peak = p.value;
        peakAt = p.label;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeaRenderer(card: card, expanded: true),
        if (peak != null) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              StatCell(
                  label: l.highestWaves,
                  value: '${Fmt.num1(peak)} m',
                  icon: Icons.waves),
              const SizedBox(width: 24),
              StatCell(label: l.around, value: peakAt, icon: Icons.schedule),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text(l.douglasScale, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            for (final band in douglas)
              Pill(
                label: '${seaStateLabel(l, band.key)} ${band.range}',
                color: SeaRenderer.seaStateColor(band.key.replaceAll('_', ' ')),
                dense: true,
                filled: state != null &&
                    band.key == state.toLowerCase().replaceAll(' ', '_'),
              ),
          ],
        ),
      ],
    );
  }
}
