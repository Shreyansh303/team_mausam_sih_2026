import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons.dart';
import '../../../data/models/user.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../onboarding/persona_labels.dart';
import '../providers.dart';

/// docs/06_MOBILE_SPEC.md §Home behaviour — "Persona chips: user's personas (filled) + others
/// (outlined). Tapping an outlined chip loads `/home?personas=<id>` as a temporary 'role view'
/// with a 'Viewing as Fitness · Save' strip."
class PersonaChips extends ConsumerWidget {
  const PersonaChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final settings = ref.watch(settingsProvider);
    final role = ref.watch(roleViewProvider);
    final mine = settings.personas;
    final others = Persona.ids.where((p) => !mine.contains(p)).toList();

    return SizedBox(
      // 48 dp so the chips are a comfortable tap target (docs/06 §accessibility).
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final id in <String>[...mine, ...others])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(AppIcons.persona(id), size: 16),
                label: Text(personaLabel(l, id)),
                tooltip: personaTagline(l, id),
                selected: role == null ? mine.contains(id) : role == id,
                showCheckmark: false,
                onSelected: (_) {
                  final notifier = ref.read(roleViewProvider.notifier);
                  if (role == id) {
                    notifier.clear();
                  } else if (mine.contains(id) && role == null) {
                    // Already part of the profile — nothing to preview.
                  } else {
                    notifier.view(id);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// The "Viewing as X · Save" strip shown while a role view is active.
class RoleViewStrip extends ConsumerWidget {
  const RoleViewStrip({super.key, required this.personaId});

  final String personaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(AppIcons.persona(personaId),
              size: 16, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.viewingAs(personaLabel(l, personaId)),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
          TextButton(
            onPressed: () async {
              final settings = ref.read(settingsProvider);
              final next = <String>[
                personaId,
                ...settings.personas.where((p) => p != personaId),
              ].take(3).toList();
              await ref.read(settingsProvider.notifier).setPersonas(next);
              ref.read(roleViewProvider.notifier).clear();
            },
            child: Text(l.saveRole),
          ),
          TextButton(
            onPressed: () => ref.read(roleViewProvider.notifier).clear(),
            child: Text(l.clearRoleView),
          ),
        ],
      ),
    );
  }
}
