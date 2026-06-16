import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:qldazangjing/core/ink/ink.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';
import 'package:qldazangjing/core/utils/chinese_converter.dart';
import 'package:qldazangjing/data/models/app_settings.dart';
import 'package:qldazangjing/data/models/catalog_models.dart';
import 'package:qldazangjing/domain/repositories/repositories.dart';
import 'package:qldazangjing/presentation/pages/section_page.dart';
import 'package:qldazangjing/presentation/providers/app_providers.dart';

/// P3.3 Section 页：列表项 = 笺纸卡 InkCard、行高 ≥48dp、边距 ≥16dp、
/// Material Card 清零。
void main() {
  late ChineseConverter converter;

  setUpAll(() async {
    converter = await ChineseConverter.load();
  });

  CatalogBook book(String id, String title) => CatalogBook()
    ..bookId = id
    ..sectionId = '01'
    ..bu = '第 1 部'
    ..title = title
    ..author = '唐三藏法师玄奘奉诏译'
    ..volume = '六百卷'
    ..isMulu = false
    ..order = 0;

  final demoBooks = [
    book('0001-01', '大般若波罗蜜多经'),
    book('0001-02', '放光般若波罗蜜经'),
  ];

  Widget harness({AppThemeId theme = AppThemeId.hupochangguang}) {
    return ProviderScope(
      overrides: [
        chineseConverterProvider.overrideWithValue(converter),
        settingsProvider.overrideWith(
          (ref) => SettingsController(
              _NoopIsar(), AppSettings()..themeKey = theme.key),
        ),
        catalogRepositoryProvider
            .overrideWithValue(_FakeCatalogRepository(demoBooks)),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(theme),
        home: const SectionPage(sectionId: '01'),
      ),
    );
  }

  Future<void> pumpPage(WidgetTester tester,
      {AppThemeId theme = AppThemeId.hupochangguang}) async {
    await tester.pumpWidget(harness(theme: theme));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('P3.3 列表项 = 笺纸卡，行高 ≥48dp，水平边距 ≥16dp', (tester) async {
    await pumpPage(tester);

    final screen = tester.getSize(find.byType(SectionPage));
    for (final b in demoBooks) {
      final card = find.widgetWithText(InkCard, b.title);
      expect(card, findsOneWidget, reason: '${b.title} 应为 InkCard');
      final rect = tester.getRect(card);
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(rect.left, greaterThanOrEqualTo(16));
      expect(screen.width - rect.right, greaterThanOrEqualTo(16));
    }

    // Material 默认 Card 清零（§10 无默认观感）。
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('P3.3 六主题构建无异常/overflow', (tester) async {
    for (final theme in AppThemeId.values) {
      await pumpPage(tester, theme: theme);
      expect(tester.takeException(), isNull, reason: '主题 ${theme.key} 异常');
    }
  });
}

class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository(this.books);

  final List<CatalogBook> books;

  @override
  Stream<List<CatalogBook>> watchBooksOfSection(String sectionId) =>
      Stream.value(books);

  @override
  Stream<List<CatalogSection>> watchSections() => Stream.value([
        CatalogSection()
          ..sectionId = '01'
          ..name = '大乘般若部'
          ..order = 0,
      ]);

  @override
  Stream<Map<String, List<ClassicEntry>>> watchClassics() =>
      Stream.value(const {});

  @override
  Future<CatalogBook?> getBook(String bookId) async => null;

  @override
  Future<List<CatalogBook>> getBooks(List<String> bookIds) async => const [];

  @override
  Future<List<CatalogBook>> searchTitles(String simplifiedQuery) async =>
      const [];
}

class _NoopIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('测试中不应使用 Isar：${invocation.memberName}');
}
