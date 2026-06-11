import 'package:isar_community/isar.dart';

part 'outbox_operation.g.dart';

/// Types of operations the offline outbox can hold.
enum OutboxOpType {
  /// Fetch one volume into the local cache — only a fallback for volumes
  /// missing from the bundled assets (catalog/data mismatch).
  downloadBook,
}

enum OutboxStatus { pending, inFlight, done, failed }

/// Offline-first outbox (FIFO). Writes that need the network are appended
/// here; the UI responds immediately from the local DB and the SyncManager
/// drains the queue when connectivity returns.
@collection
class OutboxOperation {
  Id id = Isar.autoIncrement;

  @Enumerated(EnumType.name)
  late OutboxOpType type;

  /// JSON payload, e.g. {"bookId": "0001-01"}.
  late String payloadJson;

  @Enumerated(EnumType.name)
  @Index()
  OutboxStatus status = OutboxStatus.pending;

  int attempts = 0;

  String? lastError;

  @Index()
  late DateTime createdAt;

  DateTime? completedAt;
}
