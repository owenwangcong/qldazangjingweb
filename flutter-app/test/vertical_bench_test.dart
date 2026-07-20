import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/vertical/vertical_paginator.dart';
import 'package:qldazangjing/core/vertical/vertical_models.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';

/// 竖排 S8——分页耗时基准（C11 一半：另一半是真机 timeline 采样）。
/// 方案 §11 预算：一卷（1~3 万字）<10ms（release）；此处 debug JIT 环境
/// 放宽到 250ms 作回归护栏，实测值打印到日志供追踪。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(VerticalPagination.clearCache);

  test('整卷 3 万字冷分页耗时（debug 护栏 250ms）', () {
    // 30,720 字符：散文+偈颂+密集标点混合,贴近真实卷帙。
    final prose = '如是我闻：一时，薄伽梵住王舍城鹫峰山顶，与大苾刍众千二百五十人俱。' * 400;
    final verse = '诸法从本来，常自寂灭相。佛子行道已，来世得作佛。' * 100;
    final book = BookData(
      meta: const BookMeta(id: 'bench', bu: '', title: '基准卷', author: '测'),
      blocks: [
        const JuanBlock(id: 'b0', type: JuanBlockType.bt, paragraphs: ['卷第一']),
        JuanBlock(id: 'b1', type: JuanBlockType.p, paragraphs: [prose]),
        JuanBlock(id: 'b2', type: JuanBlockType.p, paragraphs: [verse]),
        JuanBlock(id: 'b3', type: JuanBlockType.p, paragraphs: [prose]),
      ],
    );
    final charCount = (prose.length * 2 + verse.length);

    const key = VerticalPaginationKey(
      bookId: 'bench',
      contentSize: Size(640, 1257), // 平板实测内容区
      fontFamily: '',
      fontSize: 20,
      lineHeight: 1.75,
      letterSpacingEm: 0,
      isSimplified: true,
      baiwen: false,
      textScaleFactor: 1,
    );

    final sw = Stopwatch()..start();
    final result =
        VerticalPagination.run(key: key, book: book, display: (s) => s);
    sw.stop();

    // ignore: avoid_print
    print('[bench] $charCount 字符 → ${result.pages.length} 页,'
        '冷分页 ${sw.elapsedMicroseconds / 1000} ms (debug JIT)');
    expect(result.pages.length, greaterThan(20));
    expect(sw.elapsedMilliseconds, lessThan(250),
        reason: '算术分页出现量级退化');

    // 缓存命中应为零成本路径。
    final sw2 = Stopwatch()..start();
    VerticalPagination.run(key: key, book: book, display: (s) => s);
    sw2.stop();
    expect(sw2.elapsedMilliseconds, lessThan(5));
  });
}
