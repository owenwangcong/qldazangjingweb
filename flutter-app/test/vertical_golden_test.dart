import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/vertical/vertical_models.dart';
import 'package:qldazangjing/core/vertical/vertical_paginator.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';
import 'package:qldazangjing/presentation/widgets/vertical_page_painter.dart';

/// 竖排 S7——golden 锁定（C6 复验）：Ahem 字体下每字形 = 1em 实心方块，
/// 矩阵对齐/悬浮标点/乌丝栏在像素层一览无余；任何几何回归都会破图。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(VerticalPagination.clearCache);

  final book = BookData(
    meta: const BookMeta(id: 'golden-t', bu: '', title: '测试经', author: '某译'),
    blocks: const [
      JuanBlock(id: 'b0', type: JuanBlockType.bt, paragraphs: ['卷第一']),
      JuanBlock(id: 'b1', type: JuanBlockType.p, paragraphs: [
        '诸法从本来，常自寂灭相。佛子行道已，来世得作佛。'
            '愿以此功德，庄严佛净土。上报四重恩，下济三途苦。',
      ]),
      JuanBlock(id: 'b2', type: JuanBlockType.p, paragraphs: [
        '如是我闻：一时，佛在王舍城。',
      ]),
    ],
  );

  Widget harness({required bool baiwen, required bool showRules}) {
    final key = VerticalPaginationKey(
      bookId: 'golden-t',
      contentSize: const Size(350, 700),
      fontFamily: '',
      fontSize: 20,
      lineHeight: 1.75,
      letterSpacingEm: 0,
      isSimplified: true,
      baiwen: baiwen,
      textScaleFactor: 1,
    );
    final result =
        VerticalPagination.run(key: key, book: book, display: (s) => s);
    final styles = VerticalPageStyles(
      fontFamily: null,
      fontSize: result.grid.fontSize,
      gap: result.grid.gap,
      foreground: const Color(0xFF2A2118),
      muted: const Color(0xFF8A7B66),
    );
    return Center(
      child: RepaintBoundary(
        child: Container(
          width: 350,
          height: 700,
          color: const Color(0xFFF4E9D3), // 琥珀长光纸色近似
          child: CustomPaint(
            painter: VerticalPagePainter(
              page: result.pages.first,
              grid: result.grid,
              styles: styles,
              glyphs: GlyphCache(),
              showColumnRules: showRules,
              ruleColor: const Color(0x472A2118),
              ruleStrokeWidth: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('golden：句读 + 乌丝栏（矩阵/悬浮标点/界线）', (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: harness(baiwen: false, showRules: true),
    ));
    await expectLater(find.byType(RepaintBoundary).last,
        matchesGoldenFile('goldens/vertical_matrix_judou.png'));
  });

  testWidgets('golden：白文 + 无乌丝栏（纯矩阵对照）', (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: harness(baiwen: true, showRules: false),
    ));
    await expectLater(find.byType(RepaintBoundary).last,
        matchesGoldenFile('goldens/vertical_matrix_baiwen.png'));
  });
}
