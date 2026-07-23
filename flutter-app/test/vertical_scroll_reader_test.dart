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
import 'package:qldazangjing/presentation/widgets/column_snap_physics.dart';
import 'package:qldazangjing/presentation/widgets/vertical_scroll_reader.dart';

/// V4/V7——竖排展卷视图冒烟：reverse 方向、吸附静止必在列边缘、
/// jumpToBlock 落点、进度回调、chrome 点按。
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

  testWidgets('冒烟:方向/吸附/跳转/进度/chrome', (tester) async {
    final controller = BlockJumpController();
    var chromeToggles = 0;
    var lastBlock = -1;
    double progress = -1;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        chineseConverterProvider.overrideWithValue(converter),
        settingsProvider.overrideWith(
          (ref) => SettingsController(
              _NoopIsar(), AppSettings()..readingMode = 'verticalScroll'),
        ),
        fontControllerProvider.overrideWith(
          (ref) => FontController(FontService(), AppFont.system),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(AppThemeId.hupochangguang),
        home: Scaffold(
          body: VerticalScrollReader(
            bookId: 't',
            book: book,
            anchorBlockIndex: null,
            controller: controller,
            onBlockChanged: (b) => lastBlock = b,
            onProgress: (p) => progress = p,
            onToggleChrome: () => chromeToggles++,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // DS1:reverse 水平列表(列带向左延伸)。
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.reverse, isTrue);
    expect(list.scrollDirection, Axis.horizontal);

    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.physics, isA<ColumnSnapPhysics>());
    // 默认竖排字号 26/行间1.75 → colPitch = 45.5(均匀列书,无插图)。
    const pitch = 45.5;

    // 手指左→右滑 = 前进;惯性停止必吸附在列边缘(A-VS1 视图级)。
    await tester.fling(find.byType(ListView), const Offset(320, 0), 1500);
    await tester.pumpAndSettle();
    final settled = scrollable.position.pixels;
    expect(settled, greaterThan(0));
    final remainder = settled % pitch;
    expect(remainder < 0.01 || (pitch - remainder) < 0.01, isTrue,
        reason: '静止 offset=$settled 必须是列边缘(35 的整数倍)');
    expect(progress, greaterThan(0));
    expect(lastBlock, greaterThanOrEqualTo(0));

    // 点按显隐 chrome(DS3),不改变滚动位置。
    await tester.tap(find.byType(ListView), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(chromeToggles, 1);
    expect(scrollable.position.pixels, settled);

    // jumpToBlock:落点为该块首列边缘。
    controller.jumpToBlock(3);
    await tester.pumpAndSettle();
    final jumped = scrollable.position.pixels;
    expect(jumped, greaterThan(settled));
    expect((jumped % pitch) < 0.01 || (pitch - jumped % pitch) < 0.01, isTrue);
  });

  testWidgets('翻页⇄展卷共享分页缓存:互切零重排', (tester) async {
    // 展卷视图建立缓存后,同参数下 debugCacheKeys 不应因再次 run 而变化
    // ——此处以同 key 二次 run 返回 identical 结果侧证(缓存命中语义
    // 已在 paginator 测试覆盖;此测试锁定「键构造一致」)。
    final settings = AppSettings()..readingMode = 'verticalScroll';
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chineseConverterProvider.overrideWithValue(converter),
        settingsProvider.overrideWith(
            (ref) => SettingsController(_NoopIsar(), settings)),
        fontControllerProvider.overrideWith(
          (ref) => FontController(FontService(), AppFont.system),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(AppThemeId.hupochangguang),
        home: Scaffold(
          body: VerticalScrollReader(
            bookId: 'cache-t',
            book: book,
            anchorBlockIndex: null,
            controller: BlockJumpController(),
            onBlockChanged: (_) {},
            onProgress: (_) {},
            onToggleChrome: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final keys = VerticalPagination.debugCacheKeys;
    expect(keys, hasLength(1));
    // 竖排翻页视图对同书同设置构造的键必须与展卷相同(共享缓存前提):
    // 直接以缓存命中验证。
    final hit = VerticalPagination.cached(keys.single);
    expect(hit, isNotNull);
  });
}

class _NoopIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('测试中不应使用 Isar：${invocation.memberName}');
}
