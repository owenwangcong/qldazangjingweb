import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:qldazangjing/core/ink/ink.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';
import 'package:qldazangjing/core/utils/chinese_converter.dart';
import 'package:qldazangjing/data/models/app_settings.dart';
import 'package:qldazangjing/data/models/user_data.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';
import 'package:qldazangjing/domain/repositories/repositories.dart';
import 'package:qldazangjing/presentation/pages/reader_page.dart';
import 'package:qldazangjing/presentation/providers/app_providers.dart';
import 'package:qldazangjing/presentation/widgets/reader_settings_sheet.dart';

/// P3.4 Reader 页：留白边距（≥600dp 宽 → ≥10% 屏宽）、章节笔触标题、
/// 朱砂淡染高亮对比度、阅读设置面板水墨化、EnsoLoading。
void main() {
  late ChineseConverter converter;

  setUpAll(() async {
    converter = await ChineseConverter.load();
  });

  final demoBook = BookData(
    meta: const BookMeta(
      id: '0001-01',
      bu: '大乘般若部·第0001部',
      title: '大般若波罗蜜多经',
      author: '唐三藏法师玄奘奉诏译',
    ),
    blocks: [
      JuanBlock.fromJson({
        'id': 'j1',
        'type': 'bt',
        'content': ['大般若波罗蜜多经卷第一'],
      })!,
      JuanBlock.fromJson({
        'id': 'p-0',
        'type': 'p',
        'content': ['如是我闻：一时，薄伽梵住王舍城鹫峰山顶。'],
      })!,
    ],
  );

  List<Override> overrides({
    BookData? book,
    AppThemeId theme = AppThemeId.hupochangguang,
  }) =>
      [
        chineseConverterProvider.overrideWithValue(converter),
        settingsProvider.overrideWith(
          (ref) => SettingsController(
              _NoopIsar(), AppSettings()..themeKey = theme.key),
        ),
        bookRepositoryProvider.overrideWithValue(_FakeBookRepository(book)),
        studyRepositoryProvider.overrideWithValue(_FakeStudyRepository()),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      ];

  Widget harness({
    BookData? book,
    AppThemeId theme = AppThemeId.hupochangguang,
    String? highlight,
  }) {
    return ProviderScope(
      overrides: overrides(book: book, theme: theme),
      child: MaterialApp(
        theme: buildAppTheme(theme),
        home: ReaderPage(bookId: '0001-01', highlightText: highlight),
      ),
    );
  }

  testWidgets('P3.4 留白：≥600dp 宽时正文边距 ≥10% 屏宽', (tester) async {
    await tester.pumpWidget(harness(book: demoBook));
    await tester.pump();
    await tester.pump();

    final screen = tester.getSize(find.byType(ReaderPage));
    expect(screen.width, greaterThanOrEqualTo(600),
        reason: '测试面宽须 ≥600 才能验证宽屏分支');
    final body = tester.getRect(find.textContaining('如是我闻'));
    expect(body.left, greaterThanOrEqualTo(screen.width * 0.10));
    expect(screen.width - body.right,
        greaterThanOrEqualTo(screen.width * 0.10 - 0.5));
  });

  testWidgets('P3.4 章节笔触标题：书名页眉 + bt 块均带 BrushUnderline',
      (tester) async {
    await tester.pumpWidget(harness(book: demoBook));
    await tester.pump();
    await tester.pump();

    // 书名页眉 1 + 卷题 bt 1 = 至少 2 道笔触下划线。
    expect(
        find.byType(BrushUnderline), findsAtLeastNWidgets(2));
  });

  testWidgets('P3.4 加载态使用 EnsoLoading（无 Material 转圈）', (tester) async {
    await tester.pumpWidget(harness(book: null));
    await tester.pump();

    expect(find.byType(EnsoLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('P3.4 搜索高亮 = 朱砂淡染（无硬编码黄色）', (tester) async {
    await tester.pumpWidget(harness(book: demoBook, highlight: '薄伽梵'));
    await tester.pump();
    await tester.pump();

    final ink = InkTokens.forTheme(AppThemeId.hupochangguang);
    final expected = ink.sealRed.withValues(alpha: 0.22);
    var found = false;
    for (final element in find.byType(Text).evaluate()) {
      final text = element.widget as Text;
      final span = text.textSpan;
      if (span == null) continue;
      span.visitChildren((child) {
        final bg = child.style?.backgroundColor;
        if (bg != null) {
          expect(bg, expected, reason: '高亮底色应为 sealRed 0.22 淡染');
          expect(bg, isNot(const Color(0xFFFEF08A)));
          found = true;
        }
        return true;
      });
    }
    expect(found, isTrue, reason: '应存在高亮 span');
  });

  test('P3.4 高亮对比度：六主题正文字色 vs 朱砂淡染底 ≥3:1', () {
    for (final theme in AppThemeId.values) {
      final palette = buildAppTheme(theme).extension<AppColors>()!;
      final ink = InkTokens.forTheme(theme);
      final blended =
          Color.alphaBlend(ink.sealRed.withValues(alpha: 0.22), palette.background);
      final ratio = _contrastRatio(palette.foreground, blended);
      expect(ratio, greaterThanOrEqualTo(3.0),
          reason: '主题 ${theme.key} 高亮对比度 $ratio 不足 3:1');
    }
  });

  testWidgets('P3.4 阅读设置面板水墨化：无 SegmentedButton/ChoiceChip，六主题纸样',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(book: demoBook),
        child: MaterialApp(
          theme: buildAppTheme(AppThemeId.hupochangguang),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showReaderSettingsSheet(context),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(Slider), findsNWidgets(4));
    // 主题区在折叠线以下：先把面板列表滚到底再断言。
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    for (final theme in AppThemeId.values) {
      expect(find.text(theme.label), findsOneWidget);
    }
    // 简繁墨字切换存在。
    expect(find.text('简体'), findsOneWidget);
    expect(find.text('繁體'), findsOneWidget);
  });
}

/// WCAG 相对亮度对比度（与 ink_tokens_test 同式）。
double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

class _FakeBookRepository implements BookRepository {
  _FakeBookRepository(this.book);

  final BookData? book;

  @override
  Stream<BookData?> watchBook(String bookId) =>
      book == null ? const Stream.empty() : Stream.value(book);

  @override
  Future<bool> isCached(String bookId) async => book != null;

  @override
  Future<BookFetchOutcome> ensureCached(String bookId) async =>
      // 测试恒返回 cached：book == null 的用例要停留在「加载中」态
      // （queuedOffline 会切到离线提示分支）。
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

class _NoopIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('测试中不应使用 Isar：${invocation.memberName}');
}
