import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/vertical/vertical_models.dart';
import 'package:qldazangjing/core/vertical/vertical_paginator.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';

/// V1 两层化重构对拍（vertical-scroll-plan.md §2.1）：
/// 重构前先给真书翻页产物拍数字指纹（页数/每页列数序列摘要/锚定采样），
/// 重构后指纹必须逐位不变——列带层+页分组层不得改变翻页行为。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(VerticalPagination.clearCache);

  ({int pages, int cols, int colHash, int anchorHash, List<int> samples})
      digest(String bookId) {
    final raw = gzip
        .decode(File('assets/books/$bookId.json.gz').readAsBytesSync());
    final json = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
    final book = BookData(
      meta: BookMeta.fromJson(json['meta'] as Map<String, dynamic>),
      blocks: (json['juans'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(JuanBlock.fromJson)
          .whereType<JuanBlock>()
          .toList(),
    );
    final result = VerticalPagination.run(
      key: VerticalPaginationKey(
        bookId: 'digest-$bookId',
        contentSize: const Size(640, 1257),
        fontFamily: '',
        fontSize: 20,
        lineHeight: 1.75,
        letterSpacingEm: 0,
        isSimplified: true,
        baiwen: false,
        textScaleFactor: 1,
      ),
      book: book,
      display: (s) => s,
    );
    var cols = 0, colHash = 17, anchorHash = 17;
    for (final p in result.pages) {
      cols += p.columns.length;
      colHash = (colHash * 31 + p.columns.length) & 0x3fffffff;
      anchorHash = (anchorHash * 31 + p.firstBlockIndex) & 0x3fffffff;
      for (final c in p.columns) {
        colHash = (colHash * 7 + c.tokens.length + c.indent * 131) & 0x3fffffff;
      }
    }
    final samples = [
      for (var b = 0; b < book.blocks.length; b += 7)
        result.pageForBlock(b)
    ];
    return (
      pages: result.pages.length,
      cols: cols,
      colHash: colHash,
      anchorHash: anchorHash,
      samples: samples,
    );
  }

  test('0085-01 翻页产物指纹不变（重构前基准 2026-07-20）', () {
    final d = digest('0085-01');
    expect(d.pages, 63);
    expect(d.cols, 1099);
    expect(d.colHash, 747057561);
    expect(d.anchorHash, 957985439);
    expect(d.samples, [0, 11, 24, 43, 54]);
  });

  test('0998 翻页产物指纹不变（重构前基准 2026-07-20）', () {
    final d = digest('0998');
    expect(d.pages, 18);
    expect(d.cols, 303);
    expect(d.colHash, 297985313);
    expect(d.anchorHash, 622377286);
    expect(d.samples, [0, 3, 6, 9, 12, 15]);
  });

  test('派生一致性：页分组的列序列 == 列带中的列序列', () {
    final raw = gzip
        .decode(File('assets/books/0998.json.gz').readAsBytesSync());
    final json = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
    final result = VerticalPagination.run(
      key: const VerticalPaginationKey(
        bookId: 'derive-0998',
        contentSize: Size(640, 1257),
        fontFamily: '',
        fontSize: 20,
        lineHeight: 1.75,
        letterSpacingEm: 0,
        isSimplified: true,
        baiwen: false,
        textScaleFactor: 1,
      ),
      book: BookData(
        meta: BookMeta.fromJson(json['meta'] as Map<String, dynamic>),
        blocks: (json['juans'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(JuanBlock.fromJson)
            .whereType<JuanBlock>()
            .toList(),
      ),
      display: (s) => s,
    );
    final fromPages =
        result.pages.expand((p) => p.columns).toList(growable: false);
    final fromStrip = result.strip
        .whereType<StripColumn>()
        .map((s) => s.column)
        .toList(growable: false);
    expect(fromPages.length, fromStrip.length);
    for (var i = 0; i < fromPages.length; i++) {
      expect(identical(fromPages[i], fromStrip[i]), isTrue,
          reason: '页与列带必须共享同一列对象(零拷贝派生)');
    }
  });
}
