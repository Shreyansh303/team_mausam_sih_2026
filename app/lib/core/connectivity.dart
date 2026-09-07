import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// docs/06_MOBILE_SPEC.md §Layout `core/connectivity.dart` — drives the offline banner and
/// disables network-only actions.
///
/// `connectivity_plus` reports the *interface*, not reachability: "connected to Wi-Fi" does not
/// prove the backend is reachable. We therefore only ever use it to say **offline**; "online"
/// still goes through the normal request path, whose failure keeps the cache on screen.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _isOffline(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);

  Future<bool> isOffline() async {
    try {
      return _isOffline(await _connectivity.checkConnectivity());
    } catch (_) {
      return false; // unsupported platform — assume online and let requests decide
    }
  }

  /// `true` when the device has no usable interface.
  Stream<bool> offlineStream() =>
      _connectivity.onConnectivityChanged.map(_isOffline).handleError((_) => false);
}
