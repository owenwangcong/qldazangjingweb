import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../models/app_settings.dart';
import '../../models/book_content.dart';
import '../../models/catalog_models.dart';
import '../../models/outbox_operation.dart';
import '../../models/user_data.dart';

/// Owns the Isar instance — the app's single source of truth.
/// All UI reads go through Isar; the network only ever fills this cache.
class IsarService {
  IsarService._(this.isar);

  final Isar isar;

  static Future<IsarService> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [
        CatalogSectionSchema,
        CatalogBookSchema,
        ClassicEntrySchema,
        BookContentSchema,
        FavoriteBookSchema,
        HistoryItemSchema,
        BookmarkSchema,
        NoteSchema,
        ReadingProgressSchema,
        AppSettingsSchema,
        OutboxOperationSchema,
      ],
      directory: dir.path,
      inspector: false,
    );
    final service = IsarService._(isar);
    await service._seedIfNeeded();
    await service._repairSeeds();
    return service;
  }

  /// 种子数据修正（幂等，随版本追加）：seed 只在目录为空时导入，
  /// 已入库的坏数据要在此定点修复。
  /// 2026-07-20：常用经典·华严的普贤行愿品曾误写不存在的 0089-01
  /// （0089 是《大方广入如来智德不思议经》且无分卷），指到 0085-01。
  Future<void> _repairSeeds() async {
    final broken = await isar.classicEntrys
        .filter()
        .bookIdEqualTo('0089-01')
        .findAll();
    // 同一坏 id 在同步队列里留下的 404 僵尸重试任务一并清除。
    final zombies = await isar.outboxOperations
        .filter()
        .payloadJsonContains('0089-01')
        .findAll();
    if (broken.isEmpty && zombies.isEmpty) return;
    await isar.writeTxn(() async {
      for (final e in broken) {
        e.bookId = '0085-01';
        await isar.classicEntrys.put(e);
      }
      await isar.outboxOperations
          .deleteAll(zombies.map((z) => z.id).toList());
    });
  }

  /// First-launch import of the bundled catalog so browsing works with zero
  /// network. Idempotent: runs only when the catalog is empty.
  Future<void> _seedIfNeeded() async {
    if (await isar.catalogSections.count() > 0) return;

    final mlsRaw = await rootBundle.loadString(AppConstants.assetMls);
    final classicsRaw =
        await rootBundle.loadString(AppConstants.assetClassics);

    final mls = jsonDecode(mlsRaw) as Map<String, dynamic>;
    final classics = jsonDecode(classicsRaw) as Map<String, dynamic>;

    final sections = <CatalogSection>[];
    final books = <CatalogBook>[];
    var sectionOrder = 0;
    for (final entry in mls.values) {
      final section = entry as Map<String, dynamic>;
      final sectionId = section['id'] as String;
      sections.add(
        CatalogSection()
          ..sectionId = sectionId
          ..name = section['name'] as String? ?? ''
          ..order = sectionOrder++,
      );
      final bus = section['bus'] as List<dynamic>? ?? const [];
      var bookOrder = 0;
      for (final b in bus) {
        final bu = b as Map<String, dynamic>;
        final bookId = bu['id'] as String? ?? '';
        if (bookId.isEmpty) continue;
        books.add(
          CatalogBook()
            ..bookId = bookId
            ..sectionId = sectionId
            ..bu = bu['bu'] as String? ?? ''
            ..title = bu['title'] as String? ?? ''
            ..author = bu['author'] as String? ?? ''
            ..volume = bu['volume'] as String? ?? ''
            ..isMulu = bookId.contains('ml')
            ..order = bookOrder++,
        );
      }
    }

    final classicEntries = <ClassicEntry>[];
    for (final category in classics.entries) {
      final items = category.value as List<dynamic>;
      var order = 0;
      for (final item in items) {
        final m = item as Map<String, dynamic>;
        classicEntries.add(
          ClassicEntry()
            ..category = category.key
            ..bookId = m['id'] as String? ?? ''
            ..title = m['title'] as String? ?? ''
            ..order = order++,
        );
      }
    }

    await isar.writeTxn(() async {
      await isar.catalogSections.putAll(sections);
      await isar.catalogBooks.putAll(books);
      await isar.classicEntrys.putAll(classicEntries);
      // Ensure the settings singleton exists.
      if (await isar.appSettings.get(0) == null) {
        await isar.appSettings.put(AppSettings());
      }
    });
  }
}
