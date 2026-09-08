import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../models/warning.dart';

/// One decoded server frame. docs/04 §WebSocket lists exactly six types; anything else is
/// dropped by [AlertsSocket] so a later server can add one without breaking this build.
sealed class AlertsMessage {
  const AlertsMessage();
}

class AlertsHello extends AlertsMessage {
  const AlertsHello({this.serverTime, this.scenario});

  final String? serverTime;
  final String? scenario;
}

class AlertsWarningIssued extends AlertsMessage {
  const AlertsWarningIssued({required this.warning, required this.affectsYou});

  final WeatherWarning warning;
  final bool affectsYou;
}

class AlertsWarningCleared extends AlertsMessage {
  const AlertsWarningCleared(this.id);

  final String id;
}

class AlertsScenarioChanged extends AlertsMessage {
  const AlertsScenarioChanged(this.scenario);

  final String scenario;
}

class AlertsNowOverride extends AlertsMessage {
  const AlertsNowOverride(this.now);

  /// `null` clears the demo clock (docs/04 §admin `POST /admin/now-override`).
  final String? now;
}

/// Connection state, so the UI can show a "live" dot and so a test can assert the lifecycle.
enum AlertsStatus { idle, connecting, connected, reconnecting, unauthorized, closed }

/// The transport [AlertsSocket] talks to. Production wraps `web_socket_channel`; tests pass a
/// fake, which is why this exists rather than the app depending on `WebSocketChannel` directly.
abstract class AlertsChannel {
  Stream<dynamic> get stream;

  void send(String data);

  /// Close code once the socket is done — 1008 means "policy violation" (docs/04: an invalid
  /// token is closed with 1008 before `hello`).
  int? get closeCode;

  Future<void> close();
}

/// Default transport: a real WebSocket.
class WebSocketAlertsChannel implements AlertsChannel {
  WebSocketAlertsChannel(this._channel);

  factory WebSocketAlertsChannel.connect(Uri uri) =>
      WebSocketAlertsChannel(WebSocketChannel.connect(uri));

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  void send(String data) => _channel.sink.add(data);

  @override
  int? get closeCode => _channel.closeCode;

  @override
  Future<void> close() => _channel.sink.close(ws_status.goingAway);
}

