import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../demo/demo_sheet.dart';
import '../providers.dart';

/// docs/06_MOBILE_SPEC.md §Layout — the home's "quick actions row": the three destinations that
/// are not cards (map, saved places, demo controls). Each is a 48 dp target with its own
/// semantics label so a screen reader announces the destination, not the icon.
class QuickActions extends ConsumerWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final lowBandwidth = ref.watch(settingsProvider).lowBandwidth;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: _Action(
              icon: Icons.map_outlined,
              label: l.quickRadar,
              onTap: () => context.push('/map'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Action(
              icon: Icons.place_outlined,
              label: l.quickPlaces,
              onTap: () => context.push('/places'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Action(
              icon: lowBandwidth ? Icons.data_saver_on : Icons.science_outlined,
              label: lowBandwidth ? l.liteBadge : l.quickDemo,
              onTap: () => DemoSheet.show(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
