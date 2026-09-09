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

  /// The ten scenarios docs/05 §Scenarios ships as `backend/app/data/scenarios/*.json`, in the
  /// order the sheet shows them. It is a hardcoded list, not a call to `/weather/scenarios`
  /// (which docs/04 does not publish), so a scenario A* adds must be added here too.
  ///
  /// C1: `cold_wave` used to sit in this list with no file behind it. The backend answers an
  /// unknown scenario with live data, so the chip highlighted and nothing on screen changed —
  /// a dead control in the middle of the judge demo. `test/demo_sheet_test.dart` now pins the
  /// list to what the backend actually ships.
  static const List<String> scenarios = <String>[
    'live',
    'clear_pleasant',
    'thunderstorm',
    'heavy_rain',
    'monsoon_flood',
    'heatwave',
    'dense_fog',
    'severe_aqi',
    'cyclone',
    'frost',
  ];

  /// The demo clock docs/00 §Demo script uses (`07:30 IST`, the school run), and three more
  /// hours that move the ranking (midday, evening, night).
  ///
  /// Built on **today's** date, never a hardcoded one: the backend only moves the reading to a
  /// demo hour it actually has a forecast row for, so a preset carrying the day it was written
  /// stops working the next morning — the feed falls back to the live observation and "07:30"
  /// shows whatever the real clock says. C1.
  static const List<String> clockHours = <String>['07:30', '13:00', '18:30', '22:00'];

  /// Today at [hhmm] in IST — the offset docs/04 reads a bare demo clock as.
  static String presetFor(String hhmm, {DateTime? today}) {
    final d = today ?? DateTime.now();
    final date = '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return '${date}T$hhmm:00+05:30';
  }

  static List<String> get clockPresets =>
      <String>[for (final hhmm in clockHours) presetFor(hhmm)];

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
                      label: Text(scenarioLabel(name)),
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
                      // Today's date, for the same reason `clockPresets` is computed rather than
                      // written down — a hardcoded day falls outside the forecast window as soon
                      // as it is yesterday, and the backend then leaves the reading on live data.
                      notifier.setNowOverride(presetFor('$hh:$mm'));
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

  /// Acronyms the rest of the app always writes in capitals. Without this the `severe_aqi`
  /// chip read "Severe Aqi" next to an AQI card titled "AQI".
  static const Map<String, String> _acronyms = <String, String>{'aqi': 'AQI'};

  @visibleForTesting
  static String scenarioLabel(String key) => key
      .split('_')
      .map((w) => w.isEmpty
          ? w
          : _acronyms[w] ?? '${w[0].toUpperCase()}${w.substring(1)}')
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
