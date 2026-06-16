import 'package:isar_community/isar.dart';

part 'book_content.g.dart';

/// Offline cache of one volume's full text (`/data/books/{id}.json`).
/// The raw JSON payload is stored verbatim; the domain layer parses it into
/// typed blocks. Once cached, reading works fully offline.
@collection
class BookContent {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String bookId;

  /// `meta` object of the source JSON (title/Arthur/last_bu/next_bu...).
  late String metaJson;

  /// `juans` array of the source JSON.
  late String juansJson;

  late int sizeBytes;

  late DateTime cachedAt;
}
