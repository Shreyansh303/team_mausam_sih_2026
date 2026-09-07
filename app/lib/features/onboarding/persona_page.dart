import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
import '../../data/models/user.dart';
import '../../l10n/gen/app_localizations.dart';
import '../home/providers.dart';
import 'onboarding_scaffold.dart';
import 'persona_labels.dart';

/// docs/06_MOBILE_SPEC.md §onboarding — "8 persona tiles with icon + one-line, pick 1–3,
/// first = primary".
class PersonaPage extends ConsumerStatefulWidget {
  const PersonaPage({super.key});

  @override
  ConsumerState<PersonaPage> createState() => _PersonaPageState();
}

class _PersonaPageState extends ConsumerState<PersonaPage> {
  late final List<String> _selected = <String>[...ref.read(settingsProvider).personas];

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < 3) {
        _selected.add(id); // append: index 0 stays the primary persona
      } else {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(L.of(context).personaLimitReached)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);

    return OnboardingScaffold(
      step: 1,
      title: l.onboardingPersonaTitle,
      subtitle: l.onboardingPersonaSubtitle,
      primaryLabel: '${l.continueLabel} · ${l.selectedCount(_selected.length)}',
      onPrimary: _selected.isEmpty
          ? null
          : () async {
              await ref.read(settingsProvider.notifier).setPersonas(_selected);
              if (context.mounted) context.go('/onboarding/location');
            },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 560 ? 3 : 2;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              for (final persona in Persona.ids)
                _PersonaTile(
                  id: persona,
                  label: personaLabel(l, persona),
                  tagline: personaTagline(l, persona),
                  selected: _selected.contains(persona),
                  primary: _selected.isNotEmpty && _selected.first == persona,
                  primaryLabel: l.personaPrimary,
                  onTap: () => _toggle(persona),
                  scheme: theme.colorScheme,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PersonaTile extends StatelessWidget {
  const _PersonaTile({
    required this.id,
    required this.label,
    required this.tagline,
    required this.selected,
    required this.primary,
    required this.primaryLabel,
    required this.onTap,
    required this.scheme,
  });

  final String id;
  final String label;
  final String tagline;
  final bool selected;
  final bool primary;
  final String primaryLabel;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label. $tagline',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.persona(id),
                    color: selected ? scheme.onPrimaryContainer : scheme.primary,
                  ),
                  const Spacer(),
                  if (primary)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        primaryLabel,
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.onPrimary),
                      ),
                    )
                  else if (selected)
                    Icon(Icons.check_circle, size: 18, color: scheme.primary),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  tagline,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
