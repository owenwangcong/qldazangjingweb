import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:qldazangjing/core/ink/ink.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';
import 'package:qldazangjing/core/utils/chinese_converter.dart';
import 'package:qldazangjing/data/models/app_settings.dart';
import 'package:qldazangjing/data/models/catalog_models.dart';
import 'package:qldazangjing/data/models/user_data.dart';
import 'package:qldazangjing/domain/repositories/repositories.dart';
import 'package:qldazangjing/presentation/pages/mystudy_page.dart';
import 'package:qldazangjing/presentation/providers/app_providers.dart';

/// P3.6 我的研习：书签/笔记卡 = InkCard；slidable 左滑删除可用性不退化。
void main() {
  late ChineseConverter converter;

  setUpAll(() async {
    converter = await ChineseConverter.load();
  });

  Widget harness({AppThemeId theme = AppThemeId.hupochangguang}) {
    return ProviderScope(
      overrides: [
        chineseConverterProvider.overrideWithValue(converter),
        settingsProvider.overrideWith(
          (ref) => SettingsController(
              _NoopIsar(), AppSettings()..themeKey = theme.key),
        ),
        catalogRepositoryProvider.overrideWithValue(_FakeCatalogRepository()),
        studyRepositoryProvider.overrideWithValue(_FakeStudyRepository()),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(theme),
        home: const MyStudyPage(),
      ),
    );
  }

  testWidgets('P3.6 书签卡 = InkCard 且保留 Slidable 左滑', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('书签'));
    await tester.pumpAndSettle();

    expect(find.byType(InkCard), findsAtLeastNWidgets(1));
    expect(find.byType(Slidable), findsAtLeastNWidgets(1));

    // 左滑出现删除按钮（可用性不退化）。
    await tester.drag(find.byType(Slidable).first, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('P3.6 笔记卡 = InkCard', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('笔记'));
    await tester.pumpAndSettle();

    expect(find.byType(InkCard), findsAtLeastNWidgets(1));
    expect(find.textContaining('观自在'), findsOneWidget);
  });

  testWidgets('P3.6 六主题构建无异常/overflow', (tester) async {
    for (final theme in AppThemeId.values) {
      await tester.pumpWidget(harness(theme: theme));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '主题 ${theme.key} 异常');
    }
  });
}

class _FakeStudyRepository implements StudyRepository {
  @override
  Stream<List<FavoriteBook>> watchFavorites() => Stream.value(const []);

  @override
  Future<bool> isFavorite(String bookId) async => false;

  @override
  Future<void> addFavorite(String bookId) async {}

  @override
  Future<void> removeFavorite(String bookId) async {}

  @override
  Stream<List<HistoryItem>> watchHistory() => Stream.value(const []);

  @override
  Future<void> recordVisit(String bookId) async {}

  @override
  Stream<List<Bookmark>> watchBookmarks() => Stream.value([
        Bookmark()
          ..compositeKey = '0001-01-part-j1-0'
          ..bookId = '0001-01'
          ..partId = 'part-j1-0'
          ..blockIndex = 3
          ..content = '如是我闻：一时，薄伽梵'
          ..createdAt = DateTime(2026, 6, 1),
      ]);

  @override
  Future<void> addBookmark({
    required String bookId,
    required String partId,
    required int blockIndex,
    required String content,
  }) async {}

  @override
  Future<void> removeBookmark(String compositeKey) async {}

  @override
  Stream<List<Note>> watchNotes() => Stream.value([
        Note()
          ..bookId = '0001-01'
          ..quote = '观自在菩萨行深般若波罗蜜多时'
          ..body = '此句为心经开篇'
          ..createdAt = DateTime(2026, 6, 1),
      ]);

  @override
  Future<void> addNote({
    required String bookId,
    required String quote,
    required String body,
  }) async {}

  @override
  Future<void> removeNote(int noteId) async {}

  @override
  Future<ReadingProgress?> getProgress(String bookId) async => null;

  @override
  Future<void> saveProgress(String bookId, int blockIndex) async {}
}

class _FakeCatalogRepository implements CatalogRepository {
  @override
  Stream<List<CatalogSection>> watchSections() => Stream.value(const []);

  @override
  Stream<Map<String, List<ClassicEntry>>> watchClassics() =>
      Stream.value(const {});

  @override
  Stream<List<CatalogBook>> watchBooksOfSection(String sectionId) =>
      Stream.value(const []);

  @override
  Future<CatalogBook?> getBook(String bookId) async => null;

  @override
  Future<List<CatalogBook>> getBooks(List<String> bookIds) async => [
        CatalogBook()
          ..bookId = '0001-01'
          ..sectionId = '01'
          ..bu = '第 1 部'
          ..title = '大般若波罗蜜多经'
          ..author = '唐三藏法师玄奘奉诏译'
          ..volume = '六百卷'
          ..isMulu = false
          ..order = 0,
      ];

  @override
  Future<List<CatalogBook>> searchTitles(String simplifiedQuery) async =>
      const [];
}

class _NoopIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('测试中不应使用 Isar：${invocation.memberName}');
}
