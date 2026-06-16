import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:qldazangjing/core/pagination/sutra_paginator.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';
import 'package:qldazangjing/core/utils/chinese_converter.dart';
import 'package:qldazangjing/data/models/app_settings.dart';
import 'package:qldazangjing/data/models/user_data.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';
import 'package:qldazangjing/domain/repositories/repositories.dart';
import 'package:qldazangjing/presentation/pages/reader_page.dart';
import 'package:qldazangjing/presentation/providers/app_providers.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// 翻页阅读模式：PageView 渲染、翻页手势/点按分区、chrome 显隐、
/// 设置面板模式切换、?index 锚点。
///
/// 注意：页面常驻 EnsoLoading（角落/排版态）会让 pumpAndSettle 超时，
/// 全部用定步 pump。
void main() {
  late ChineseConverter converter;

  setUpAll(() async {
    converter = await ChineseConverter.load();
  });

  setUp(SutraPaginator.clearCache);

  // 60 个一行短块：默认字号下每页十余块，块间距离足够区分页码。
  final demoBook = BookData(
    meta: const BookMeta(
      id: '0001-01',
      bu: '大乘般若部·第0001部',
      title: '大般若波罗蜜多经',
      author: '唐三藏法师玄奘奉诏译',
    ),
    blocks: [
      for (var i = 0; i < 60; i++)
        JuanBlock(id: 'p-$i', type: JuanBlockType.p, paragraphs: ['块$i佛说般若']),
    ],
  );

  List<Override> overrides({
    required BookData book,
    required AppSettings settings,
  }) =>
      [
        chineseConverterProvider.overrideWithValue(converter),
        settingsProvider.overrideWith(
          (ref) => SettingsController(_FakeIsar(), settings),
        ),
        bookRepositoryProvider.overrideWithValue(_FakeBookRepository(book)),
        studyRepositoryProvider.overrideWithValue(_FakeStudyRepository()),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      ];

  Widget harness({
    required BookData book,
    String readingMode = 'paged',
    int? initialBlockIndex,
  }) {
    return ProviderScope(
      overrides: overrides(
        book: book,
        settings: AppSettings()..readingMode = readingMode,
      ),
      child: MaterialApp(
        theme: buildAppTheme(AppThemeId.hupochangguang),
        home: ReaderPage(
          bookId: '0001-01',
          initialBlockIndex: initialBlockIndex,
        ),
      ),
    );
  }

  /// 等待翻页视图完成排版上屏（EnsoLoading 常转，禁用 pumpAndSettle）。
  Future<void> pumpUntilPaged(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(PageView).evaluate().isNotEmpty) return;
    }
    fail('PageView 未在限时内出现（排版未完成？）');
  }

  /// 逐帧推进翻页动画：ballistic/animateToPage 按帧 tick，单次大步 pump
  /// 不会让模拟收敛。
  Future<void> pumpFrames(WidgetTester tester, {int frames = 45}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('paged 模式：渲染 PageView，无滚动列表，第一页含书名页眉',
      (tester) async {
    await tester.pumpWidget(harness(book: demoBook));
    await pumpUntilPaged(tester);

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(ScrollablePositionedList), findsNothing);
    expect(find.text('大般若波罗蜜多经'), findsWidgets); // 页眉 + AppBar
    expect(find.textContaining('块0'), findsWidgets);
  });

  testWidgets('左滑翻页：下一页内容上屏，进度/页码推进', (tester) async {
    await tester.pumpWidget(harness(book: demoBook));
    await pumpUntilPaged(tester);

    final firstPageMarker = find.textContaining('块0', findRichText: true);
    expect(firstPageMarker, findsWidgets);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
    await pumpFrames(tester);

    // 页码角标出现且 ≥ 第 2 页。
    expect(find.textContaining('第 2 /'), findsOneWidget);
  });

  testWidgets('点按分区：右缘前进、中区显隐 chrome', (tester) async {
    await tester.pumpWidget(harness(book: demoBook));
    await pumpUntilPaged(tester);

    AnimatedSlide slide() =>
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
    expect(slide().offset, Offset.zero, reason: '初始 chrome 可见');

    // 中区点按 → chrome 隐藏。
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 250));
    expect(slide().offset, const Offset(0, -1.2));

    // 再点 → 恢复。
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 250));
    expect(slide().offset, Offset.zero);

    // 右缘点按 → 翻到第 2 页。
    await tester.tapAt(const Offset(750, 300));
    await pumpFrames(tester);
    expect(find.textContaining('第 2 /'), findsOneWidget);
  });

  testWidgets('设置面板：翻页方式切换实时换 body', (tester) async {
    await tester.pumpWidget(harness(book: demoBook, readingMode: 'scroll'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ScrollablePositionedList), findsOneWidget);
    expect(find.byType(PageView), findsNothing);

    // 打开阅读设置 → 出现两个选项。
    await tester.tap(find.byIcon(Icons.text_fields));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('上下滚动'), findsOneWidget);
    expect(find.text('左右翻页'), findsOneWidget);

    await tester.tap(find.text('左右翻页'));
    await pumpUntilPaged(tester);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(ScrollablePositionedList), findsNothing);

    // 切回滚动。
    await tester.tap(find.text('上下滚动'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ScrollablePositionedList), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('?index 锚点：直接落在目标块所在页', (tester) async {
    await tester.pumpWidget(harness(book: demoBook, initialBlockIndex: 40));
    await pumpUntilPaged(tester);

    // 目标块在当前页（或邻页缓存）；远端块不应在树上。
    expect(find.textContaining('块40'), findsWidgets);
    expect(find.textContaining('块0佛'), findsNothing);
  });
}

// ---- Fakes -------------------------------------------------------------------

class _FakeBookRepository implements BookRepository {
  _FakeBookRepository(this.book);

  final BookData book;

  @override
  Stream<BookData?> watchBook(String bookId) => Stream.value(book);

  @override
  Future<bool> isCached(String bookId) async => true;

  @override
  Future<BookFetchOutcome> ensureCached(String bookId) async =>
      BookFetchOutcome.cached;

  @override
  Future<void> deleteCache(String bookId) async {}

  @override
  Stream<List<({String bookId, int sizeBytes, DateTime cachedAt})>>
      watchCachedBooks() => Stream.value(const []);
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
  Stream<List<Bookmark>> watchBookmarks() => Stream.value(const []);

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
  Stream<List<Note>> watchNotes() => Stream.value(const []);

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

/// 与 ink_reader_test 的 _NoopIsar 不同：设置切换（setReadingMode 等）会真正
/// 走 writeTxn → appSettings.put，这里给出最小可用实现。
class _FakeIsar implements Isar {
  final _collection = _FakeAppSettingsCollection();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #writeTxn) {
      final callback = invocation.positionalArguments.first as Function;
      return callback();
    }
    if (invocation.memberName == #collection) return _collection;
    throw StateError('未模拟的 Isar 调用：${invocation.memberName}');
  }
}

class _FakeAppSettingsCollection implements IsarCollection<AppSettings> {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #put) return Future<int>.value(0);
    throw StateError('未模拟的 IsarCollection 调用：${invocation.memberName}');
  }
}
