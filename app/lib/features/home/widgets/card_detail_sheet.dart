import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../data/models/card.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../renderers/generic.dart';
import '../renderers/registry.dart';

/// A modal stand-in for the per-renderer detail pages that land in B2
/// (docs/06 §Layout `home/detail/card_detail_page.dart`).
///
/// It shows the full renderer body plus the raw `data` scalars, which is enough for B1 to prove
/// the payload round-trips and gives the demo something to open on tap.
class CardDetailSheet extends StatelessWidget {
  const CardDetailSheet({super.key, required this.card});

  final HomeCard card;

  static Future<void> show(BuildContext context, HomeCard card) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (_, controller) =>
              CardDetailSheet(card: card)._body(context, controller),
        ),
      );

  Widget _body(BuildContext context, ScrollController controller) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final accent = AppTheme.cardSeverityColor(card.severity, theme.colorScheme);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            Icon(AppIcons.byName(card.insight?.icon), color: accent),
            const SizedBox(width: 10),
            Expanded(child: Text(card.title, style: theme.textTheme.headlineSmall)),
          ],
        ),
        if (card.subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(card.subtitle,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        const SizedBox(height: 16),
        RendererRegistry.build(context, card),
        if (card.insight != null) ...[
          const SizedBox(height: 16),
          Text(card.insight!.headline,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (card.insight!.detail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(card.insight!.detail, style: theme.textTheme.bodyMedium),
            ),
        ],
        const SizedBox(height: 20),
        Text(l.details, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DataKeyValueGrid(data: card.data, maxEntries: 40),
        const SizedBox(height: 16),
        Text(
          'type ${card.type} · renderer ${card.renderer} · source ${card.source ?? "—"}',
          style:
              theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => _body(context, ScrollController());
}
