import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/pagination/page_models.dart';
import 'package:qldazangjing/core/pagination/paragraph_text.dart';
import 'package:qldazangjing/core/pagination/sutra_paginator.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';

/// SutraPaginator 单元测试。
///
/// 测试引擎的 FlutterTest 字体（Ahem 系）把所有字形渲染成 fontSize 见方：
/// fontSize 10 / lineHeight 1.0 / 宽 105 → 每行恰 10 字、行高 10——
/// 全部断言确定性成立。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String identity(String s) => s;

  PaginationKey makeKey({
    double width = 105,
    double height = 101, // 可用高 = height − 1（亚像素余量）= 100 = 10 行
    double fontSize = 10,
    double paragraphSpacing = 0,
    String bookId = 'book-1',
  }) =>
      PaginationKey(
        bookId: bookId,
        contentSize: Size(width, height),
        fontFamily: '',
        fontSize: fontSize,
        lineHeight: 1.0,
        letterSpacingEm: 0,
        paragraphSpacing: paragraphSpacing,
        isSimplified: true,
        textScaleFactor: 1.0,
      );

  TextStyle makeStyle(PaginationKey key) => TextStyle(
        fontSize: key.fontSize,
        height: key.lineHeight,
        letterSpacing: 0,
      );

  // 测试 meta：标题/作者各 1 字 → 页眉高 36+10+6+10+16+24 = 102，
  // 在 101 高的小页面上独占第 0 页（强放裁切），后续断言只看正文页。
  BookData makeBook(List<JuanBlock> blocks) => BookData(
        meta: const BookMeta(id: 'book-1', bu: '', title: '题', author: '者'),
        blocks: blocks,
      );

  JuanBlock p(String id, List<String> paragraphs) =>
      JuanBlock(id: id, type: JuanBlockType.p, paragraphs: paragraphs);

  Future<PaginationResult> paginate(SutraPaginator paginator) async {
    final completer = Completer<void>();
    paginator.addListener(() {
      if (paginator.result.done && !completer.isCompleted) {
        completer.complete();
      }
    });
    paginator.start();
    await completer.future.timeout(const Duration(seconds: 30));
    return paginator.result;
  }

  Future<PaginationResult> run(BookData book, PaginationKey key) {
    final paginator = SutraPaginator(
      key: key,
      book: book,
      display: identity,
      baseStyle: makeStyle(key),
    );
    return paginate(paginator);
  }

  setUp(SutraPaginator.clearCache);

  test('切片覆盖不变量：各段切片拼接 == 原文，无缝无叠，引用同一字符串', () async {
    final book = makeBook([
      p('b0', ['阿' * 95]),
      p('b1', ['阿' * 230]),
      p('b2', ['阿' * 40, '阿' * 15]),
    ]);
    final result = await run(book, makeKey(paragraphSpacing: 7));

    expect(result.done, isTrue);
    // 按 (block, paragraph) 聚合文本切片。
    final byPara = <(int, int), List<PageSlice>>{};
    for (final page in result.pages) {
      for (final s in page.slices) {
        if (s.kind == PageSliceKind.text) {
          byPara.putIfAbsent((s.blockIndex, s.paragraphIndex), () => []).add(s);
        }
      }
    }
    expect(byPara.keys, hasLength(4));
    byPara.forEach((para, slices) {
      expect(slices.first.charStart, 0);
      for (var i = 1; i < slices.length; i++) {
        expect(slices[i].charStart, slices[i - 1].charEnd,
            reason: '段 $para 切片必须无缝衔接');
        expect(identical(slices[i].text, slices.first.text), isTrue,
            reason: '同段切片必须引用同一字符串对象');
      }
      expect(slices.last.charEnd, slices.first.text!.length,
          reason: '段 $para 切片必须覆盖到结尾');
    });
  });

  test('每页装载高 ≤ 可用页高；页尾丢段距', () async {
    final book = makeBook([
      for (var i = 0; i < 8; i++) p('b$i', ['阿' * 30]),
    ]);
    final result = await run(book, makeKey(paragraphSpacing: 8));

    for (final page in result.pages) {
      // 只验证纯文本页（页眉/nav 页的高度公式另测）。
      if (page.slices.any((s) => s.kind != PageSliceKind.text)) continue;
      var height = 0.0;
      for (final s in page.slices) {
        final lines = ((s.charEnd - s.charStart) + 9) ~/ 10;
        height += lines * 10 + s.paddingAfter;
      }
      expect(height, lessThanOrEqualTo(100),
          reason: '纯文本页装载高不得超过可用页高');
    }
    // 段距只可能是 0（页尾丢弃）或完整 8。
    for (final page in result.pages) {
      for (final s in page.slices) {
        expect(s.paddingAfter == 0 || s.paddingAfter == 8, isTrue);
      }
    }
  });

  test('长段跨 ≥3 页，且在行边界（10 字）切分', () async {
    final book = makeBook([
      p('b0', ['阿' * 350]),
    ]);
    final result = await run(book, makeKey());

    final pagesWithPara = <int>{};
    for (var i = 0; i < result.pages.length; i++) {
      for (final s in result.pages[i].slices) {
        if (s.kind == PageSliceKind.text && s.blockIndex == 0) {
          pagesWithPara.add(i);
          if (s.charEnd != 350) {
            expect(s.charEnd % 10, 0, reason: '跨页切点必须落在行边界');
          }
        }
      }
    }
    expect(pagesWithPara.length, greaterThanOrEqualTo(3));
  });

  test('blockIndex ↔ 页码往返映射单调一致', () async {
    final book = makeBook([
      for (var i = 0; i < 5; i++) p('b$i', ['阿' * 100]),
    ]);
    final result = await run(book, makeKey());

    int? lastPage;
    for (var b = 0; b < 5; b++) {
      final page = result.pageForBlock(b);
      expect(page, isNotNull);
      if (lastPage != null) {
        expect(page!, greaterThanOrEqualTo(lastPage));
      }
      expect(result.blockForPage(page!), lessThanOrEqualTo(b),
          reason: '页首块不得晚于映射来源块');
      lastPage = page;
    }
  });

  test('<img> 段独占一页，前后文本正常流动', () async {
    final book = makeBook([
      p('b0', ['阿阿阿<img src="/pic.png">阿阿']),
    ]);
    final result = await run(book, makeKey());

    final imagePages = result.pages
        .where((page) => page.slices.any((s) => s.kind == PageSliceKind.image))
        .toList();
    expect(imagePages, hasLength(1));
    expect(imagePages.single.slices, hasLength(1),
        reason: '插图独占一页');
    expect(imagePages.single.slices.single.imageUrl, endsWith('/pic.png'));
    // 前 3 字与后 2 字仍按文本切片输出。
    final textChars = result.pages
        .expand((page) => page.slices)
        .where((s) => s.kind == PageSliceKind.text)
        .fold<int>(0, (sum, s) => sum + (s.charEnd - s.charStart));
    expect(textChars, 5);
  });

  test('空书 → 单页 [页眉, nav]；映射安全', () async {
    final book = makeBook(const []);
    final result = await run(book, makeKey(height: 300));

    expect(result.done, isTrue);
    expect(result.pages, hasLength(1));
    expect(result.pages.single.slices.map((s) => s.kind),
        [PageSliceKind.header, PageSliceKind.nav]);
    expect(result.pageForBlock(0), 0);
    expect(result.blockForPage(0), 0);
  });

  test('时间片：大书多回合增长，pages 只追加', () async {
    final book = makeBook([
      for (var i = 0; i < 3000; i++) p('b$i', ['阿' * 50]),
    ]);
    final key = makeKey(bookId: 'big-book');
    final paginator = SutraPaginator(
      key: key,
      book: book,
      display: identity,
      baseStyle: makeStyle(key),
    );
    var sawPartial = false;
    var lastCount = 0;
    paginator.addListener(() {
      if (!paginator.result.done && paginator.result.pages.isNotEmpty) {
        sawPartial = true;
      }
      expect(paginator.result.pages.length, greaterThanOrEqualTo(lastCount),
          reason: 'pages 只追加，索引不漂移');
      lastCount = paginator.result.pages.length;
    });
    final result = await paginate(paginator);
    expect(result.done, isTrue);
    expect(sawPartial, isTrue,
        reason: '3000 块的书必然超出单回合 8ms 预算，应有中间通知');
  });

  test('dispose 取消进行中的排版', () async {
    final book = makeBook([
      for (var i = 0; i < 3000; i++) p('b$i', ['阿' * 50]),
    ]);
    final key = makeKey(bookId: 'cancel-book');
    final paginator = SutraPaginator(
      key: key,
      book: book,
      display: identity,
      baseStyle: makeStyle(key),
    );
    final firstTick = Completer<void>();
    paginator.addListener(() {
      if (!firstTick.isCompleted) firstTick.complete();
    });
    paginator.start();
    await firstTick.future.timeout(const Duration(seconds: 10));
    paginator.dispose();
    final countAtDispose = paginator.result.pages.length;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(paginator.result.done, isFalse);
    expect(paginator.result.pages.length, countAtDispose,
        reason: 'dispose 后不得继续装页');
  });

  test('完成结果入缓存；key 任一分量不同即 miss', () async {
    final book = makeBook([
      p('b0', ['阿' * 30]),
    ]);
    final key = makeKey();
    final result = await run(book, key);

    expect(identical(SutraPaginator.cached(makeKey()), result), isTrue);
    expect(SutraPaginator.cached(makeKey(fontSize: 11)), isNull);
    expect(SutraPaginator.cached(makeKey(width: 200)), isNull);
    expect(SutraPaginator.cached(makeKey(bookId: 'other')), isNull);
  });

  test('段落预处理：剥弯引号、<img> 切分与 URL 补全', () {
    expect(cleanParagraph('“阿”弥“陀”'), '阿弥陀');
    final segments =
        splitParagraphSegments('前文<img src="/a.png">后文');
    expect(segments, hasLength(3));
    expect(segments[0].text, '前文');
    expect(segments[1].imageUrl, endsWith('/a.png'));
    expect(segments[1].imageUrl, startsWith('http'));
    expect(segments[2].text, '后文');
    // 绝对 URL 原样保留。
    final absolute =
        splitParagraphSegments('<img src="https://x.com/b.png">');
    expect(absolute.single.imageUrl, 'https://x.com/b.png');
  });
}
