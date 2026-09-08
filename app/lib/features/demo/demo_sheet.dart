import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/icons.dart';
import '../../data/models/user.dart';
import '../../data/ws/alerts_socket.dart';
import '../../l10n/gen/app_localizations.dart';
import '../home/live_alerts.dart';
import '../home/providers.dart';
import '../onboarding/persona_labels.dart';

/// docs/06_MOBILE_SPEC.md §Layout `demo/ demo_sheet (time override picker, scenario dropdown,
/// open admin console, simulate offline)`, plus the persona switch the judge demo in
/// docs/00 §Demo script leans on.
///
/// Everything here is a **request-scoped** override (docs/04 §GET /home params `scenario`,
/// `now_override`, `personas`): nothing is persisted, and "Reset" puts the app back on live
/// data. The global equivalents live in the admin console, which this sheet links to.
class DemoSheet extends ConsumerWidget {
  const DemoSheet({super.key});

  /// docs/05 §Scenarios. Fetched from `/weather/scenarios` when the backend is up; this list is
  /// the offline fallback and the display order.
  static const List<String> scenarios = <String>[
    'live',
    'clear_pleasant',
    'thunderstorm',
    'heavy_rain',
    'monsoon_flood',
    'heatwave',
    'cold_wave',
    'dense_fog',
    'severe_aqi',
    'cyclone',
    'frost',
  ];

  /// The demo clock docs/00 §Demo script uses (`07:30 IST`, the school run).
  static const List<String> clockPresets = <String>[
    '2026-09-08T07:30:00+05:30',
    '2026-09-08T13:00:00+05:30',
    '2026-09-08T18:30:00+05:30',
    '2026-09-08T22:00:00+05:30',
  ];

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const DemoSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final demo = ref.watch(demoProvider);
    final notifier = ref.read(demoProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final role = ref.watch(roleViewProvider);
    final live = ref.watch(liveAlertsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.science_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l.demoTitle, style: theme.textTheme.titleLarge)),
                  _LiveDot(status: live.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(l.demoSubtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),

              // ------------------------------------------------------------ scenario
              const SizedBox(height: 18),
              Text(l.demoScenario, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in scenarios)
                    ChoiceChip(
                      label: Text(_humanize(name)),
                      selected: (demo.scenario ?? 'live') == name,
                      onSelected: (_) => notifier.setScenario(name),
                    ),
                ],
              ),

              // ------------------------------------------------------------ demo clock
              const SizedBox(height: 18),
              Text(l.demoClock, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l.demoClockNow),
                    selected: demo.nowOverride == null,
                    onSelected: (_) => notifier.setNowOverride(null),
                  ),
                  for (final iso in clockPresets)
                    ChoiceChip(
                      label: Text(iso.substring(11, 16)),
                      selected: demo.nowOverride == iso,
                      onSelected: (_) => notifier.setNowOverride(iso),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: Text(l.demoClockPick),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked == null) return;
                      final hh = picked.hour.toString().padLeft(2, '0');
                      final mm = picked.minute.toString().padLeft(2, '0');
                      // docs/04: a `now` without an offset is read as IST; we send it explicitly.
                      notifier.setNowOverride('2026-09-08T$hh:$mm:00+05:30');
                    },
                  ),
                ],
              ),

              // ------------------------------------------------------------ persona view
              const SizedBox(height: 18),
              Text(l.demoPersona, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l.demoPersonaMine),
                    selected: role == null,
                    onSelected: (_) => ref.read(roleViewProvider.notifier).clear(),
                  ),
                  for (final id in Persona.ids)
                    ChoiceChip(
                      avatar: Icon(AppIcons.persona(id), size: 16),
                      label: Text(personaLabel(l, id)),
                      selected: role == id,
                      onSelected: (_) => ref.read(roleViewProvider.notifier).view(id),
                    ),
                ],
              ),

              // ------------------------------------------------------------ switches
              const SizedBox(height: 8),
              SwitchListTile(
                value: demo.simulateOffline,
                onChanged: notifier.setSimulateOffline,
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.cloud_off_outlined),
                title: Text(l.demoSimulateOffline),
                subtitle: Text(l.demoSimulateOfflineHelp),
              ),
              SwitchListTile(
                value: settings.lowBandwidth,
                onChanged: ref.read(settingsProvider.notifier).setLowBandwidth,
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.data_saver_on),
                title: Text(l.settingsLowBandwidth),
                subtitle: Text(l.settingsLowBandwidthHelp),
              ),

              // ------------------------------------------------------------ admin console
              const Divider(height: 24),
              Text(
                l.demoLiveStatus(_statusLabel(l, live.status)),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openConsole(context, settings.backendUrl),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: Text(l.demoOpenConsole),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      notifier.reset();
                      ref.read(roleViewProvider.notifier).clear();
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: Text(l.demoReset),
                  ),
                ],
              ),
              if (demo.isActive) ...[
                const SizedBox(height: 8),
                Text(
                  l.demoActiveHint,
                  style:
                      theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _openConsole(BuildContext context, String backendUrl) async {
    final messenger = ScaffoldMessenger.of(context);
    final label = L.of(context).demoConsoleUnavailable;
    final uri = Uri.parse('$backendUrl/admin/console');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('$label $uri')));
    }
  }

  static String _humanize(String key) => key
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  static String _statusLabel(L l, AlertsStatus status) => switch (status) {
        AlertsStatus.connected => l.wsConnected,
        AlertsStatus.connecting => l.wsConnecting,
        AlertsStatus.reconnecting => l.wsReconnecting,
        AlertsStatus.unauthorized => l.wsUnauthorized,
        AlertsStatus.closed || AlertsStatus.idle => l.wsOffline,
      };
}

/// Small connection dot: green while `/ws/alerts` is live, amber while reconnecting.
class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.status});

  final AlertsStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AlertsStatus.connected => const Color(0xFF2E7D32),
      AlertsStatus.connecting || AlertsStatus.reconnecting => const Color(0xFFF28C28),
      _ => Theme.of(context).colorScheme.outline,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
