import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over connectivity_plus exposing a deduplicated online/offline
/// stream used by the SyncManager and offline UI banners.
class ConnectivityService {
  ConnectivityService() {
    _subscription =
        Connectivity().onConnectivityChanged.listen(_handleResults);
    // Prime the initial state.
    Connectivity().checkConnectivity().then(_handleResults);
  }

  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  /// Emits whenever the online state flips; new listeners receive the
  /// current state immediately.
  Stream<bool> get onStatusChange async* {
    yield _isOnline;
    yield* _controller.stream;
  }

  void _handleResults(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(online);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
