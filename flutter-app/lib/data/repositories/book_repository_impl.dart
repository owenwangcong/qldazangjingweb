import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

import '../../core/network/connectivity_service.dart';
import '../../domain/entities/book_entities.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/local/book_assets.dart';
import '../datasources/remote/api_client.dart';
import '../models/book_content.dart';
import '../models/outbox_operation.dart';
import '../sync/outbox.dart';
import '../sync/sync_manager.dart';

class BookRepositoryImpl implements BookRepository {
  BookRepositoryImpl({
    required Isar isar,
    required ApiClient api,
    required Outbox outbox,
    required SyncManager syncManager,
    required ConnectivityService connectivity,
  })  : _isar = isar,
        _api = api,
        _outbox = outbox,
        _syncManager = syncManager,
        _connectivity = connectivity;

  final Isar _isar;
  final ApiClient _api;
  final Outbox _outbox;
  final SyncManager _syncManager;
  final ConnectivityService _connectivity;

  @override
  Stream<BookData?> watchBook(String bookId) => _isar.bookContents
      .filter()
      .bookIdEqualTo(bookId)
      .watch(fireImmediately: true)
      .map((rows) => rows.isEmpty ? null : _parse(rows.first));

  BookData _parse(BookContent row) {
    final meta =
        BookMeta.fromJson(jsonDecode(row.metaJson) as Map<String, dynamic>);
    final juans = jsonDecode(row.juansJson) as List<dynamic>;
    final blocks = juans
        .whereType<Map<String, dynamic>>()
        .map(JuanBlock.fromJson)
        .whereType<JuanBlock>()
        .toList();
    return BookData(meta: meta, blocks: blocks);
  }

  @override
  Future<bool> isCached(String bookId) async =>
      await _isar.bookContents.filter().bookIdEqualTo(bookId).count() > 0;

  @override
  Future<BookFetchOutcome> ensureCached(String bookId) async {
    if (await isCached(bookId)) return BookFetchOutcome.cached;

    // Primary source: the bundled asset — every volume ships with the app,
    // so opening a book works with zero network.
    final asset = await BookAssets.tryLoad(bookId);
    if (asset != null) {
      await _put(bookId, asset.metaJson, asset.juansJson);
      return BookFetchOutcome.downloaded;
    }

    // Asset missing (catalog/data mismatch) — fall back to the network path.
    if (!_connectivity.isOnline) {
      await _outbox.enqueue(OutboxOpType.downloadBook, {'bookId': bookId});
      return BookFetchOutcome.queuedOffline;
    }
    try {
      final json = await _api.fetchBook(bookId);
      await _put(
        bookId,
        jsonEncode(json['meta'] ?? const <String, dynamic>{}),
        jsonEncode(json['juans'] ?? const <dynamic>[]),
      );
      return BookFetchOutcome.downloaded;
    } catch (e) {
      debugPrint('ensureCached($bookId) failed: $e');
      // Network flaked mid-request — let the sync queue retry it.
      await _outbox.enqueue(OutboxOpType.downloadBook, {'bookId': bookId});
      _syncManager.kick();
      return BookFetchOutcome.failed;
    }
  }

  Future<void> _put(String bookId, String metaJson, String juansJson) async {
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

  @override
  Future<void> deleteCache(String bookId) async {
    await _isar.writeTxn(() async {
      await _isar.bookContents.filter().bookIdEqualTo(bookId).deleteAll();
    });
  }

  @override
  Stream<List<({String bookId, int sizeBytes, DateTime cachedAt})>>
      watchCachedBooks() => _isar.bookContents
          .where()
          .watch(fireImmediately: true)
          .map((rows) => rows
              .map((r) => (
                    bookId: r.bookId,
                    sizeBytes: r.sizeBytes,
                    cachedAt: r.cachedAt,
                  ))
              .toList()
            ..sort((a, b) => b.cachedAt.compareTo(a.cachedAt)));
}
