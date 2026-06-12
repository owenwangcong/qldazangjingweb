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
import 'package:qldazangjing/presentation/pages/home_page.dart';
import 'package:qldazangjing/presentation/providers/app_providers.dart';

/// P3.2 首页水墨化：留白规范（§1#1）、笺纸卡、册页题签、空态淡莲花。
void main() {
  late ChineseConverter converter;

  setUpAll(() async {
    converter = await ChineseConverter.load();
  });

  CatalogSection section(String id, String name, int order) =>
      CatalogSection()
        ..sectionId = id
        ..name = name
        ..order = order;

  ClassicEntry classic(String cat, String bookId, String title, int order) =>
      ClassicEntry()
        ..category = cat
        ..bookId = bookId
        ..title = title
        ..order = order;

  Widget harness({
    required List<CatalogSection> sections,
    required Map<String, List<ClassicEntry>> classics,
  }) {
    return ProviderScope(
      overrides: [
        chineseConverterProvider.overrideWithValue(converter),
        settingsProvider.overrideWith(
          (ref) => SettingsController(_NoopIsar(), AppSettings()),
        ),
        catalogRepositoryProvider.overrideWithValue(
          _FakeCatalogRepository(sections: sections, classics: classics),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(AppThemeId.hupochangguang),
        home: const HomePage(),
      ),
    );
  }

  final demoSections = [
    section('01', '大乘般若部', 0),
    section('02', '大乘宝积部', 1),
    section('03', '大乘大集部', 2),
    section('04', '大乘华严部', 3),
  ];
  final demoClassics = {
    '般若': [classic('般若', '0001-01', '大般若经', 0)],
    '净土': [classic('净土', '0366', '阿弥陀经', 0)],
  };

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      harness(sections: demoSections, classics: demoClassics),
    );
    await tester.pump(); // 让 StreamProvider 吐出首个事件
    await tester.pump();
  }

  testWidgets('P3.2 留白规范：水平边距 ≥16dp、区块垂直间距 ≥12dp', (tester) async {
    await pumpHome(tester);

    final screen = tester.getSize(find.byType(HomePage));
    final classicsCard =
        tester.getRect(find.widgetWithText(InkCard, '常用经典'));
    final title = tester.getRect(find.text('部类目录'));
    final firstGridCard =
        tester.getRect(find.widgetWithText(InkCard, '大乘般若部'));

    // 水平边距 ≥16dp（左右两侧）。
    expect(classicsCard.left, greaterThanOrEqualTo(16));
    expect(screen.width - classicsCard.right, greaterThanOrEqualTo(16));
    expect(title.left, greaterThanOrEqualTo(16));
    expect(firstGridCard.left, greaterThanOrEqualTo(16));

    // 区块垂直间距 ≥12dp：经典卡 → 标题 → 部类网格。
    expect(title.top - classicsCard.bottom, greaterThanOrEqualTo(12));
    expect(firstGridCard.top - title.bottom, greaterThanOrEqualTo(12));
  });

  testWidgets('P3.2 部类目录 = 笺纸卡 InkCard，命中区 ≥48dp', (tester) async {
    await pumpHome(tester);

    for (final s in demoSections) {
      final card = find.widgetWithText(InkCard, s.name);
      expect(card, findsOneWidget, reason: '部类 ${s.name} 应为 InkCard');
      expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('P3.2 常用经典 = 册页题签，无 Material chip，命中区 ≥48dp',
      (tester) async {
    await pumpHome(tester);

    // Material 默认 chip 全部退场（§10 无默认观感）。
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(ActionChip), findsNothing);

    // 题签为 InkCard（吃墨边缘）——文字的 InkCard 祖先 = 外层经典卡 + 题签
    // 本体共 2 个；取最内层（最小高度）断言命中区 ≥48。
    final slipCards = find.ancestor(
      of: find.text('大般若经'),
      matching: find.byType(InkCard),
    );
    expect(slipCards, findsNWidgets(2));
    final slipHeight = slipCards
        .evaluate()
        .map((e) => e.size!.height)
        .reduce((a, b) => a < b ? a : b);
    expect(slipHeight, greaterThanOrEqualTo(48));

    // 选中分类有且仅有一道笔触下划线（形状差异）。
    expect(find.byType(BrushUnderline), findsOneWidget);
  });

  testWidgets('P3.2 空态淡莲花 ≤1 处', (tester) async {
    await tester.pumpWidget(harness(sections: const [], classics: const {}));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LotusOutline), findsOneWidget);
    expect(find.text('暂无目录'), findsOneWidget);
  });

  testWidgets('P3.2 六主题构建无异常/overflow', (tester) async {
    for (final theme in AppThemeId.values) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chineseConverterProvider.overrideWithValue(converter),
            settingsProvider.overrideWith(
              (ref) => SettingsController(
                  _NoopIsar(), AppSettings()..themeKey = theme.key),
            ),
            catalogRepositoryProvider.overrideWithValue(
              _FakeCatalogRepository(
                  sections: demoSections, classics: demoClassics),
            ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(theme),
            home: const HomePage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '主题 ${theme.key} 异常');
    }
  });
}

class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository({required this.sections, required this.classics});

  final List<CatalogSection> sections;
  final Map<String, List<ClassicEntry>> classics;

  @override
  Stream<List<CatalogSection>> watchSections() => Stream.value(sections);

  @override
  Stream<Map<String, List<ClassicEntry>>> watchClassics() =>
      Stream.value(classics);

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

/// settingsProvider 的构造需要 Isar；测试中不应触发任何持久化。
class _NoopIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('测试中不应使用 Isar：${invocation.memberName}');
}
