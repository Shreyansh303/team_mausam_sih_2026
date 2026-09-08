import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/warning.dart';
import '../../data/ws/alerts_socket.dart';
import 'providers.dart';

/// What the home screen knows about the live `/ws/alerts` connection.
class LiveAlertsState {
  const LiveAlertsState({
    this.status = AlertsStatus.idle,
    this.warning,
    this.scenario,
    this.nowOverride,
    this.lastEventAt,
  });

  final AlertsStatus status;

  /// The warning that just arrived over the socket and affects this location. docs/06
  /// §Home behaviour: "show banner immediately with the warning → refetch → animate", so the
  /// banner does not wait for `/home` to come back.
  final WeatherWarning? warning;

  /// Last `scenario_changed` / `now_override` seen, shown in the demo sheet.
  final String? scenario;
  final String? nowOverride;

  /// Bumped on every event that triggered a re-fetch — the home feed uses it to decide that a
  /// re-rank is worth animating and announcing.
  final DateTime? lastEventAt;

  bool get isLive => status == AlertsStatus.connected;

  LiveAlertsState copyWith({
    AlertsStatus? status,
    WeatherWarning? warning,
    bool clearWarning = false,
    String? scenario,
    String? nowOverride,
    bool clearNowOverride = false,
    DateTime? lastEventAt,
  }) =>
      LiveAlertsState(
        status: status ?? this.status,
        warning: clearWarning ? null : (warning ?? this.warning),
        scenario: scenario ?? this.scenario,
        nowOverride: clearNowOverride ? null : (nowOverride ?? this.nowOverride),
        lastEventAt: lastEventAt ?? this.lastEventAt,
      );
}

/// The socket itself. One per app run; the notifier below owns its lifecycle.
final alertsSocketProvider = Provider<AlertsSocket>((ref) {
  final socket = AlertsSocket();
  ref.onDispose(socket.dispose);
  return socket;
});

/// docs/06_MOBILE_SPEC.md §Home behaviour — "WebSocket: connect on home; on `warning_issued`
/// with `affects_you` → show banner immediately with the warning → refetch → animate. On
/// `scenario_changed` / `now_override` → refetch."
///
/// Everything the socket does to the rest of the app happens here, so the transport in
/// `data/ws/alerts_socket.dart` stays free of Riverpod and is unit-testable on its own.
class LiveAlertsNotifier extends Notifier<LiveAlertsState> {
  @override
  LiveAlertsState build() {
    final socket = ref.watch(alertsSocketProvider);
    final settings = ref.watch(settingsProvider);
    final query = ref.watch(homeQueryProvider);
    // A guest token is best-effort: DEMO_MODE lets the socket connect without one, and a dead
    // backend must never stop the home screen from rendering.
    final token = ref.watch(authTokenProvider).value;

    final subMessages = socket.messages.listen(_onMessage);
    final subStatus = socket.statuses.listen((s) {
      state = state.copyWith(status: s);
    });
    ref.onDispose(() {
      subMessages.cancel();
      subStatus.cancel();
    });

    socket.connect(
      backendUrl: settings.backendUrl,
      token: token,
      lat: query.lat,
      lon: query.lon,
    );

    return LiveAlertsState(status: socket.status);
  }

  void _onMessage(AlertsMessage message) {
    switch (message) {
      case AlertsHello(:final scenario):
        state = state.copyWith(scenario: scenario);
      case AlertsWarningIssued(:final warning, :final affectsYou):
        if (!affectsYou) return;
        state = state.copyWith(warning: warning, lastEventAt: DateTime.now());
        _refetchHome();
      case AlertsWarningCleared(:final id):
        if (state.warning?.id == id) {
          state = state.copyWith(clearWarning: true, lastEventAt: DateTime.now());
        }
        _refetchHome();
      case AlertsScenarioChanged(:final scenario):
        state = state.copyWith(scenario: scenario, lastEventAt: DateTime.now());
        _refetchHome();
      case AlertsNowOverride(:final now):
        state = now == null
            ? state.copyWith(clearNowOverride: true, lastEventAt: DateTime.now())
            : state.copyWith(nowOverride: now, lastEventAt: DateTime.now());
        _refetchHome();
    }
  }

  /// Drops the live banner once the refreshed `/home` carries the warning itself.
  void clearWarning() => state = state.copyWith(clearWarning: true);

  void _refetchHome() {
    final query = ref.read(homeQueryProvider);
    ref.invalidate(homeProvider(query));
  }
}

final liveAlertsProvider =
    NotifierProvider<LiveAlertsNotifier, LiveAlertsState>(LiveAlertsNotifier.new);
