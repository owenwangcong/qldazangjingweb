import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../models/outbox_operation.dart';

/// Append-only API over the outbox queue. UI-facing code calls [enqueue] and
/// returns immediately — the network work happens later in the SyncManager.
class Outbox {
  Outbox(this._isar);

  final Isar _isar;

  Future<void> enqueue(OutboxOpType type, Map<String, dynamic> payload) async {
    // Idempotency: skip if an identical operation is already waiting.
    final payloadJson = jsonEncode(payload);
    final existing = await _isar.outboxOperations
        .filter()
        .statusEqualTo(OutboxStatus.pending)
        .typeEqualTo(type)
        .payloadJsonEqualTo(payloadJson)
        .findFirst();
    if (existing != null) return;

    await _isar.writeTxn(() async {
      await _isar.outboxOperations.put(
        OutboxOperation()
          ..type = type
          ..payloadJson = payloadJson
          ..status = OutboxStatus.pending
          ..createdAt = DateTime.now(),
      );
    });
  }

  /// Oldest pending operation first (FIFO).
  Future<OutboxOperation?> nextPending() => _isar.outboxOperations
      .filter()
      .statusEqualTo(OutboxStatus.pending)
      .sortByCreatedAt()
      .findFirst();

  Future<void> markInFlight(OutboxOperation op) async {
    op
      ..status = OutboxStatus.inFlight
      ..attempts += 1;
    await _isar.writeTxn(() => _isar.outboxOperations.put(op));
  }

  Future<void> markDone(OutboxOperation op) async {
    op
      ..status = OutboxStatus.done
      ..completedAt = DateTime.now()
      ..lastError = null;
    await _isar.writeTxn(() => _isar.outboxOperations.put(op));
  }

  /// Failed ops go back to pending until [maxAttempts]; after that they are
  /// parked as failed so the queue cannot wedge itself on one bad item.
  Future<void> markFailed(
    OutboxOperation op,
    Object error, {
    int maxAttempts = 5,
  }) async {
    op
      ..lastError = error.toString()
      ..status = op.attempts >= maxAttempts
          ? OutboxStatus.failed
          : OutboxStatus.pending;
    await _isar.writeTxn(() => _isar.outboxOperations.put(op));
  }

  /// Re-arm operations stuck inFlight after a crash, so they run again.
  Future<void> recoverStaleInFlight() async {
    final stale = await _isar.outboxOperations
        .filter()
        .statusEqualTo(OutboxStatus.inFlight)
        .findAll();
    if (stale.isEmpty) return;
    await _isar.writeTxn(() async {
      for (final op in stale) {
        op.status = OutboxStatus.pending;
        await _isar.outboxOperations.put(op);
      }
    });
  }

  /// Number of operations still waiting (for the downloads UI).
  Stream<int> watchPendingCount() => _isar.outboxOperations
      .filter()
      .statusEqualTo(OutboxStatus.pending)
      .watch(fireImmediately: true)
      .map((ops) => ops.length);

  Stream<List<OutboxOperation>> watchAll() => _isar.outboxOperations
      .where()
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);

  Future<void> clearCompleted() async {
    await _isar.writeTxn(() async {
      await _isar.outboxOperations
          .filter()
          .statusEqualTo(OutboxStatus.done)
          .deleteAll();
    });
  }
}
