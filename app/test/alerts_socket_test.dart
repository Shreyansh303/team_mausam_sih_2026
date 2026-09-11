import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mausam_app/data/ws/alerts_socket.dart';

/// A scriptable stand-in for a WebSocket. `emit` pushes a server frame, `finish` closes the
/// socket with a code, and `sent` records everything the client wrote back.
class FakeChannel implements AlertsChannel {
  FakeChannel(this.uri);

  final Uri uri;
  final StreamController<dynamic> _controller = StreamController<dynamic>();
  final List<String> sent = <String>[];

  int? _closeCode;
  bool closed = false;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void send(String data) => sent.add(data);

  @override
  int? get closeCode => _closeCode;

  @override
  Future<void> close() async {
    closed = true;
    if (!_controller.isClosed) await _controller.close();
  }

  void emit(Object frame) =>
      _controller.add(frame is String ? frame : jsonEncode(frame));

  /// Server-side close, e.g. 1008 for a rejected token (docs/04 §WebSocket).
  Future<void> finish({int? code}) async {
    _closeCode = code;
    if (!_controller.isClosed) await _controller.close();
  }
}

/// docs/04 §WebSocket: the real frames captured from the running backend (milestone A3).
const Map<String, dynamic> _warningFrame = <String, dynamic>{
  'type': 'warning_issued',
  'warning': <String, dynamic>{
    'id': 'wrn_7a4734a416',
    'severity': 'orange',
    'hazard': 'thunderstorm',
    'title': 'Thunderstorm warning — Delhi',
    'description': 'Thunderstorm with lightning and gusty winds likely over Delhi.',
    'issued_at': '2026-09-07T15:55:48+05:30',
    'valid_from': '2026-09-07T15:55:48+05:30',
    'valid_to': '2026-09-07T17:55:48+05:30',
    'district': 'New Delhi',
    'state': 'Delhi',
    'lat': 28.61,
    'lon': 77.21,
    'radius_km': 75,
    'source': 'admin',
    'color_hex': '#F28C28',
  },
  'affects_you': true,
};

