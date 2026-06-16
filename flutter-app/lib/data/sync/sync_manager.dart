import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

import '../../core/network/connectivity_service.dart';
import '../datasources/local/book_assets.dart';
import '../datasources/remote/api_client.dart';
import '../models/book_content.dart';
import '../models/outbox_operation.dart';
import 'outbox.dart';

/// Background drainer of the offline outbox.
///
/// - Listens to connectivity; when the device comes (back) online it consumes
///   the queue strictly FIFO.
/// - Each operation type has a handler; failures retry with exponential
///   backoff and park as `failed` after 5 attempts (no head-of-line wedge).
/// - Conflict policy: operations are idempotent writes into the local cache
///   (last-write-wins). User data never leaves the device in v1, so there is
///   no remote conflict to resolve yet.
class SyncManager {
  SyncManager({
    required Isar isar,
    required Outbox outbox,
    required ApiClient api,
    required ConnectivityService connectivity,
  })  : _isar = isar,
        _outbox = outbox,
        _api = api,
        _connectivity = connectivity;

  final Isar _isar;
  final Outbox _outbox;
  final ApiClient _api;
  final ConnectivityService _connectivity;

  StreamSubscription<bool>? _connectivitySub;
  bool _draining = false;
  Timer? _retryTimer;

  void start() {
    _outbox.recoverStaleInFlight();
    _connectivitySub = _connectivity.onStatusChange.listen((online) {
      if (online) _drain();
    });
  }

  Future<void> stop() async {
    await _connectivitySub?.cancel();
    _retryTimer?.cancel();
  }

  /// Public nudge — call after enqueueing if we may already be online.
  void kick() {
    if (_connectivity.isOnline) _drain();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_connectivity.isOnline) {
        final op = await _outbox.nextPending();
        if (op == null) break;
        await _outbox.markInFlight(op);
        try {
          await _execute(op);
          await _outbox.markDone(op);
        } catch (e) {
          debugPrint('SyncManager: op ${op.id} (${op.type.name}) failed: $e');
          await _outbox.markFailed(op, e);
          // Exponential backoff before touching the queue again, so a flaky
          // network doesn't spin the same head item.
          final delay = Duration(seconds: 1 << (op.attempts.clamp(0, 5)));
          _retryTimer?.cancel();
          _retryTimer = Timer(delay, () {
            if (_connectivity.isOnline) _drain();
          });
          break;
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _execute(OutboxOperation op) async {
    final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
    switch (op.type) {
      case OutboxOpType.downloadBook:
        await _downloadBook(payload['bookId'] as String);
    }
  }

  Future<void> _downloadBook(String bookId) async {
    // Idempotent: skip when already cached.
    final cached =
        await _isar.bookContents.filter().bookIdEqualTo(bookId).findFirst();
    if (cached != null) return;

    // Bundled asset first; the network only covers data mismatches.
    var content = await BookAssets.tryLoad(bookId);
    if (content == null) {
      final json = await _api.fetchBook(bookId);
      content = (
        metaJson: jsonEncode(json['meta'] ?? const <String, dynamic>{}),
        juansJson: jsonEncode(json['juans'] ?? const <dynamic>[]),
      );
    }
    final (:metaJson, :juansJson) = content;
    await _isar.writeTxn(() async {
      await _isar.bookContents.put(
        BookContent()
          ..bookId = bookId
          ..metaJson = metaJson
          ..juansJson = juansJson
          ..sizeBytes = metaJson.length + juansJson.length
          ..cachedAt = DateTime.now(),
      );
    });
  }
}
