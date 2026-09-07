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
/// B1 wires the queue and the flush timer; B2 attaches the impression/tap/expand/dismiss
/// producers to the card widgets. A failed flush drops the batch rather than growing forever —
/// engagement data is best-effort telemetry, never something the user waits on.
class EventsRepo {
  EventsRepo({required this._api, this._flushInterval = const Duration(seconds: 10)});

  static const int maxBatch = 100;

  final ApiClient _api;
  final Duration _flushInterval;
  final List<EngagementEvent> _queue = <EngagementEvent>[];
  final Set<String> _impressionsThisLoad = <String>{};

  Timer? _timer;
  bool _sending = false;

  int get pending => _queue.length;

  void add(EngagementEvent event) {
    _queue.add(event);
    if (_queue.length >= maxBatch) {
      unawaited(flush());
    } else {
      _ensureTimer();
    }
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

  Future<void> flush() async {
    if (_sending || _queue.isEmpty) return;
    _sending = true;
    final batch = _queue.take(maxBatch).toList();
    try {
      await _api.postJson('/events', body: <String, dynamic>{
        'events': batch.map((e) => e.toJson()).toList(),
      });
      _queue.removeRange(0, batch.length);
    } on ApiException {
      // Offline or backend down: drop the batch so the queue cannot grow without bound.
      _queue.removeRange(0, batch.length);
    } finally {
      _sending = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
