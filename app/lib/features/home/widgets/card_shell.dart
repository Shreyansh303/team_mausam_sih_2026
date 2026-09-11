import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../data/models/card.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../card_actions.dart';
import '../detail/card_detail_page.dart';
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
/// (sends `dismiss`). Every action goes through [CardActions] so the `/events` batch and the
/// `/home` refresh happen in the right order.
class CardShell extends ConsumerWidget {
  const CardShell({super.key, required this.card, this.position, this.highlighted = false});

  final HomeCard card;
  final int? position;

  /// Set for one beat after a re-rank moved this card up (docs/06 §Packages — "a highlight
  /// flash on cards whose position improved").
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final accent = AppTheme.cardSeverityColor(card.severity, theme.colorScheme);
    final actions = ref.read(cardActionsProvider);

    void openDetail() {
      actions.tap(card, position: position);
      CardDetailPage.show(context, card);
    }

    void openWhy() => WhySheet.show(context, card);

    Future<void> run(String id) async {
      switch (id) {
        case 'details':
          openDetail();
        case 'share':
          await actions.share(card);
        case 'pin':
        case 'unpin':
          await actions.pin(card, position: position);
          if (context.mounted) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                  SnackBar(content: Text(card.pinned ? l.unpinned : l.pinnedToTop)));
          }
        case 'dismiss':
          actions.dismiss(card, position: position);
        case 'hide':
          await actions.hide(card, position: position);
        case 'why':
          openWhy();
        case 'open_map':
          context.push('/map');
        case 'open_places':
          context.push('/places');
        case 'open_settings':
          context.push('/settings');
        default:
          openDetail();
      }
    }

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
              _Header(card: card, accent: accent, onAction: run),
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
              if (card.actions.isNotEmpty) ...[
                const SizedBox(height: 4),
                CardActionsRow(card: card, onAction: run),
              ],
            ],
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: card.semanticsLabel,
      button: true,
      onTapHint: l.details,
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
        onDismissed: (_) => actions.dismiss(card, position: position),
        child: highlighted
            ? _RerankHighlight(color: theme.colorScheme.primary, child: content)
            : content,
      ),
    );
  }
}

/// docs/06 §Card shell footer — "actions from `card.actions`". The backend already localizes
/// `label` and swaps `pin`→`unpin`, so the ids are rendered exactly as they arrive
/// (the fixture corpus in docs/fixtures/, docs/04_API_CONTRACT.md).
class CardActionsRow extends StatelessWidget {
  const CardActionsRow({super.key, required this.card, required this.onAction});

  final HomeCard card;
  final Future<void> Function(String id) onAction;

  static const Map<String, IconData> _icons = <String, IconData>{
    'details': Icons.open_in_new,
    'share': Icons.share_outlined,
    'pin': Icons.push_pin_outlined,
    'unpin': Icons.push_pin,
    'dismiss': Icons.arrow_downward,
    'hide': Icons.visibility_off_outlined,
    'open_map': Icons.map_outlined,
    'open_places': Icons.place_outlined,
    'open_settings': Icons.settings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        for (final action in card.actions)
          TextButton.icon(
            onPressed: () => onAction(action.id),
            icon: Icon(_icons[action.id] ?? Icons.chevron_right, size: 16),
            label: Text(action.label),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.standard,
              minimumSize: const Size(48, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
      ],
    );
  }
}

/// A short primary-tinted flash over a card whose rank improved.
class _RerankHighlight extends StatelessWidget {
  const _RerankHighlight({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: 0),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOut,
      builder: (context, t, inner) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.9 * t), width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(color: color.withValues(alpha: 0.28 * t), blurRadius: 18 * t),
          ],
        ),
        child: inner,
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.card, required this.accent, required this.onAction});

  final HomeCard card;
  final Color accent;
  final Future<void> Function(String action) onAction;

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
        // docs/00 principle 6: anything modelled is labelled, never shown as an observation.
        if (card.isEstimated)
          _Badge(
            label: l.estimated,
            icon: Icons.calculate_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        PopupMenuButton<String>(
          tooltip: l.cardMenu,
          // 48 dp minimum target (Material a11y guidance, docs/06 §accessibility).
          padding: const EdgeInsets.all(14),
          iconSize: 20,
          icon: const Icon(Icons.more_vert),
          onSelected: onAction,
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: 'details', child: Text(l.details)),
            PopupMenuItem<String>(
                value: card.pinned ? 'unpin' : 'pin',
                child: Text(card.pinned ? l.unpin : l.pinToTop)),
            PopupMenuItem<String>(value: 'dismiss', child: Text(l.showLess)),
            PopupMenuItem<String>(value: 'hide', child: Text(l.hideCard)),
            PopupMenuItem<String>(value: 'share', child: Text(l.share)),
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
