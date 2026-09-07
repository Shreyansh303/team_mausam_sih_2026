import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../data/models/card.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../renderers/generic.dart';
import '../renderers/registry.dart';
import 'gauge_detail.dart';

/// docs/06_MOBILE_SPEC.md §Layout — `home/detail/card_detail_page.dart`,
/// "full-screen detail per renderer, charts via fl_chart".
///
/// The page is the same for every card: title, the expanded renderer body, the insight, the raw
/// `data` scalars and a provenance line. What changes is [detailBodyFor], which swaps the card's
/// compact body for a taller one — a bigger gauge with its band legend and a 24-h chart, the
/// whole advice list instead of three rows, and so on. Renderers with no dedicated detail body
/// simply reuse their card body, so this page works for all 33 card types from day one.
class CardDetailPage extends StatelessWidget {
  const CardDetailPage({super.key, required this.card});

  final HomeCard card;

  static Future<void> show(BuildContext context, HomeCard card) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => CardDetailPage(card: card)),
      );

  /// The expanded body for [card], or its normal renderer body when there is no bigger version.
  static Widget detailBodyFor(BuildContext context, HomeCard card) {
    switch (card.renderer) {
      case 'gauge':
        return GaugeDetail(card: card);
      default:
        return RendererRegistry.build(context, card);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final accent = AppTheme.cardSeverityColor(card.severity, theme.colorScheme);

    return Scaffold(
      appBar: AppBar(
        title: Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.byName(card.insight?.icon), color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.title, style: theme.textTheme.headlineSmall),
                    if (card.subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          card.subtitle,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              // CLAUDE.md §6 — a modelled number is never presented as an observation.
              if (card.isEstimated)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.calculate_outlined, size: 14),
                  label: Text(l.estimated),
                ),
            ],
          ),
          const SizedBox(height: 18),
          detailBodyFor(context, card),
          if (card.insight != null && card.insight!.headline.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(card.insight!.headline,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (card.insight!.detail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(card.insight!.detail, style: theme.textTheme.bodyMedium),
              ),
          ],
          const SizedBox(height: 24),
          Text(l.details, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          DataKeyValueGrid(data: card.data, maxEntries: 40),
          const SizedBox(height: 20),
          Text(
            'type ${card.type} · renderer ${card.renderer} · source ${card.source ?? "—"}',
            style:
                theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
