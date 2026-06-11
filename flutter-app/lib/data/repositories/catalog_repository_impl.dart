import 'package:isar_community/isar.dart';

import '../../domain/repositories/repositories.dart';
import '../models/catalog_models.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl(this._isar);

  final Isar _isar;

  @override
  Stream<List<CatalogSection>> watchSections() =>
      _isar.catalogSections.where().sortByOrder().watch(fireImmediately: true);

  @override
  Stream<List<CatalogBook>> watchBooksOfSection(String sectionId) =>
      _isar.catalogBooks
          .filter()
          .sectionIdEqualTo(sectionId)
          .isMuluEqualTo(false)
          .sortByOrder()
          .watch(fireImmediately: true);

  @override
  Future<CatalogBook?> getBook(String bookId) =>
      _isar.catalogBooks.filter().bookIdEqualTo(bookId).findFirst();

  @override
  Future<List<CatalogBook>> getBooks(List<String> bookIds) async {
    if (bookIds.isEmpty) return const [];
    final books = await _isar.catalogBooks
        .filter()
        .anyOf(bookIds, (q, id) => q.bookIdEqualTo(id))
        .findAll();
    return books;
  }

  @override
  Stream<Map<String, List<ClassicEntry>>> watchClassics() => _isar
          .classicEntrys
          .where()
          .watch(fireImmediately: true)
          .map((entries) {
        final grouped = <String, List<ClassicEntry>>{};
        for (final e in entries) {
          grouped.putIfAbsent(e.category, () => []).add(e);
        }
        for (final list in grouped.values) {
          list.sort((a, b) => a.order.compareTo(b.order));
        }
        return grouped;
      });

  @override
  Future<List<CatalogBook>> searchTitles(String simplifiedQuery) async {
    final q = simplifiedQuery.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _isar.catalogBooks
        .filter()
        .group(
          (g) => g
              .titleContains(q, caseSensitive: false)
              .or()
              .authorContains(q, caseSensitive: false),
        )
        .findAll();
  }
}
