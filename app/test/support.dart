import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mausam_app/data/ws/alerts_socket.dart';

/// Keeps `flutter_map` off the network (and off `path_provider`'s tile cache) by answering
/// every tile with a 1×1 transparent PNG. Shared by every widget test that builds the home
/// feed, because the feed contains a radar card.
class BlankTileProvider extends TileProvider {
  static final Uint8List _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  ImageProvider<Object> getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_pixel);
}

/// A socket transport that connects, says nothing and never closes — so a widget test that
/// mounts the home screen does not open a real WebSocket (or leave a reconnect timer pending).
class SilentAlertsChannel implements AlertsChannel {
  final StreamController<dynamic> _controller = StreamController<dynamic>();
  final List<String> sent = <String>[];

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void send(String data) => sent.add(data);

  @override
  int? get closeCode => null;

  @override
  Future<void> close() async {
    if (!_controller.isClosed) await _controller.close();
  }
}

/// An [AlertsSocket] wired to [SilentAlertsChannel] — the value to override
/// `alertsSocketProvider` with in widget tests.
AlertsSocket silentAlertsSocket() => AlertsSocket(connect: (_) => SilentAlertsChannel());
