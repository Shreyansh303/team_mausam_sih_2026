import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config.dart';
import '../../core/icons.dart';
import '../../data/models/location.dart';
import '../../data/models/user.dart';
import '../../l10n/gen/app_localizations.dart';
import '../demo/demo_sheet.dart';
import '../home/card_actions.dart';
import '../home/providers.dart';
import '../onboarding/language_page.dart';
import '../onboarding/persona_labels.dart';

/// docs/06_MOBILE_SPEC.md §Layout `settings/settings_page` — language, units, personas, home
/// location, school/commute windows, backend URL, low-bandwidth, large text, reset learning,
/// about.
///
/// Everything that belongs to the server profile (`personas`, `language`, `units`,
/// `home_location`, the two window lists) is pushed with `PUT /me/profile` by
/// `SettingsNotifier.update` — see docs/04 §Objects `User`.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _urlController =
      TextEditingController(text: ref.read(settingsProvider).backendUrl);
  String? _urlError;
  String _version = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = '${info.version}+${info.buildNumber}');
    } catch (_) {
      // package_info_plus needs platform channels; a bare test host has none.
    }
  }

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
    _toast(l.saved);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editWindow(
    List<TimeWindow> windows,
    int index,
    bool isStart,
    Future<void> Function(List<TimeWindow>) save,
  ) async {
    final window = windows[index];
    final current = _parseHhMm(isStart ? window.start : window.end);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    final value = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    final next = <TimeWindow>[...windows];
    next[index] = isStart ? window.copyWith(start: value) : window.copyWith(end: value);
    await save(next);
    if (mounted) _toast(L.of(context).saved);
  }

  static TimeOfDay _parseHhMm(String value) {
    final parts = value.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  Future<void> _changeHomeLocation() async {
    final selected = await showModalBottomSheet<LocationResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _LocationPicker(),
    );
    if (selected == null) return;
    await ref.read(settingsProvider.notifier).setHomeLocation(selected);
    if (!mounted) return;
    _toast(L.of(context).saved);
  }

  Future<void> _resetLearning() async {
    final l = L.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsResetLearning),
        content: Text(l.settingsResetLearningConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.settingsReset)),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(cardActionsProvider).resetLearning();
    if (!mounted) return;
    _toast(ok ? l.settingsResetLearningDone : l.errorGeneric);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ---------------------------------------------------------------- language
          _SectionTitle(l.settingsLanguage),
          for (final lang in LanguagePage.languages)
            RadioListTile<String>(
              value: lang.code,
              // ignore: deprecated_member_use
              groupValue: settings.language,
              // ignore: deprecated_member_use
              onChanged: (v) {
                if (v != null) notifier.setLanguage(v);
              },
              title: Text(lang.label),
              subtitle: lang.label == lang.english ? null : Text(lang.english),
              contentPadding: EdgeInsets.zero,
            ),

          // ---------------------------------------------------------------- units
          const Divider(height: 28),
          _SectionTitle(l.settingsUnits),
          SegmentedButton<String>(
            segments: <ButtonSegment<String>>[
              ButtonSegment<String>(value: 'metric', label: Text(l.unitsMetric)),
              ButtonSegment<String>(value: 'imperial', label: Text(l.unitsImperial)),
            ],
            selected: <String>{settings.units},
            onSelectionChanged: (s) => notifier.setUnits(s.first),
          ),

          // ---------------------------------------------------------------- personas
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
                        _toast(l.personaLimitReached);
                        return;
                      }
                      next.add(id);
                    } else {
                      if (next.length == 1) return; // at least one persona is required
                      next.remove(id);
                    }
                    notifier.setPersonas(next);
                  },
                ),
            ],
          ),

          // ---------------------------------------------------------------- home location
          const Divider(height: 28),
          _SectionTitle(l.settingsHomeLocation),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.place_outlined, color: theme.colorScheme.primary),
            title: Text(settings.homeLocation?.name ?? l.settingsNoLocation),
            subtitle: settings.homeLocation == null
                ? null
                : Text('${settings.homeLocation!.subtitle} · '
                    '${settings.homeLocation!.lat.toStringAsFixed(2)}, '
                    '${settings.homeLocation!.lon.toStringAsFixed(2)}'),
            trailing: TextButton(onPressed: _changeHomeLocation, child: Text(l.change)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.bookmark_border, color: theme.colorScheme.primary),
            title: Text(l.placesTitle),
            subtitle: Text(l.settingsPlacesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/places'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.map_outlined, color: theme.colorScheme.primary),
            title: Text(l.mapTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/map'),
          ),

          // ---------------------------------------------------------------- windows
          const Divider(height: 28),
          _SectionTitle(l.settingsSchoolWindows),
          _Windows(
            windows: settings.schoolWindows,
            onEdit: (i, isStart) =>
                _editWindow(settings.schoolWindows, i, isStart, notifier.setSchoolWindows),
          ),
          const SizedBox(height: 16),
          _SectionTitle(l.settingsCommuteWindows),
          _Windows(
            windows: settings.commuteWindows,
            onEdit: (i, isStart) =>
                _editWindow(settings.commuteWindows, i, isStart, notifier.setCommuteWindows),
          ),

          // ---------------------------------------------------------------- backend
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
                'http://127.0.0.1:8000',
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

          // ---------------------------------------------------------------- accessibility
          const Divider(height: 28),
          _SectionTitle(l.settingsAccessibility),
          SwitchListTile(
            value: settings.lowBandwidth,
            onChanged: notifier.setLowBandwidth,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.data_saver_on),
            title: Text(l.settingsLowBandwidth),
            subtitle: Text(l.settingsLowBandwidthHelp),
          ),
          SwitchListTile(
            value: settings.largeText,
            onChanged: notifier.setLargeText,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.format_size),
            title: Text(l.settingsLargeText),
            subtitle: Text(l.settingsLargeTextHelp),
          ),

          // ---------------------------------------------------------------- demo + learning
          const Divider(height: 28),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.science_outlined, color: theme.colorScheme.primary),
            title: Text(l.demoTitle),
            subtitle: Text(l.demoSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => DemoSheet.show(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.restart_alt, color: theme.colorScheme.error),
            title: Text(l.settingsResetLearning),
            subtitle: Text(l.settingsResetLearningHelp),
            onTap: _resetLearning,
          ),

          // ---------------------------------------------------------------- about
          const Divider(height: 28),
          _SectionTitle(l.settingsAbout),
          Text(AppConfig.appNameLong, style: theme.textTheme.bodyMedium),
          if (_version.isNotEmpty)
            Text('v$_version',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(
            l.aboutDisclaimer,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// One `TimeWindow` list with a start/end button per row (docs/04 §Objects `User`).
class _Windows extends StatelessWidget {
  const _Windows({required this.windows, required this.onEdit});

  final List<TimeWindow> windows;
  final void Function(int index, bool isStart) onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < windows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(_label(windows[i].label), style: theme.textTheme.bodyMedium),
                ),
                OutlinedButton(
                  onPressed: () => onEdit(i, true),
                  child: Text(windows[i].start),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–'),
                ),
                OutlinedButton(
                  onPressed: () => onEdit(i, false),
                  child: Text(windows[i].end),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _label(String raw) => raw
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Search sheet used by "change home location". Same `/locations/search` +
/// `/locations/popular` pair the onboarding page uses, with the same offline fallback.
class _LocationPicker extends ConsumerStatefulWidget {
  const _LocationPicker();

  @override
  ConsumerState<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<_LocationPicker> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<LocationResult> _results = const <LocationResult>[];
  List<LocationResult> _popular = const <LocationResult>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadPopular());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPopular() async {
    final list = await ref.read(locationsRepoProvider).popular();
    if (!mounted) return;
    setState(() => _popular = list.take(12).toList());
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = const <LocationResult>[]);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final list = await ref.read(locationsRepoProvider).search(q);
      if (!mounted) return;
      setState(() => _results = list);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final showing = _results.isNotEmpty ? _results : _popular;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: l.searchCity,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final city in showing)
                  ListTile(
                    leading: Icon(city.isCoastal ? Icons.waves : Icons.location_city),
                    title: Text(city.name),
                    subtitle: Text(city.subtitle),
                    onTap: () => Navigator.of(context).pop(city),
                  ),
              ],
            ),
          ),
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
