import 'dart:async';

import '../api_client.dart';

/// One engagement event. docs/04 §Engagement events:
/// `action` ∈ impression|tap|expand|dismiss|pin|unpin|hide|unhide.
class EngagementEvent {
  EngagementEvent({
    required this.type,
    required this.action,
    DateTime? ts,
    this.meta,
  }) : ts = ts ?? DateTime.now();

  final String type;
  final String action;
  final DateTime ts;
  final Map<String, dynamic>? meta;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'action': action,
        'ts': ts.toIso8601String(),
        if (meta != null) 'meta': meta,
      };
}

/// docs/06_MOBILE_SPEC.md §Layout `events_repo (batched, flushed every 10 s or on background)`.
///
/// docs/04 §Engagement events: batches are capped at 100, and `pin/unpin/hide/unhide` also
/// update card-prefs server-side — which is why the app never calls `/me/card-prefs` after one.
/// The `{ok, engagement}` response is kept in [engagement] so the why-sheet can show the user
/// what the ranker has learned from them (docs/03 §Explainability).
///
/// A failed flush drops the batch rather than growing forever: engagement data is best-effort
/// telemetry and must never be something the user waits on, or a queue that eats memory offline.
class EventsRepo {
  EventsRepo({
    required ApiClient api,
    Duration flushInterval = const Duration(seconds: 10),
  })  : _api = api, // ignore: prefer_initializing_formals
        _flushInterval = flushInterval; // ignore: prefer_initializing_formals

  /// docs/04: "Batch ≤ 100".
  static const int maxBatch = 100;

  /// Hard ceiling on the queue while offline — five full batches is far more history than the
  /// ranker needs, and the oldest events are the least interesting.
  static const int maxQueue = 500;

  final ApiClient _api;
  final Duration _flushInterval;
  final List<EngagementEvent> _queue = <EngagementEvent>[];
  final Set<String> _impressionsThisLoad = <String>{};

  Map<String, Map<String, int>> _engagement = <String, Map<String, int>>{};

  Timer? _timer;

  /// Serialises overlapping flushes: a caller that awaits [flush] gets the future of the whole
  /// chain, so "flush then re-fetch /home" cannot race an in-flight batch (docs/06 §Why sheet).
  Future<void>? _chain;

  int get pending => _queue.length;

  /// Per-card-type counters as last reported by `POST /events`
  /// (`{type: {taps, expands, dismisses, pins, impressions}}`).
  Map<String, Map<String, int>> get engagement => _engagement;

  Map<String, int> engagementFor(String type) =>
      _engagement[type] ?? const <String, int>{};

  void add(EngagementEvent event) {
    _queue.add(event);
    if (_queue.length > maxQueue) {
      _queue.removeRange(0, _queue.length - maxQueue);
    }
    if (_queue.length >= maxBatch) {
      unawaited(flush());
    } else {
      _ensureTimer();
    }
  }

  /// Convenience for the card widgets: one call per user gesture.
  void record(String type, String action, {int? position, String? locationId}) {
    add(EngagementEvent(
      type: type,
      action: action,
      meta: position == null && locationId == null
          ? null
          : <String, dynamic>{
              if (position case final int p) 'position': p,
              if (locationId case final String id) 'location_id': id,
            },
    ));
  }

  /// docs/06 §Home behaviour — one impression per card per load.
  void recordImpression(String type, {int? position}) {
    if (!_impressionsThisLoad.add(type)) return;
    add(EngagementEvent(
      type: type,
      action: 'impression',
      meta: position == null ? null : <String, dynamic>{'position': position},
    ));
  }

  void resetImpressions() => _impressionsThisLoad.clear();

  void _ensureTimer() {
    _timer ??= Timer(_flushInterval, () {
      _timer = null;
      unawaited(flush());
    });
  }

  /// Sends everything queued, up to [maxBatch] per request. Never throws.
  Future<void> flush() {
    final next = (_chain ?? Future<void>.value()).then((_) => _drain());
    _chain = next;
    next.whenComplete(() {
      if (identical(_chain, next)) _chain = null;
    });
    return next;
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty) {
      final batch = _queue.take(maxBatch).toList();
      try {
        final res = await _api.postJson('/events', body: <String, dynamic>{
          'events': batch.map((e) => e.toJson()).toList(),
        });
        _absorbEngagement(res['engagement']);
      } on ApiException {
        // Offline or backend down: drop this batch and stop, so we do not spin through the
        // whole queue against a dead endpoint.
        _queue.removeRange(0, batch.length);
        return;
      }
      _queue.removeRange(0, batch.length);
    }
  }

  void _absorbEngagement(Object? raw) {
    if (raw is! Map) return;
    final next = <String, Map<String, int>>{};
    raw.forEach((key, value) {
      if (value is! Map) return;
      final counters = <String, int>{};
      value.forEach((k, v) {
        final n = v is num ? v.round() : int.tryParse('$v');
        if (n != null) counters['$k'] = n;
      });
      next['$key'] = counters;
    });
    if (next.isNotEmpty) _engagement = next;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
