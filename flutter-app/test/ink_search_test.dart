import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:qldazangjing/core/ink/ink.dart';
import 'package:qldazangjing/core/network/connectivity_service.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';
import 'package:qldazangjing/core/utils/chinese_converter.dart';
import 'package:qldazangjing/data/models/app_settings.dart';
import 'package:qldazangjing/data/models/catalog_models.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';
import 'package:qldazangjing/domain/repositories/repositories.dart';
import 'package:qldazangjing/presentation/pages/search_page.dart';
import 'package:qldazangjing/presentation/providers/app_providers.dart';

/// P3.5 搜索页：砚台搜索框、墨字模式切换、结果高亮 = 朱砂淡染（对比度 ≥4.5）。
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
        searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
        connectivityServiceProvider.overrideWithValue(_FakeConnectivity()),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(theme),
        home: const SearchPage(),
      ),
    );
  }

  testWidgets('P3.5 模式切换 = 墨字页签（无 SegmentedButton），命中区 ≥48dp',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(find.byType(InkToggle), findsOneWidget);
    expect(tester.getSize(find.byType(InkToggle)).height,
        greaterThanOrEqualTo(48));
  });

  testWidgets('P3.5 高亮 <em> = 朱砂淡染；空闲态淡莲花 ≤1 处', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    // 空闲态（未搜索）：唯一淡莲花。
    expect(find.byType(LotusOutline), findsOneWidget);

    // 触发全文搜索（fake 返回带 <em> 的片段）。
    await tester.enterText(find.byType(TextField), '般若');
    await tester.tap(find.text('搜索'));
    await tester.pump();
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
          expect(bg, expected, reason: '<em> 高亮底色应为 sealRed 0.22 淡染');
          found = true;
        }
        return true;
      });
    }
    expect(found, isTrue, reason: '搜索结果应有高亮 span');

    // 结果卡为 InkCard。
    expect(find.byType(InkCard), findsAtLeastNWidgets(1));
    // 搜索后莲花退场（仅空态展示）。
    expect(find.byType(LotusOutline), findsNothing);
  });

  test('P3.5 高亮文字对比度：六主题 ≥4.5（叠淡染底）', () {
    for (final theme in AppThemeId.values) {
      final palette = buildAppTheme(theme).extension<AppColors>()!;
      final ink = InkTokens.forTheme(theme);
      // 高亮渲染在 muted 0.6 衬底之上，再叠 sealRed 0.22。
      final mutedBase =
          Color.alphaBlend(palette.muted.withValues(alpha: 0.6), palette.background);
      final blended =
          Color.alphaBlend(ink.sealRed.withValues(alpha: 0.22), mutedBase);
      final ratio = _contrastRatio(palette.foreground, blended);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: '主题 ${theme.key} 高亮对比度 $ratio 不足 4.5');
    }
  });

  testWidgets('P3.5 六主题构建无异常/overflow', (tester) async {
    for (final theme in AppThemeId.values) {
      await tester.pumpWidget(harness(theme: theme));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '主题 ${theme.key} 异常');
    }
  });
}

double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

class _FakeSearchRepository implements SearchRepository {
  @override
  Future<FullTextSearchPage> searchFullText({
    required String query,
    required bool phraseMatch,
    required int page,
  }) async {
    return FullTextSearchPage(
      total: 1,
      hits: [
        SearchHit(
          id: '0001-01',
          title: '大般若波罗蜜多经',
          author: '唐三藏法师玄奘奉诏译',
          score: 12.3,
          contentHighlights: const ['如是我闻：一时，薄伽梵住<em>般若</em>会上。'],
        ),
      ],
    );
  }
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
  Future<List<CatalogBook>> getBooks(List<String> bookIds) async => const [];

  @override
  Future<List<CatalogBook>> searchTitles(String simplifiedQuery) async =>
      const [];
}

class _FakeConnectivity implements ConnectivityService {
  @override
  bool get isOnline => true;

  @override
  Stream<bool> get onStatusChange => Stream.value(true);

  @override
  Future<void> dispose() async {}
}

class _NoopIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('测试中不应使用 Isar：${invocation.memberName}');
}
