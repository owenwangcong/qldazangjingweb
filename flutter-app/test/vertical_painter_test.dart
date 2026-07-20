import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/vertical/vertical_models.dart';
import 'package:qldazangjing/core/vertical/vertical_paginator.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';
import 'package:qldazangjing/presentation/widgets/vertical_page_painter.dart';

/// 竖排 S7——画师坐标断言（真实绘制调用口径，非公式复读）：
/// C6 矩阵对齐（字形落点严格落在网格、行列等差）
/// C7 标点悬浮（零侵占字面框、em 框不触乌丝栏、字距恒定）
/// C8 乌丝栏（位置/两端/数量/开关零绘制）
///
/// 测试字体为 Ahem（全字形 = 1em 实心方块）：CJK 字形盒恰为
/// fontSize×fontSize，双向居中后 dx==colX、dy==cellY，断言可取严格等值。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(VerticalPagination.clearCache);

  const key = VerticalPaginationKey(
    bookId: 'painter-t',
    contentSize: Size(350, 700), // 35 格 × 10 列,gap 15
    fontFamily: '',
    fontSize: 20,
    lineHeight: 1.75,
    letterSpacingEm: 0,
    isSimplified: true,
    baiwen: false,
    textScaleFactor: 1,
  );

  final book = BookData(
    meta: const BookMeta(id: 'painter-t', bu: '', title: '测试经', author: '某译'),
    blocks: const [
      JuanBlock(id: 'b0', type: JuanBlockType.bt, paragraphs: ['卷第一']),
      JuanBlock(id: 'b1', type: JuanBlockType.p, paragraphs: [
        // 五言偈 8 句（40 字）→ 35+5 两列,句首顶格对齐。
        '诸法从本来，常自寂灭相。佛子行道已，来世得作佛。'
            '愿以此功德，庄严佛净土。上报四重恩，下济三途苦。',
      ]),
      JuanBlock(id: 'b2', type: JuanBlockType.p, paragraphs: [
        '如是我闻：一时，佛在王舍城。', // 密集标点段
      ]),
    ],
  );

  ({VerticalPaginationResult result, _RecordingCanvas canvas, VerticalPageStyles styles})
      paintFirstPage({required bool showRules, bool baiwen = false}) {
    final k = baiwen
        ? const VerticalPaginationKey(
            bookId: 'painter-t',
            contentSize: Size(350, 700),
            fontFamily: '',
            fontSize: 20,
            lineHeight: 1.75,
            letterSpacingEm: 0,
            isSimplified: true,
            baiwen: true,
            textScaleFactor: 1,
          )
        : key;
    final result =
        VerticalPagination.run(key: k, book: book, display: (s) => s);
    final styles = VerticalPageStyles(
      fontFamily: null,
      fontSize: result.grid.fontSize,
      gap: result.grid.gap,
      foreground: const Color(0xFF2A2118),
      muted: const Color(0xFF8A7B66),
    );
    final canvas = _RecordingCanvas();
    VerticalPagePainter(
      page: result.pages.first,
      grid: result.grid,
      styles: styles,
      glyphs: GlyphCache(),
      showColumnRules: showRules,
      ruleColor: const Color(0x442A2118),
      ruleStrokeWidth: 0.5,
    ).paint(canvas, const Size(350, 700));
    return (result: result, canvas: canvas, styles: styles);
  }

  group('C6 矩阵对齐（绘制落点）', () {
    test('全部主体字形落点与网格公式严格等值；行列等差', () {
      final p = paintFirstPage(showRules: true);
      final grid = p.result.grid;
      final page = p.result.pages.first;

      // 期望落点：按列/格公式推导（Ahem 主体盒 20、作者盒 16 → 居中偏移 2；
      // 偈颂列行号 = ti + ti÷n，句间空一格 D6）。
      final expected = <Offset>[];
      for (var ci = 0; ci < page.columns.length; ci++) {
        final col = page.columns[ci];
        final boxSize = col.role == VColumnRole.author ? 16.0 : 20.0;
        final inset = (grid.cellW - boxSize) / 2;
        final n = col.verseClauseLen;
        for (var ti = 0; ti < col.tokens.length; ti++) {
          final row = col.indent + ti + (n == null ? 0 : ti ~/ n);
          expected.add(
              Offset(grid.colX(ci) + inset, grid.cellY(row) + inset));
        }
      }
      final actual = p.canvas.paragraphs
          .where((d) => d.$1.height > 10) // 主体/作者字形（标点 7.8 排除）
          .map((d) => d.$2)
          .toList();
      expect(actual, expected, reason: '绘制次序与落点应与网格完全一致');

      // 非偈颂列内相邻字距恒等于 cellH（含带标点字——C7 的字距零侵占）；
      // 偈颂列的句间空格由上面的精确落点断言覆盖。
      final proseXs = <double>{};
      for (var ci = 0; ci < page.columns.length; ci++) {
        if (page.columns[ci].verseClauseLen == null) {
          proseXs.add(grid.colX(ci));
        }
      }
      final byX = <double, List<double>>{};
      for (final o in actual) {
        byX.putIfAbsent(o.dx, () => []).add(o.dy);
      }
      for (final e in byX.entries) {
        if (!proseXs.contains(e.key) && !proseXs.contains(e.key - 2)) continue;
        final dys = e.value;
        for (var i = 1; i < dys.length; i++) {
          expect(dys[i] - dys[i - 1], moreOrLessEquals(grid.cellH),
              reason: '标点不得挤占字距');
        }
      }
    });

    test('偈颂两列句首均顶格（跨列横向对齐）', () {
      final p = paintFirstPage(showRules: true);
      final page = p.result.pages.first;
      final verseCols = <int>[];
      for (var ci = 0; ci < page.columns.length; ci++) {
        final col = page.columns[ci];
        if (col.role == VColumnRole.body &&
            col.tokens.first.blockIndex == 1) {
          verseCols.add(ci);
        }
      }
      expect(verseCols.length, 2, reason: '40 字五言（D6 句间空格）应折为 30+10 两列');
      expect(page.columns[verseCols[0]].tokens.length, 30);
      expect(page.columns[verseCols[1]].tokens.length, 10);
      for (final ci in verseCols) {
        expect(page.columns[ci].indent, 0);
        expect(page.columns[ci].tokens.length % 5, 0);
        expect(page.columns[ci].verseClauseLen, 5);
      }
    });
  });

  group('C7 标点悬浮', () {
    test('标点 em 框：不侵入字面框、不触乌丝栏、纵向不出文本区', () {
      final p = paintFirstPage(showRules: true);
      final grid = p.result.grid;
      final puncts = p.canvas.paragraphs
          .where((d) => d.$1.height < 10)
          .toList();
      expect(puncts, isNotEmpty, reason: '样本含密集标点');

      final colRights = [
        for (var i = 0; i < grid.colsPerPage; i++) grid.colX(i) + grid.cellW
      ];
      for (final (para, offset) in puncts) {
        // 找所属列：em 框左缘必须在某列右缘之外（零侵占）。
        final ci = colRights.indexWhere((r) =>
            offset.dx >= r - 1e-6 && offset.dx < r + grid.gap);
        expect(ci, isNot(-1),
            reason: '标点 ${offset.dx} 必须落在某列右侧间隙内');
        final punctW = para.longestLine;
        if (ci >= 1) {
          // 与左邻列之间存在乌丝栏（线在列 ci 右缘 + 0.62gap…等下：
          // ruleX(i) 定义于列 i 右缘外,i≥1——列 0 右侧无线）。
          expect(offset.dx + punctW,
              lessThanOrEqualTo(colRights[ci] + grid.gap * 0.62 + 1e-6),
              reason: '标点 em 框不得触碰乌丝栏');
        }
        expect(offset.dy, greaterThanOrEqualTo(-1e-6));
        expect(offset.dy + para.height,
            lessThanOrEqualTo(grid.gridBottom + 1e-6),
            reason: '标点纵向不得越出文本区');
      }
    });

    test('白文页零标点绘制,主体落点与句读页逐点一致', () {
      final judou = paintFirstPage(showRules: true);
      final baiwen = paintFirstPage(showRules: true, baiwen: true);

      List<Offset> bodyOf(_RecordingCanvas c) => c.paragraphs
          .where((d) => d.$1.height > 10)
          .map((d) => d.$2)
          .toList();
      expect(
          baiwen.canvas.paragraphs.where((d) => d.$1.height < 10), isEmpty);
      expect(bodyOf(baiwen.canvas), bodyOf(judou.canvas),
          reason: '标点有无绝不改变主体矩阵（C7 核心）');
    });
  });

  group('C8 乌丝栏', () {
    test('数量 = 实有列数−1;x 在列隙 0.62 处;两端与文本区齐平', () {
      final p = paintFirstPage(showRules: true);
      final grid = p.result.grid;
      final cols = p.result.pages.first.columns.length;
      expect(p.canvas.lines.length, cols - 1);
      for (var i = 1; i < cols; i++) {
        final (p1, p2, _) = p.canvas.lines[i - 1];
        expect(p1.dx, moreOrLessEquals(grid.ruleX(i)));
        expect(p2.dx, p1.dx);
        expect(p1.dy, 0);
        expect(p2.dy, moreOrLessEquals(grid.gridBottom));
      }
    });

    test('开关关闭 → 零线条绘制', () {
      final p = paintFirstPage(showRules: false);
      expect(p.canvas.lines, isEmpty);
    });
  });
}

/// 记录型 Canvas：拦截画师的真实绘制调用（字形 drawParagraph、
/// 乌丝栏 drawLine），其余成员静默。
class _RecordingCanvas implements Canvas {
  final paragraphs = <(ui.Paragraph, Offset)>[];
  final lines = <(Offset, Offset, Paint)>[];

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) =>
      paragraphs.add((paragraph, offset));

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      lines.add((p1, p2, paint));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
