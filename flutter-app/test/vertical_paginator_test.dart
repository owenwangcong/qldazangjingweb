import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/vertical/grid_geometry.dart';
import 'package:qldazangjing/core/vertical/token_stream.dart';
import 'package:qldazangjing/core/vertical/vertical_models.dart';
import 'package:qldazangjing/core/vertical/vertical_paginator.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';

/// 竖排 S4——验收 C1（网格几何公式）/ C4（分页完整性 property）/
/// C5（blockIndex 锚定）。
void main() {
  setUp(VerticalPagination.clearCache);

  group('C1 网格几何', () {
    test('标准参数全公式精确值', () {
      final g = VerticalGridSpec.fit(
        contentSize: const Size(350, 700),
        fontSize: 20,
        lineHeight: 1.75,
        letterSpacingEm: 0,
      );
      expect(g.cellW, 20);
      expect(g.cellH, 20);
      expect(g.colPitch, 35);
      expect(g.gap, 15);
      expect(g.charsPerCol, 35);
      expect(g.colsPerPage, 10); // floor((350+15)/35)
      expect(g.gridW, 335); // 10×35−15
      expect(g.leftInset, 7.5);
      expect(g.degraded, isFalse);
      // 列 x 严格等差（公差 colPitch），i=0 最右。
      expect(g.colX(0), 322.5); // 7.5+335−20
      expect(g.colX(9), 7.5);
      for (var i = 1; i < 10; i++) {
        expect(g.colX(i - 1) - g.colX(i), moreOrLessEquals(35));
      }
      // 行 y 严格等差（公差 cellH）。
      expect(g.cellY(3), 60);
      expect(g.gridBottom, 700);
      // 乌丝栏在列隙 0.62 处。
      expect(g.ruleX(1), g.colX(1) + 20 + 15 * 0.62);
    });

    test('字距增大格高、行距钳制下限', () {
      final g = VerticalGridSpec.fit(
        contentSize: const Size(350, 700),
        fontSize: 20,
        lineHeight: 1.0, // 低于下限 1.35 → 钳制
        letterSpacingEm: 0.1,
      );
      expect(g.cellH, moreOrLessEquals(22));
      expect(g.colPitch, moreOrLessEquals(20 * 1.35));
    });

    test('A1 兜底：字号钳制到恰容 1 格 1 列', () {
      final g = VerticalGridSpec.fit(
        contentSize: const Size(30, 15),
        fontSize: 40,
        lineHeight: 1.75,
        letterSpacingEm: 0,
      );
      expect(g.degraded, isTrue);
      expect(g.fontSize, 15); // min(15/1, 30)
      expect(g.charsPerCol, greaterThanOrEqualTo(1));
      expect(g.colsPerPage, greaterThanOrEqualTo(1));
    });
  });

  const key = VerticalPaginationKey(
    bookId: 't',
    contentSize: Size(350, 700), // 35 格 × 10 列
    fontFamily: '',
    fontSize: 20,
    lineHeight: 1.75,
    letterSpacingEm: 0,
    isSimplified: true,
    baiwen: false,
    textScaleFactor: 1,
  );

  BookData bookOf(List<JuanBlock> blocks,
          {String title = '测试经', String author = '某某译', BookMeta? meta}) =>
      BookData(
        meta: meta ??
            BookMeta(id: 't', bu: '', title: title, author: author),
        blocks: blocks,
      );

  String identity(String s) => s;

  VerticalPaginationResult run(BookData book,
          {VerticalPaginationKey k = key}) =>
      VerticalPagination.run(key: k, book: book, display: identity);

  group('C4 分页完整性', () {
    test('property：页内正文 token 拼接 == 输入流（无丢字无重字）', () {
      final book = bookOf([
        const JuanBlock(id: 'b0', type: JuanBlockType.bt, paragraphs: ['卷第一']),
        const JuanBlock(
            id: 'b1', type: JuanBlockType.bm, paragraphs: ['缘起品第一']),
        JuanBlock(id: 'b2', type: JuanBlockType.p, paragraphs: [
          '如是我闻：一时，薄伽梵住王舍城鹫峰山顶，与大苾刍众千二百五十人俱。' * 8,
          '诸行无常，是生灭法。生灭灭已，寂灭为乐。',
          '复有五百苾刍尼众，皆阿罗汉。',
        ]),
      ]);
      final stream =
          buildTokenStream(book: book, display: identity, baiwen: false);
      final streamChars =
          stream.expand((p) => p.tokens).map((t) => t.char).join();

      final result = run(book);
      final pageChars = result.pages
          .expand((p) => p.columns)
          .where((c) =>
              c.role == VColumnRole.bt ||
              c.role == VColumnRole.bm ||
              c.role == VColumnRole.body)
          .expand((c) => c.tokens)
          .map((t) => t.char)
          .join();
      expect(pageChars, streamChars);
    });

    test('列容量恒不超限；散文短段连排进同一列（D5）', () {
      final book = bookOf(const [
        JuanBlock(
            id: 'b',
            type: JuanBlockType.p,
            paragraphs: ['甲乙。', '丙丁。', '戊己。']),
      ]);
      final result = run(book);
      for (final page in result.pages) {
        for (final c in page.columns) {
          expect(c.tokens.length + c.indent,
              lessThanOrEqualTo(result.grid.charsPerCol));
        }
      }
      final bodyCols = result.pages
          .expand((p) => p.columns)
          .where((c) => c.role == VColumnRole.body)
          .toList();
      expect(bodyCols, hasLength(1), reason: '三个短段应连排同一列，不各起一列');
      expect(bodyCols.single.tokens.map((t) => t.char).join(), '甲乙丙丁戊己');
    });

    test('按联编码的偈颂区段合并折列（地藏经形态）', () {
      // 3 段 × 2 句七言 = 6 句归并;35 格列 7 言:k=(35+1)÷8=4 句/列
      // → 列 [28, 14] tokens,而非每段各自成列。
      final book = bookOf(const [
        JuanBlock(id: 'b', type: JuanBlockType.p, paragraphs: [
          '吾观地藏威神力，恒河沙劫说难尽，',
          '见闻瞻礼一念间，利益人天无量事。',
          '若男若女若龙神，报尽应当堕恶道。',
        ]),
      ]);
      final verseCols = run(book)
          .pages
          .expand((p) => p.columns)
          .where((c) => c.role == VColumnRole.body)
          .toList();
      expect(verseCols.map((c) => c.tokens.length).toList(), [28, 14],
          reason: '相邻同 n 联合并为一个区段折列');
      for (final c in verseCols) {
        expect(c.verseClauseLen, 7);
      }
    });

    test('偈颂三明治：前后散文断列，偈颂独立按句折列（D5 唯一小断）', () {
      final book = bookOf(const [
        JuanBlock(id: 'b', type: JuanBlockType.p, paragraphs: [
          '尔时世尊告曰。',
          '诸法从本来，常自寂灭相。佛子行道已，来世得作佛。',
          '闻者皆大欢喜。',
        ]),
      ]);
      final bodyCols = run(book)
          .pages
          .expand((p) => p.columns)
          .where((c) => c.role == VColumnRole.body)
          .toList();
      expect(bodyCols, hasLength(3), reason: '散文|偈颂|散文 各自成列');
      expect(bodyCols[0].tokens.map((t) => t.char).join(), '尔时世尊告曰');
      expect(bodyCols[1].tokens.length % 5, 0, reason: '偈颂列按句折列');
      expect(bodyCols[2].tokens.map((t) => t.char).join(), '闻者皆大欢喜');
    });

    test('跨块散文连排：后块始于列中段，pageForBlock 仍精确（逐 token 记录）', () {
      final book = bookOf([
        JuanBlock(id: 'b0', type: JuanBlockType.p, paragraphs: ['阿' * 400]),
        JuanBlock(id: 'b1', type: JuanBlockType.p, paragraphs: ['弥' * 100]),
      ]);
      final result = run(book);
      // 卷首题署 2 列 + 连排正文：b1 首 token 在正文第 400~/35=11 列中段，
      // 全局第 13 列 → 第 2 页（10 列/页）。
      final joined = result.pages
          .expand((p) => p.columns)
          .where((c) => c.role == VColumnRole.body)
          .expand((c) => c.tokens)
          .map((t) => t.char)
          .join();
      expect(joined, '阿' * 400 + '弥' * 100, reason: '跨块连排无缝续排');
      expect(result.pageForBlock(1), 1,
          reason: '块始于列中段时锚定仍指其首 token 所在页');
    });

    test('偈颂按句折列且句间空一格（D6）：k 句占 k×n+(k−1) 格', () {
      // 35 格/列，五言：k = (35+1)÷(5+1) = 6 句/列（占满 6×5+5=35 格）。
      final verse = '诸法从本来，常自寂灭相。佛子行道已，来世得作佛。' * 5; // 20 句
      final book = bookOf([
        JuanBlock(id: 'b', type: JuanBlockType.p, paragraphs: [verse]),
      ]);
      final result = run(book);
      final verseCols = result.pages
          .expand((p) => p.columns)
          .where((c) => c.role == VColumnRole.body)
          .toList();
      expect(verseCols, isNotEmpty);
      for (final c in verseCols) {
        expect(c.verseClauseLen, 5);
        expect(c.tokens.length % 5, 0, reason: 'A6：句子绝不跨列');
        final clauses = c.tokens.length ~/ 5;
        expect(c.tokens.length + clauses - 1,
            lessThanOrEqualTo(result.grid.charsPerCol),
            reason: '含句间空格后不得超列容量');
      }
      // 20 句 → 6+6+6+2 句/列。
      expect(verseCols.map((c) => c.tokens.length).toList(), [30, 30, 30, 10]);
    });

    test('卷首题署：书名列顶格、作者列下沉对齐列底', () {
      final result = run(bookOf(const []));
      final first = result.pages.first;
      expect(first.columns[0].role, VColumnRole.title);
      expect(first.columns[0].indent, 0);
      final author = first.columns[1];
      expect(author.role, VColumnRole.author);
      expect(author.indent + author.tokens.length, result.grid.charsPerCol,
          reason: '下沉至列底（仿卷端题署）');
    });

    test('bm 品名低一格；bt 顶格', () {
      final book = bookOf(const [
        JuanBlock(id: 'b0', type: JuanBlockType.bt, paragraphs: ['卷第一']),
        JuanBlock(id: 'b1', type: JuanBlockType.bm, paragraphs: ['缘起品']),
      ]);
      final cols = run(book).pages.expand((p) => p.columns);
      expect(cols.firstWhere((c) => c.role == VColumnRole.bt).indent, 0);
      expect(cols.firstWhere((c) => c.role == VColumnRole.bm).indent, 1);
    });

    test('插图独占页，前后文字不与之同页', () {
      final book = bookOf(const [
        JuanBlock(id: 'b', type: JuanBlockType.p, paragraphs: [
          '前文若干字。<img src="/images/x.png">后文若干字。',
        ]),
      ]);
      final result = run(book);
      final imagePages =
          result.pages.where((p) => p.imageUrl != null).toList();
      expect(imagePages.length, 1);
      expect(imagePages.single.columns, isEmpty);
    });

    test('卷尾 nav 页仅在有前后部时出现', () {
      final without = run(bookOf(const []));
      expect(without.pages.any((p) => p.isNavPage), isFalse);

      final withNav = run(
        bookOf(const [],
            meta: const BookMeta(
                id: 't2',
                bu: '',
                title: '测',
                author: '',
                nextBuId: 'n1',
                nextBuName: '下一部')),
        k: const VerticalPaginationKey(
          bookId: 't2',
          contentSize: Size(350, 700),
          fontFamily: '',
          fontSize: 20,
          lineHeight: 1.75,
          letterSpacingEm: 0,
          isSimplified: true,
          baiwen: false,
          textScaleFactor: 1,
        ),
      );
      expect(withNav.pages.last.isNavPage, isTrue);
    });

    test('空书兜底至少一页', () {
      final result = run(bookOf(const [], title: '', author: ''));
      expect(result.pages, hasLength(1));
    });
  });

  group('C5 进度锚定', () {
    test('pageForBlock 单调不减；blockForPage 往返一致', () {
      final book = bookOf([
        const JuanBlock(id: 'b0', type: JuanBlockType.bt, paragraphs: ['卷第一']),
        JuanBlock(
            id: 'b1',
            type: JuanBlockType.p,
            paragraphs: ['如是我闻，一时佛在。' * 60]),
        const JuanBlock(id: 'b2', type: JuanBlockType.bm, paragraphs: ['品第二']),
        JuanBlock(
            id: 'b3',
            type: JuanBlockType.p,
            paragraphs: ['复有五百苾刍尼众。' * 60]),
      ]);
      final result = run(book);
      expect(result.pages.length, greaterThan(2), reason: '样本须跨多页');

      var prev = 0;
      for (var b = 0; b < book.blocks.length; b++) {
        final page = result.pageForBlock(b);
        expect(page, greaterThanOrEqualTo(prev));
        prev = page;
      }
      // 往返：块 b 首现页的锚块 ≤ b。
      for (var b = 0; b < book.blocks.length; b++) {
        expect(result.blockForPage(result.pageForBlock(b)),
            lessThanOrEqualTo(b));
      }
      // 越界钳制不崩。
      expect(result.pageForBlock(-5), 0);
      expect(result.pageForBlock(999), lessThan(result.pages.length));
    });

    test('缓存命中返回同一实例；不同键重排', () {
      final book = bookOf(const []);
      final a = run(book);
      final b = run(book);
      expect(identical(a, b), isTrue);
      final c = run(book,
          k: const VerticalPaginationKey(
            bookId: 't',
            contentSize: Size(350, 700),
            fontFamily: '',
            fontSize: 22, // 字号变化
            lineHeight: 1.75,
            letterSpacingEm: 0,
            isSimplified: true,
            baiwen: false,
            textScaleFactor: 1,
          ));
      expect(identical(a, c), isFalse);
    });
  });
}
