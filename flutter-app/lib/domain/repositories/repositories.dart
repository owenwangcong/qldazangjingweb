/// Abstract repository contracts (domain layer).
library;

import '../../data/models/catalog_models.dart';
import '../../data/models/user_data.dart';
import '../entities/book_entities.dart';

abstract class CatalogRepository {
  Stream<List<CatalogSection>> watchSections();
  Stream<List<CatalogBook>> watchBooksOfSection(String sectionId);
  Future<CatalogBook?> getBook(String bookId);
  Future<List<CatalogBook>> getBooks(List<String> bookIds);
  Stream<Map<String, List<ClassicEntry>>> watchClassics();

  /// Local title/author search (works offline — mirrors web "标题搜索").
  Future<List<CatalogBook>> searchTitles(String simplifiedQuery);
}

/// How a requested book ended up being (or not being) available.
enum BookFetchOutcome {
  cached,
  downloaded,
  queuedOffline,
  failed,
}

abstract class BookRepository {
  /// UI watches this; emits when the cache fills in (offline-first SSOT).
  Stream<BookData?> watchBook(String bookId);

  Future<bool> isCached(String bookId);

  /// Local-first: hit cache → done; else import the bundled asset (all
  /// volumes ship with the app); network is only a fallback for assets
  /// missing due to a data mismatch.
  Future<BookFetchOutcome> ensureCached(String bookId);

  Future<void> deleteCache(String bookId);

  Stream<List<({String bookId, int sizeBytes, DateTime cachedAt})>>
      watchCachedBooks();
}

abstract class StudyRepository {
  Stream<List<FavoriteBook>> watchFavorites();
  Future<bool> isFavorite(String bookId);
  Future<void> addFavorite(String bookId);
  Future<void> removeFavorite(String bookId);

  Stream<List<HistoryItem>> watchHistory();
  Future<void> recordVisit(String bookId);

  Stream<List<Bookmark>> watchBookmarks();
  Future<void> addBookmark({
    required String bookId,
    required String partId,
    required int blockIndex,
    required String content,
  });
  Future<void> removeBookmark(String compositeKey);

  Stream<List<Note>> watchNotes();
  Future<void> addNote({
    required String bookId,
    required String quote,
    required String body,
  });
  Future<void> removeNote(int noteId);

  Future<ReadingProgress?> getProgress(String bookId);
  Future<void> saveProgress(String bookId, int blockIndex);
}

abstract class SearchRepository {
  Future<FullTextSearchPage> searchFullText({
    required String query,
    required bool phraseMatch,
    required int page,
  });
}

abstract class LexiconRepository {
  Future<List<({String dict, String value})>> lookup(String key);
  Future<String> toModernChinese(String text);
  Future<String> explain(String text);
}
