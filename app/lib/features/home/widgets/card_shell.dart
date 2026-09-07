import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../data/models/card.dart';
import '../../../data/repositories/events_repo.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../detail/card_detail_page.dart';
import '../providers.dart';
import '../renderers/registry.dart';
import 'reason_chips.dart';
import 'why_sheet.dart';

/// docs/06_MOBILE_SPEC.md §Card shell.
///
/// Material 3 Card (radius 16) · left accent bar coloured by `severity` · header row with icon,
/// title, `Estimated`/`Pinned` chips and an overflow menu · renderer body · footer with the
/// insight, up to two reason chips and the card's own actions.
///
/// Gestures: tap → detail (sends `tap`), long-press → why sheet, swipe-left → Show less
/// (sends `dismiss`).
class CardShell extends ConsumerWidget {
  const CardShell({super.key, required this.card, this.position});

  final HomeCard card;
  final int? position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final accent = AppTheme.cardSeverityColor(card.severity, theme.colorScheme);
    final events = ref.read(eventsRepoProvider);

    void send(String action) => events.add(EngagementEvent(
          type: card.type,
          action: action,
          meta: position == null ? null : <String, dynamic>{'position': position},
        ));

    void openDetail() {
      send('tap');
      CardDetailPage.show(context, card);
    }

    void openWhy() => WhySheet.show(context, card);

    final content = Card(
      child: InkWell(
        onTap: openDetail,
        onLongPress: openWhy,
        child: Container(
          // Severity accent bar. Drawn as a left border rather than a sibling inside an
          // IntrinsicHeight row: several renderers use LayoutBuilder, and LayoutBuilder cannot
          // answer an intrinsic-height query.
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 5)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                card: card,
                accent: accent,
                onAction: (a) {
                  switch (a) {
                    case 'details':
                      openDetail();
                    case 'pin':
                    case 'unpin':
                      send(a);
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                            SnackBar(content: Text(a == 'pin' ? l.pinToTop : l.unpin)));
                    case 'dismiss':
                      send('dismiss');
                      ref.read(demotedCardsProvider.notifier).demote(card.type);
                    case 'hide':
                      send('hide');
                      ref.read(hiddenCardsProvider.notifier).hide(card.type);
                    case 'why':
                      openWhy();
                    default:
                      openDetail();
                  }
                },
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: RendererRegistry.build(context, card),
              ),
              if (card.insight != null && card.insight!.headline.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.insight!.headline,
                        style:
                            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (card.insight!.detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          card.insight!.detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (card.reasons.isNotEmpty) ...[
                const SizedBox(height: 10),
                ReasonChips(reasons: card.reasons, onTap: openWhy),
              ],
            ],
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: card.semanticsLabel,
      child: Dismissible(
        key: ValueKey<String>('dismiss_${card.instanceId}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.arrow_downward, size: 18),
              const SizedBox(width: 6),
              Text(l.showLess),
            ],
          ),
        ),
        onDismissed: (_) {
          send('dismiss');
          ref.read(demotedCardsProvider.notifier).demote(card.type);
        },
        child: content,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.card, required this.accent, required this.onAction});

  final HomeCard card;
  final Color accent;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(AppIcons.byName(card.insight?.icon), size: 20, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.title, style: theme.textTheme.titleMedium),
              if (card.subtitle.isNotEmpty)
                Text(
                  card.subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        if (card.pinned) _Badge(label: l.pinned, icon: Icons.push_pin, color: accent),
        // docs/CLAUDE.md §6: anything modelled must be labelled, never shown as an observation.
        if (card.isEstimated)
          _Badge(
            label: l.estimated,
            icon: Icons.calculate_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        PopupMenuButton<String>(
          tooltip: '',
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: onAction,
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: 'details', child: Text(l.details)),
            PopupMenuItem<String>(
                value: card.pinned ? 'unpin' : 'pin',
                child: Text(card.pinned ? l.unpin : l.pinToTop)),
            PopupMenuItem<String>(value: 'dismiss', child: Text(l.showLess)),
            PopupMenuItem<String>(value: 'hide', child: Text(l.hideCard)),
            PopupMenuItem<String>(value: 'why', child: Text(l.whyThisCard)),
          ],
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 6, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}
