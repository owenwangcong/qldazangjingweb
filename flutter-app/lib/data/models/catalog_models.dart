import 'package:isar_community/isar.dart';

part 'catalog_models.g.dart';

/// 部类（如 大乘般若部）。Seeded from assets/data/mls.json.
@collection
class CatalogSection {
  Id id = Isar.autoIncrement;

  /// e.g. "01"
  @Index(unique: true, replace: true)
  late String sectionId;

  late String name;

  late int order;
}

/// 册（mls.json 中每部类的 bus 条目）。
@collection
class CatalogBook {
  Id id = Isar.autoIncrement;

  /// e.g. "0001-01"
  @Index(unique: true, replace: true)
  late String bookId;

  @Index()
  late String sectionId;

  /// e.g. "第 1 部"
  late String bu;

  late String title;

  late String author;

  late String volume;

  /// Catalog/table-of-contents volumes ("-ml" suffixed ids) are hidden from
  /// section listings on the web; keep the flag so we can do the same.
  late bool isMulu;

  late int order;
}

/// 常用经典快捷入口。Seeded from assets/data/classics.json.
@collection
class ClassicEntry {
  Id id = Isar.autoIncrement;

  @Index()
  late String category;

  late String bookId;

  late String title;

  late int order;
}
