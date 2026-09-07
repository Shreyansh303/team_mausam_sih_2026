import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/icons.dart';
import '../../data/models/user.dart';
import '../../l10n/gen/app_localizations.dart';
import '../home/providers.dart';
import '../onboarding/language_page.dart';
import '../onboarding/persona_labels.dart';

/// docs/06_MOBILE_SPEC.md §Layout `settings/settings_page`.
///
/// B1 ships the two settings the demo cannot run without — **backend URL** and **language** —
/// plus persona editing and the low-bandwidth toggle. Units, home location, school/commute
/// windows, reset-learning and about land in B2.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _urlController =
      TextEditingController(text: ref.read(settingsProvider).backendUrl);
  String? _urlError;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    final l = L.of(context);
    final raw = _urlController.text.trim();
    final uri = Uri.tryParse(raw);
    if (raw.isEmpty || uri == null || !uri.isAbsolute || !uri.scheme.startsWith('http')) {
      setState(() => _urlError = l.invalidUrl);
      return;
    }
    setState(() => _urlError = null);
    await ref.read(settingsProvider.notifier).setBackendUrl(raw);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l.saved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionTitle(l.settingsLanguage),
          for (final lang in LanguagePage.languages)
            RadioListTile<String>(
              value: lang.code,
              // ignore: deprecated_member_use
              groupValue: settings.language,
              // ignore: deprecated_member_use
              onChanged: (v) {
                if (v != null) ref.read(settingsProvider.notifier).setLanguage(v);
              },
              title: Text(lang.label),
              subtitle: lang.label == lang.english ? null : Text(lang.english),
              contentPadding: EdgeInsets.zero,
            ),

          const Divider(height: 28),
          _SectionTitle(l.settingsBackendUrl),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: l.settingsBackendUrlHint,
              errorText: _urlError,
              helperMaxLines: 3,
              helperText: l.settingsBackendUrlHelp,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                tooltip: l.save,
                onPressed: _saveUrl,
                icon: const Icon(Icons.check),
              ),
            ),
            onSubmitted: (_) => _saveUrl(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final preset in <String>{
                AppConfig.defaultBackendUrl,
                'http://localhost:8000',
                'http://10.0.2.2:8000',
              })
                ActionChip(
                  label: Text(preset),
                  onPressed: () {
                    _urlController.text = preset;
                    _saveUrl();
                  },
                ),
            ],
          ),

          const Divider(height: 28),
          _SectionTitle(l.settingsPersonas),
          Text(l.onboardingPersonaSubtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in Persona.ids)
                FilterChip(
                  avatar: Icon(AppIcons.persona(id), size: 16),
                  label: Text(personaLabel(l, id)),
                  selected: settings.personas.contains(id),
                  onSelected: (selected) {
                    final next = <String>[...settings.personas];
                    if (selected) {
                      if (next.length >= 3) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                              SnackBar(content: Text(l.personaLimitReached)));
                        return;
                      }
                      next.add(id);
                    } else {
                      if (next.length == 1) return; // at least one persona is required
                      next.remove(id);
                    }
                    ref.read(settingsProvider.notifier).setPersonas(next);
                  },
                ),
            ],
          ),

          const Divider(height: 28),
          SwitchListTile(
            value: settings.lowBandwidth,
            onChanged: (v) => ref.read(settingsProvider.notifier).setLowBandwidth(v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Low-bandwidth mode'),
            subtitle: const Text('Sends lite=1: trimmed hourly arrays, no radar tiles.'),
          ),

          const Divider(height: 28),
          _SectionTitle(l.settingsAbout),
          Text(AppConfig.appNameLong, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'SIH 2026 · PS 26076 · a Team Mausam prototype. Not affiliated with, and not '
            'endorsed by, the India Meteorological Department.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (settings.homeLocation != null) ...[
            const SizedBox(height: 10),
            Text(
              'Location: ${settings.homeLocation!.name} '
              '(${settings.homeLocation!.lat.toStringAsFixed(2)}, '
              '${settings.homeLocation!.lon.toStringAsFixed(2)})',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
