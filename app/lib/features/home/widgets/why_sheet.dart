import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons.dart';
import '../../../data/models/card.dart';
import '../../../data/repositories/events_repo.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../onboarding/persona_labels.dart';
import '../providers.dart';
import 'reason_chips.dart';

/// docs/06_MOBILE_SPEC.md §Why sheet — "Lists `reasons` with icons; shows personas that drove
/// it; buttons: Pin to top, Show less, Hide this card, Restore hidden cards (if any). Each
/// sends the event and refreshes home."
///
/// B1 ships the UI plus the local effect (demote / hide) and queues the engagement event.
/// B2 turns the queued events into the server-side `/me/card-prefs` round trip.
class WhySheet extends ConsumerWidget {
  const WhySheet({super.key, required this.card});

  final HomeCard card;

  static Future<void> show(BuildContext context, HomeCard card) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => WhySheet(card: card),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final hidden = ref.watch(hiddenCardsProvider);
    final events = ref.read(eventsRepoProvider);

    void send(String action) {
      events.add(EngagementEvent(type: card.type, action: action));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.byName(card.insight?.icon), color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(card.title, style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 4),
            Text(l.whyThisCard,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            if (card.reasons.isEmpty)
              Text('—', style: theme.textTheme.bodyMedium)
            else
              for (final reason in card.reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(ReasonChips.iconFor(reason.code),
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(reason.text, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
            if (card.personas.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(l.drivenBy, style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final p in card.personas)
                    Chip(
                      avatar: Icon(AppIcons.persona(p), size: 16),
                      label: Text(personaLabel(l, p)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (card.score > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Rank score ${card.score.toStringAsFixed(2)} · urgency ${card.urgency.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const Divider(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    send(card.pinned ? 'unpin' : 'pin');
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.push_pin_outlined),
                  label: Text(card.pinned ? l.unpin : l.pinToTop),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    send('dismiss');
                    ref.read(demotedCardsProvider.notifier).demote(card.type);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_downward),
                  label: Text(l.showLess),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    send('hide');
                    ref.read(hiddenCardsProvider.notifier).hide(card.type);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: Text(l.hideCard),
                ),
                if (hidden.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      for (final type in hidden) {
                        events.add(EngagementEvent(type: type, action: 'unhide'));
                      }
                      ref.read(hiddenCardsProvider.notifier).restoreAll();
                      ref.read(demotedCardsProvider.notifier).restoreAll();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.restore),
                    label: Text(l.restoreHidden),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
