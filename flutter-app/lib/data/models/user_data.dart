import 'package:isar_community/isar.dart';

part 'user_data.g.dart';

/// 收藏（web: localStorage favoriteBooks）。
@collection
class FavoriteBook {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String bookId;

  late DateTime createdAt;
}

/// 浏览历史（web: localStorage browserHistory，上限 50 条）。
@collection
class HistoryItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String bookId;

  @Index()
  late DateTime visitedAt;
}

/// 书签（web: localStorage bookmarks，定位到段落）。
@collection
class Bookmark {
  Id id = Isar.autoIncrement;

  /// "{bookId}-{partId}" — same composite key as the web app.
  @Index(unique: true, replace: true)
  late String compositeKey;

  @Index()
  late String bookId;

  /// Paragraph anchor, e.g. "part-p-12-0".
  late String partId;

  /// Index of the block in the parsed juans list (mobile fast-jump).
  late int blockIndex;

  /// First ~16 chars of the paragraph, used as the label (web parity).
  late String content;

  late DateTime createdAt;
}

/// 笔记/注释（web: recogito 划词注释的移动端化）。
@collection
class Note {
  Id id = Isar.autoIncrement;

  @Index()
  late String bookId;

  /// The selected source text the note is attached to.
  late String quote;

  /// User's comment body.
  late String body;

  late DateTime createdAt;
}

/// 断点续读：每本书最后阅读到的块索引（移动端新增能力）。
@collection
class ReadingProgress {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String bookId;

  late int blockIndex;

  late DateTime updatedAt;
}
