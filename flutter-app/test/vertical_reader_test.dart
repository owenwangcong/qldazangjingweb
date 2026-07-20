import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:qldazangjing/core/fonts/font_service.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';
import 'package:qldazangjing/core/utils/chinese_converter.dart';
import 'package:qldazangjing/core/vertical/vertical_paginator.dart';
import 'package:qldazangjing/data/models/app_settings.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';
import 'package:qldazangjing/presentation/providers/app_providers.dart';
import 'package:qldazangjing/presentation/widgets/block_jump_controller.dart';
import 'package:qldazangjing/presentation/widgets/vertical_reader.dart';

/// 竖排 S6（视图层）——验收 C9 冒烟：reverse 翻页方向、镜像点按分区、
/// 左→右滑前进、jumpToBlock 即达、页码/进度回调。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChineseConverter converter;

  setUpAll(() async {
    converter = await ChineseConverter.load();
  });

  setUp(VerticalPagination.clearCache);

  final book = BookData(
    meta: const BookMeta(id: 't', bu: '', title: '测试经', author: '某译'),
    blocks: [
      const JuanBlock(id: 'b0', type: JuanBlockType.bt, paragraphs: ['卷第一']),
      JuanBlock(
          id: 'b1',
          type: JuanBlockType.p,
          paragraphs: ['如是我闻，一时佛在王舍城中。' * 200]),
      const JuanBlock(id: 'b2', type: JuanBlockType.bm, paragraphs: ['品第二']),
      JuanBlock(
          id: 'b3',
          type: JuanBlockType.p,
          paragraphs: ['复有五百苾刍尼众皆阿罗汉。' * 60]),
    ],
  );

  testWidgets('C9 冒烟：方向/分区/滑动/跳转/回调', (tester) async {
    final controller = BlockJumpController();
    (int, int, bool)? pageInfo;
    var chromeToggles = 0;
    var lastBlock = -1;
    double progress = -1;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        chineseConverterProvider.overrideWithValue(converter),
        settingsProvider.overrideWith(
          (ref) => SettingsController(
              _NoopIsar(), AppSettings()..readingMode = 'vertical'),
        ),
        fontControllerProvider.overrideWith(
          (ref) => FontController(FontService(), AppFont.system),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(AppThemeId.hupochangguang),
        home: Scaffold(
          body: VerticalReader(
            bookId: 't',
            book: book,
            anchorBlockIndex: null,
            controller: controller,
            onBlockChanged: (b) => lastBlock = b,
            onProgress: (p) => progress = p,
            onPageInfo: (c, t, d) => pageInfo = (c, t, d),
            onToggleChrome: () => chromeToggles++,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 真右开本：PageView 必须 reverse。
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.reverse, isTrue);

    // 首帧回调：第 1 页 / 总页数>1 / done。
    expect(pageInfo, isNotNull);
    expect(pageInfo!.$1, 1);
    expect(pageInfo!.$2, greaterThan(1));
    expect(pageInfo!.$3, isTrue);
    final total = pageInfo!.$2;

    // 镜像点按：左 25% = 下一页。
    await tester.tapAt(const Offset(60, 300));
    await tester.pumpAndSettle();
    expect(pageInfo!.$1, 2);

    // 右 25% = 上一页。
    await tester.tapAt(const Offset(740, 300));
    await tester.pumpAndSettle();
    expect(pageInfo!.$1, 1);

    // 中部 = chrome 显隐，不翻页。
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(chromeToggles, 1);
    expect(pageInfo!.$1, 1);

    // 手指左→右滑 = 下一页（reverse 语义核心断言）。
    await tester.fling(find.byType(PageView), const Offset(320, 0), 1200);
    await tester.pumpAndSettle();
    expect(pageInfo!.$1, 2);
    expect(lastBlock, greaterThanOrEqualTo(0));

    // jumpToBlock 即达：跳末块 → 落在其首现页。
    controller.jumpToBlock(3);
    await tester.pumpAndSettle();
    expect(pageInfo!.$1, greaterThan(2));
    expect(pageInfo!.$1, lessThanOrEqualTo(total));
    expect(progress, greaterThan(0));
  });

  testWidgets('乌丝栏开关只重绘不重排（分页缓存键不含开关）', (tester) async {
    late SettingsController settings;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chineseConverterProvider.overrideWithValue(converter),
        settingsProvider.overrideWith((ref) {
          settings = SettingsController(
              _NoopIsar2(), AppSettings()..readingMode = 'vertical');
          return settings;
        }),
        fontControllerProvider.overrideWith(
          (ref) => FontController(FontService(), AppFont.system),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(AppThemeId.hupochangguang),
        home: Scaffold(
          body: VerticalReader(
            bookId: 't',
            book: book,
            anchorBlockIndex: null,
            controller: BlockJumpController(),
            onBlockChanged: (_) {},
            onProgress: (_) {},
            onPageInfo: (_, __, ___) {},
            onToggleChrome: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final keysBefore = VerticalPagination.debugCacheKeys;
    await settings.setShowColumnRules(false);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(VerticalPagination.debugCacheKeys, keysBefore,
        reason: '乌丝栏切换不得触发重排');
  });
}

class _NoopIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('测试中不应使用 Isar：${invocation.memberName}');
}

/// 需要 setter 落库路径的最小假件。
class _NoopIsar2 implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #writeTxn) {
      return (invocation.positionalArguments.first as Function)();
    }
    if (invocation.memberName == #collection) return _NoopCollection();
    throw StateError('测试中不应使用 Isar：${invocation.memberName}');
  }
}

class _NoopCollection implements IsarCollection<AppSettings> {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #put) return Future<int>.value(0);
    throw StateError('测试中不应使用 IsarCollection：${invocation.memberName}');
  }
}