/// docs/06_MOBILE_SPEC.md §Layout `data/ws/alerts_socket.dart` —
/// "reconnect w/ backoff, pong, exposes stream".
///
/// Contract (docs/04 §WebSocket + docs/PROGRESS "B2/B3 — what A3 hands you"):
///  * connect to `ws(s)://<backend>/ws/alerts?token=&lat=&lon=`;
///  * answer **every** `ping` with `{"type":"pong"}` — the server drops a socket whose send
///    fails, and it pings every 30 s;
///  * send `{"type":"location",…}` when the user moves; the server never acks it;
///  * ignore unknown `type`s;
///  * close code **1008 = re-authenticate**: never retry with the same token;
///  * any other close reconnects with exponential backoff.
class AlertsSocket {
  AlertsSocket({
    AlertsChannel Function(Uri uri)? connect,
    this.baseBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 30),
  }) : _connect = connect ?? WebSocketAlertsChannel.connect;

  final AlertsChannel Function(Uri uri) _connect;
  final Duration baseBackoff;
  final Duration maxBackoff;

  final StreamController<AlertsMessage> _messages =
      StreamController<AlertsMessage>.broadcast();
  final StreamController<AlertsStatus> _statuses =
      StreamController<AlertsStatus>.broadcast();

  AlertsChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _disposed = false;
  bool _wantConnection = false;

  String? _backendUrl;
  String? _token;
  double? _lat;
  double? _lon;

  AlertsStatus _status = AlertsStatus.idle;

  /// Decoded server frames (docs/04 §WebSocket).
  Stream<AlertsMessage> get messages => _messages.stream;

  Stream<AlertsStatus> get statuses => _statuses.stream;

  AlertsStatus get status => _status;

  bool get isConnected => _status == AlertsStatus.connected;

  /// The `/ws/alerts` URL for a backend origin: `http`→`ws`, `https`→`wss`.
  static Uri buildUri(String backendUrl, {String? token, double? lat, double? lon}) {
    var base = backendUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final http = Uri.parse(base.isEmpty ? 'http://localhost:8000' : base);
    final scheme = switch (http.scheme) {
      'https' || 'wss' => 'wss',
      _ => 'ws',
    };
    return http.replace(
      scheme: scheme,
      path: '${http.path}/ws/alerts',
      queryParameters: <String, String>{
        if (token != null && token.isNotEmpty) 'token': token,
        if (lat != null) 'lat': '$lat',
        if (lon != null) 'lon': '$lon',
      },
    );
  }

  /// Connects, or reconnects when any of the parameters changed. Safe to call on every build.
  void connect({
    required String backendUrl,
    String? token,
    double? lat,
    double? lon,
  }) {
    if (_disposed) return;
    final same = backendUrl == _backendUrl && token == _token;
    _backendUrl = backendUrl;
    _token = token;
    if (same && _channel != null) {
      // Only the position moved: docs/04 says to send a `location` frame rather than reconnect.
      updateLocation(lat, lon);
      return;
    }
    _lat = lat;
    _lon = lon;
    _wantConnection = true;
    _attempt = 0;
    _open();
  }

  /// docs/04 client→server `{"type":"location","lat":..,"lon":..}`. There is no ack.
  void updateLocation(double? lat, double? lon) {
    if (lat == _lat && lon == _lon) return;
    _lat = lat;
    _lon = lon;
    if (lat == null || lon == null) return;
    _send(<String, dynamic>{'type': 'location', 'lat': lat, 'lon': lon});
  }

  void _setStatus(AlertsStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_statuses.isClosed) _statuses.add(next);
  }

  void _send(Map<String, dynamic> frame) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.send(jsonEncode(frame));
    } catch (_) {
      // A send on a half-closed socket must never reach the UI; the stream's onDone/onError
      // below is what schedules the reconnect.
    }
  }

  void _open() {
    if (_disposed || !_wantConnection) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _teardownChannel();
    final url = _backendUrl;
    if (url == null) return;

    _setStatus(_attempt == 0 ? AlertsStatus.connecting : AlertsStatus.reconnecting);
    try {
      final channel = _connect(buildUri(url, token: _token, lat: _lat, lon: _lon));
      _channel = channel;
      _sub = channel.stream.listen(
        _onFrame,
        onError: (Object _) => _onClosed(),
        onDone: _onClosed,
        cancelOnError: false,
      );
    } catch (_) {
      _onClosed();
    }
  }

  void _onFrame(dynamic raw) {
    _attempt = 0;
    _setStatus(AlertsStatus.connected);
    // Answer every ping, first thing: the server pings every 30 s and drops a connection whose
    // send fails (docs/04 §WebSocket).
    if (isPing(raw)) {
      _send(const <String, dynamic>{'type': 'pong'});
      return;
    }
    final message = decode(raw);
    if (message == null) return;
    if (!_messages.isClosed) _messages.add(message);
  }

  /// `true` for the server's 30-second `{"type":"ping"}` keepalive.
  static bool isPing(dynamic raw) {
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        return decoded is Map && decoded['type'] == 'ping';
      } catch (_) {
        return false;
      }
    }
    return raw is Map && raw['type'] == 'ping';
  }

  /// Decodes one server frame. Returns `null` for a `ping` (answered by the caller), for an
  /// unknown `type`, and for anything that is not a JSON object.
  static AlertsMessage? decode(dynamic raw) {
    Map<String, dynamic>? frame;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) frame = Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    } else if (raw is Map) {
      frame = Map<String, dynamic>.from(raw);
    }
    if (frame == null) return null;

    switch (frame['type']) {
      case 'hello':
        return AlertsHello(
          serverTime: frame['server_time']?.toString(),
          scenario: frame['scenario']?.toString(),
        );
      case 'warning_issued':
        final w = frame['warning'];
        if (w is! Map) return null;
        return AlertsWarningIssued(
          warning: WeatherWarning.fromJson(Map<String, dynamic>.from(w)),
          affectsYou: frame['affects_you'] == true,
        );
      case 'warning_cleared':
        final id = frame['id']?.toString();
        return id == null ? null : AlertsWarningCleared(id);
      case 'scenario_changed':
        final s = frame['scenario']?.toString();
        return s == null ? null : AlertsScenarioChanged(s);
      case 'now_override':
        return AlertsNowOverride(frame['now']?.toString());
      // `ping` is handled by the socket itself; anything else is a message type this build
      // does not know about and is dropped on purpose.
      default:
        return null;
    }
  }

  void _onClosed() {
    final code = _channel?.closeCode;
    _teardownChannel();
    if (_disposed || !_wantConnection) {
      _setStatus(AlertsStatus.closed);
      return;
    }
    // docs/04: an invalid token is closed with 1008 before `hello`. Retrying with the same
    // token would just loop, so stop and let the app fetch a fresh one.
    if (code == 1008) {
      _wantConnection = false;
      _setStatus(AlertsStatus.unauthorized);
      return;
    }
    _setStatus(AlertsStatus.reconnecting);
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final delayMs = baseBackoff.inMilliseconds * (1 << _attempt.clamp(0, 5));
    final delay = Duration(
      milliseconds: delayMs.clamp(baseBackoff.inMilliseconds, maxBackoff.inMilliseconds),
    );
    _attempt++;
    _retryTimer = Timer(delay, _open);
  }

  void _teardownChannel() {
    _sub?.cancel();
    _sub = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) unawaited(channel.close().catchError((Object _) {}));
  }

  /// Stops the socket without disposing it (used when the app goes to the background).
  void disconnect() {
    _wantConnection = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _teardownChannel();
    _setStatus(AlertsStatus.closed);
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _messages.close();
    _statuses.close();
  }
}
