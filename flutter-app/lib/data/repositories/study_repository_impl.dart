import 'package:isar_community/isar.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/repositories/repositories.dart';
import '../models/user_data.dart';

/// All user study data lives only in Isar — writes succeed instantly and
/// never wait on the network (offline-first SSOT).
class StudyRepositoryImpl implements StudyRepository {
  StudyRepositoryImpl(this._isar);

  final Isar _isar;

  // ---- Favorites -----------------------------------------------------------

  @override
  Stream<List<FavoriteBook>> watchFavorites() => _isar.favoriteBooks
      .where()
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);

  @override
  Future<bool> isFavorite(String bookId) async =>
      await _isar.favoriteBooks.filter().bookIdEqualTo(bookId).count() > 0;

  @override
  Future<void> addFavorite(String bookId) async {
    await _isar.writeTxn(() async {
      await _isar.favoriteBooks.put(
        FavoriteBook()
          ..bookId = bookId
          ..createdAt = DateTime.now(),
      );
    });
  }

  @override
  Future<void> removeFavorite(String bookId) async {
    await _isar.writeTxn(() async {
      await _isar.favoriteBooks.filter().bookIdEqualTo(bookId).deleteAll();
    });
  }

  // ---- History (capped like the web app) ----------------------------------

  @override
  Stream<List<HistoryItem>> watchHistory() => _isar.historyItems
      .where()
      .sortByVisitedAtDesc()
      .watch(fireImmediately: true);

  @override
  Future<void> recordVisit(String bookId) async {
    await _isar.writeTxn(() async {
      await _isar.historyItems.put(
        HistoryItem()
          ..bookId = bookId
          ..visitedAt = DateTime.now(),
      );
      // Trim to the most recent N entries (web caps at 50).
      final overflow = await _isar.historyItems
          .where()
          .sortByVisitedAtDesc()
          .offset(AppConstants.historyLimit)
          .findAll();
      if (overflow.isNotEmpty) {
        await _isar.historyItems
            .deleteAll(overflow.map((e) => e.id).toList());
      }
    });
  }

  // ---- Bookmarks ------------------------------------------------------------

  @override
  Stream<List<Bookmark>> watchBookmarks() => _isar.bookmarks
      .where()
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);

  @override
  Future<void> addBookmark({
    required String bookId,
    required String partId,
    required int blockIndex,
    required String content,
  }) async {
    await _isar.writeTxn(() async {
      await _isar.bookmarks.put(
        Bookmark()
          ..compositeKey = '$bookId-$partId'
          ..bookId = bookId
          ..partId = partId
          ..blockIndex = blockIndex
          ..content = content
          ..createdAt = DateTime.now(),
      );
    });
  }

  @override
  Future<void> removeBookmark(String compositeKey) async {
    await _isar.writeTxn(() async {
      await _isar.bookmarks
          .filter()
          .compositeKeyEqualTo(compositeKey)
          .deleteAll();
    });
  }

  // ---- Notes (mobile-native take on recogito annotations) ------------------

  @override
  Stream<List<Note>> watchNotes() =>
      _isar.notes.where().sortByCreatedAtDesc().watch(fireImmediately: true);

  @override
  Future<void> addNote({
    required String bookId,
    required String quote,
    required String body,
  }) async {
    await _isar.writeTxn(() async {
      await _isar.notes.put(
        Note()
          ..bookId = bookId
          ..quote = quote
          ..body = body
          ..createdAt = DateTime.now(),
      );
    });
  }

  @override
  Future<void> removeNote(int noteId) async {
    await _isar.writeTxn(() async {
      await _isar.notes.delete(noteId);
    });
  }

  // ---- Reading progress -----------------------------------------------------

  @override
  Future<ReadingProgress?> getProgress(String bookId) =>
      _isar.readingProgress.filter().bookIdEqualTo(bookId).findFirst();

  @override
  Future<void> saveProgress(String bookId, int blockIndex) async {
    await _isar.writeTxn(() async {
      await _isar.readingProgress.put(
        ReadingProgress()
          ..bookId = bookId
          ..blockIndex = blockIndex
          ..updatedAt = DateTime.now(),
      );
    });
  }
}
