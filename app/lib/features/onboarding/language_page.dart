import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../home/providers.dart';
import 'onboarding_scaffold.dart';

/// docs/06_MOBILE_SPEC.md §onboarding — page 1 of 3.
class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});

  /// Endonyms, so a speaker can find their language without reading English.
  /// docs/06 §i18n ships five ARBs; `en`/`hi` are complete and the other three are partial,
  /// with `flutter gen-l10n` falling back to English per key.
  static const List<({String code, String label, String english})> languages = [
    (code: 'en', label: 'English', english: 'English'),
    (code: 'hi', label: 'हिन्दी', english: 'Hindi'),
    (code: 'mr', label: 'मराठी', english: 'Marathi'),
    (code: 'ta', label: 'தமிழ்', english: 'Tamil'),
    (code: 'bn', label: 'বাংলা', english: 'Bengali'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final current = ref.watch(settingsProvider).language;

    return OnboardingScaffold(
      step: 0,
      title: l.onboardingLanguageTitle,
      subtitle: l.onboardingLanguageSubtitle,
      primaryLabel: l.continueLabel,
      onPrimary: () => context.go('/onboarding/personas'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final lang in languages)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RadioListTile<String>(
                value: lang.code,
                // ignore: deprecated_member_use
                groupValue: current,
                // ignore: deprecated_member_use
                onChanged: (v) {
                  if (v != null) ref.read(settingsProvider.notifier).setLanguage(v);
                },
                title: Text(lang.label, style: Theme.of(context).textTheme.titleMedium),
                subtitle: lang.label == lang.english ? null : Text(lang.english),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            L.of(context).moreLanguagesNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