void main() {
  group('AlertsSocket.buildUri', () {
    test('derives ws:// from the backend origin and carries token + position', () {
      final uri = AlertsSocket.buildUri(
        'http://127.0.0.1:8000/',
        token: 'jwt-123',
        lat: 28.61,
        lon: 77.21,
      );
      expect(uri.scheme, 'ws');
      expect(uri.host, '127.0.0.1');
      expect(uri.port, 8000);
      expect(uri.path, '/ws/alerts');
      expect(uri.queryParameters['token'], 'jwt-123');
      expect(uri.queryParameters['lat'], '28.61');
      expect(uri.queryParameters['lon'], '77.21');
    });

    test('https becomes wss and a missing token is simply omitted (DEMO_MODE)', () {
      final uri = AlertsSocket.buildUri('https://mausam.onrender.com', lat: 1, lon: 2);
      expect(uri.toString(), startsWith('wss://mausam.onrender.com/ws/alerts?'));
      expect(uri.queryParameters.containsKey('token'), isFalse);
    });
  });

  group('AlertsSocket frames', () {
    late FakeChannel channel;
    late AlertsSocket socket;

    setUp(() {
      socket = AlertsSocket(
        connect: (uri) => channel = FakeChannel(uri),
        baseBackoff: const Duration(milliseconds: 10),
        maxBackoff: const Duration(milliseconds: 20),
      );
    });

    tearDown(() => socket.dispose());

    test('answers every ping with a pong and does not surface it as a message', () async {
      final seen = <AlertsMessage>[];
      socket.messages.listen(seen.add);
      socket.connect(backendUrl: 'http://127.0.0.1:8000', token: 't', lat: 28.61, lon: 77.21);

      channel.emit(<String, dynamic>{'type': 'ping'});
      channel.emit(<String, dynamic>{'type': 'ping'});
      await pumpEventQueue();

      expect(channel.sent, <String>['{"type":"pong"}', '{"type":"pong"}']);
      expect(seen, isEmpty);
      expect(socket.status, AlertsStatus.connected);
    });

    test('decodes hello, warning_issued, cleared, scenario and now_override', () async {
      final seen = <AlertsMessage>[];
      socket.messages.listen(seen.add);
      socket.connect(backendUrl: 'http://127.0.0.1:8000', lat: 28.61, lon: 77.21);

      channel
        ..emit(<String, dynamic>{
          'type': 'hello',
          'server_time': '2026-09-07T15:51:47+05:30',
          'scenario': 'live',
        })
        ..emit(_warningFrame)
        ..emit(<String, dynamic>{'type': 'warning_cleared', 'id': 'wrn_7a4734a416'})
        ..emit(<String, dynamic>{'type': 'scenario_changed', 'scenario': 'heatwave'})
        ..emit(<String, dynamic>{'type': 'now_override', 'now': '2026-09-08T07:30:00+05:30'})
        ..emit(<String, dynamic>{'type': 'now_override', 'now': null});
      await pumpEventQueue();

      expect(seen.length, 6);
      expect((seen[0] as AlertsHello).scenario, 'live');
      final issued = seen[1] as AlertsWarningIssued;
      expect(issued.affectsYou, isTrue);
      expect(issued.warning.severity, 'orange');
      expect(issued.warning.hazard, 'thunderstorm');
      expect((seen[2] as AlertsWarningCleared).id, 'wrn_7a4734a416');
      expect((seen[3] as AlertsScenarioChanged).scenario, 'heatwave');
      expect((seen[4] as AlertsNowOverride).now, '2026-09-08T07:30:00+05:30');
      expect((seen[5] as AlertsNowOverride).now, isNull);
    });

    test('ignores unknown types and malformed frames', () async {
      final seen = <AlertsMessage>[];
      socket.messages.listen(seen.add);
      socket.connect(backendUrl: 'http://127.0.0.1:8000', lat: 1, lon: 2);

      channel
        ..emit(<String, dynamic>{'type': 'quake_issued', 'magnitude': 6})
        ..emit('not json at all')
        ..emit(<String, dynamic>{'type': 'warning_issued'}) // no `warning` object
        ..emit(<String, dynamic>{'no': 'type'});
      await pumpEventQueue();

      expect(seen, isEmpty);
    });

    test('a location change sends a location frame instead of reconnecting', () async {
      socket.connect(backendUrl: 'http://127.0.0.1:8000', token: 't', lat: 28.61, lon: 77.21);
      final first = channel;
      await pumpEventQueue();

      socket.connect(backendUrl: 'http://127.0.0.1:8000', token: 't', lat: 19.08, lon: 72.88);
      await pumpEventQueue();

      expect(identical(channel, first), isTrue, reason: 'must not reopen the socket');
      expect(channel.sent.single, '{"type":"location","lat":19.08,"lon":72.88}');
    });

    test('close code 1008 stops retrying: the token has to be replaced first', () async {
      socket.connect(backendUrl: 'http://127.0.0.1:8000', token: 'stale', lat: 1, lon: 2);
      final first = channel;
      await channel.finish(code: 1008);
      await pumpEventQueue();
      expect(socket.status, AlertsStatus.unauthorized);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(identical(channel, first), isTrue, reason: 'no retry with the same token');
      expect(socket.status, AlertsStatus.unauthorized);
    });

    test('any other close reconnects with backoff', () async {
      socket.connect(backendUrl: 'http://127.0.0.1:8000', token: 't', lat: 1, lon: 2);
      final first = channel;
      await channel.finish(code: 1006);
      await pumpEventQueue();
      expect(socket.status, AlertsStatus.reconnecting);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(identical(channel, first), isFalse, reason: 'a new socket must be opened');

      channel.emit(<String, dynamic>{'type': 'hello', 'scenario': 'live'});
      await pumpEventQueue();
      expect(socket.status, AlertsStatus.connected);
    });

    test('disconnect() closes the channel and stops the retry loop', () async {
      socket.connect(backendUrl: 'http://127.0.0.1:8000', lat: 1, lon: 2);
      final first = channel;
      socket.disconnect();
      await pumpEventQueue();

      expect(first.closed, isTrue);
      expect(socket.status, AlertsStatus.closed);
    });
  });
}
