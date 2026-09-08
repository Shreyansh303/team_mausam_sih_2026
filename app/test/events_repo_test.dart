import 'package:flutter_test/flutter_test.dart';
import 'package:mausam_app/data/api_client.dart';
import 'package:mausam_app/data/repositories/events_repo.dart';

/// Records every `POST /events` body instead of sending it, and can be told to fail like an
/// unreachable backend.
class RecordingApi extends ApiClient {
  RecordingApi() : super(baseUrl: 'http://127.0.0.1:1');

  final List<List<Map<String, dynamic>>> batches = <List<Map<String, dynamic>>>[];
  bool fail = false;
  Map<String, dynamic> response = <String, dynamic>{'ok': true};

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Object? cancelToken,
  }) async {
    if (fail) {
      throw ApiException('Cannot reach the backend.', code: 'unreachable', isNetwork: true);
    }
    expect(path, '/events');
    final map = body! as Map<String, dynamic>;
    batches.add(
      (map['events'] as List<dynamic>).cast<Map<String, dynamic>>(),
    );
    return response;
  }
}

void main() {
  late RecordingApi api;
  late EventsRepo repo;

  setUp(() {
    api = RecordingApi();
    repo = EventsRepo(api: api, flushInterval: const Duration(milliseconds: 20));
  });

  tearDown(() => repo.dispose());

  test('an action is queued and flushed as one batch in the docs/04 shape', () async {
    repo.record('aqi', 'tap', position: 2);
    repo.record('aqi', 'expand');
    expect(repo.pending, 2);

    await repo.flush();

    expect(api.batches.length, 1);
    final batch = api.batches.single;
    expect(batch.length, 2);
    expect(batch.first['type'], 'aqi');
    expect(batch.first['action'], 'tap');
    expect(batch.first['meta'], <String, dynamic>{'position': 2});
    expect(DateTime.tryParse(batch.first['ts'] as String), isNotNull);
    expect(batch.last.containsKey('meta'), isFalse);
    expect(repo.pending, 0);
  });

  test('impressions are one per card per load and reset with the payload', () async {
    repo.recordImpression('aqi', position: 0);
    repo.recordImpression('aqi', position: 0);
    repo.recordImpression('hero', position: 1);
    expect(repo.pending, 2);

    repo.resetImpressions();
    repo.recordImpression('aqi', position: 0);
    expect(repo.pending, 3);
  });

  test('the batch never exceeds 100 events (docs/04 §Engagement events)', () async {
    for (var i = 0; i < 250; i++) {
      repo.add(EngagementEvent(type: 'card_$i', action: 'impression'));
    }
    await repo.flush();

    expect(api.batches.map((b) => b.length).toList(), <int>[100, 100, 50]);
  });

  test('the queue is flushed automatically after the interval', () async {
    repo.record('aqi', 'tap');
    expect(api.batches, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(api.batches.length, 1);
    expect(repo.pending, 0);
  });

  test('an unreachable backend drops the batch instead of growing the queue', () async {
    api.fail = true;
    for (var i = 0; i < 30; i++) {
      repo.record('aqi', 'impression');
    }
    await repo.flush();

    expect(api.batches, isEmpty);
    expect(repo.pending, 0, reason: 'telemetry is best-effort, never a growing backlog');
  });

  test('the queue is capped so a long offline session cannot grow without bound', () {
    for (var i = 0; i < EventsRepo.maxQueue + 250; i++) {
      // `add` flushes at 100 against a dead endpoint; use a failing api to keep them queued.
      api.fail = true;
      repo.add(EngagementEvent(type: 'aqi', action: 'impression'));
    }
    expect(repo.pending, lessThanOrEqualTo(EventsRepo.maxQueue));
  });

  test('the engagement counters from the response are kept for the why sheet', () async {
    api.response = <String, dynamic>{
      'ok': true,
      'engagement': <String, dynamic>{
        'aqi': <String, dynamic>{'taps': 3, 'dismisses': 1, 'impressions': 9},
      },
    };
    repo.record('aqi', 'tap');
    await repo.flush();

    expect(repo.engagementFor('aqi'), <String, int>{
      'taps': 3,
      'dismisses': 1,
      'impressions': 9,
    });
    expect(repo.engagementFor('tides'), isEmpty);
  });
}
