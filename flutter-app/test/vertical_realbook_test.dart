import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/vertical/token_stream.dart';
import 'package:qldazangjing/core/vertical/vertical_models.dart';
import 'package:qldazangjing/core/vertical/vertical_paginator.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';

import 'dart:ui';

/// 真书冒烟：内置资产 0085-01（普贤行愿品）全管线解析+竖排分页。
/// 2026-07-20 真机白屏排查用例，保留作数据回归。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(VerticalPagination.clearCache);

  test('0085-01 解析并竖排分页产出非空页面', () {
    final raw = gzip.decode(
        File('assets/books/0085-01.json.gz').readAsBytesSync());
    final json = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
    final meta = BookMeta.fromJson(json['meta'] as Map<String, dynamic>);
    final blocks = (json['juans'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(JuanBlock.fromJson)
        .whereType<JuanBlock>()
        .toList();
    expect(blocks, isNotEmpty, reason: '30 个 juan 应全部解析');
    // ignore: avoid_print
    print('[0085-01] blocks=${blocks.length} '
        'chars=${blocks.expand((b) => b.paragraphs).join().length}');

    final result = VerticalPagination.run(
      key: const VerticalPaginationKey(
        bookId: '0085-01',
        contentSize: Size(640, 1257),
        fontFamily: '',
        fontSize: 20,
        lineHeight: 1.75,
        letterSpacingEm: 0,
        isSimplified: true,
        baiwen: false,
        textScaleFactor: 1,
      ),
      book: BookData(meta: meta, blocks: blocks),
      display: (s) => s,
    );
    // ignore: avoid_print
    print('[0085-01] pages=${result.pages.length} '
        'cols(p0)=${result.pages.first.columns.length}');
    expect(result.pages.length, greaterThan(10));
    expect(result.pages.first.columns, isNotEmpty);
  });

  test('0998(地藏经)按联编码的偈颂被区段归并检测(漏检修复回归)', () {
    final raw =
        gzip.decode(File('assets/books/0998.json.gz').readAsBytesSync());
    final json = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
    final blocks = (json['juans'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(JuanBlock.fromJson)
        .whereType<JuanBlock>()
        .toList();
    final paras = buildTokenStream(
        book: BookData(
            meta: BookMeta.fromJson(json['meta'] as Map<String, dynamic>),
            blocks: blocks),
        display: (s) => s,
        baiwen: false);
    final target = paras.where((p) =>
        p.tokens.isNotEmpty &&
        p.tokens.map((t) => t.char).join().startsWith('吾观地藏威神力'));
    expect(target, isNotEmpty);
    expect(target.first.verseClauseLen, 7,
        reason: '十二品「吾观地藏威神力」七言偈应被检测');
    final verseParas = paras.where((p) => p.verseClauseLen != null).length;
    // ignore: avoid_print
    print('[0998] 偈颂段数=$verseParas / 总段数=${paras.length}');
    expect(verseParas, greaterThan(10), reason: '地藏经偈颂众多,不应大面积漏检');
  });
}
