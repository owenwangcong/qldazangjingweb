import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/utils/chinese_converter.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChineseConverter', () {
    late ChineseConverter converter;

    setUpAll(() async {
      converter = await ChineseConverter.load();
    });

    test('converts simplified to traditional', () {
      expect(converter.toTraditional('观自在菩萨'), '觀自在菩薩');
      expect(converter.toTraditional('般若波罗蜜多心经'), '般若波羅蜜多心經');
    });

    test('normalizes traditional queries to simplified', () {
      expect(converter.normalizeQuery('觀自在菩薩'), '观自在菩萨');
      expect(converter.normalizeQuery('金剛般若波羅蜜經'), '金刚般若波罗蜜经');
    });

    test('display passes simplified text through unchanged', () {
      const source = '如是我闻';
      expect(converter.display(source, simplified: true), source);
      expect(converter.display(source, simplified: false), '如是我聞');
    });
  });

  group('Book entities', () {
    test('parses book meta including prev/next navigation', () {
      final meta = BookMeta.fromJson({
        'id': '0001-01',
        'Bu': '大乘般若部·第0001部',
        'title': '大般若波罗蜜多经（第一卷～第十卷）',
        'Arthur': '唐三藏法师玄奘奉诏译',
        'last_bu': {'id': '0000', 'name': '上一部'},
        'next_bu': {'id': '0001-02', 'name': '下一部'},
      });
      expect(meta.id, '0001-01');
      expect(meta.author, contains('玄奘'));
      expect(meta.lastBuId, '0000');
      expect(meta.nextBuId, '0001-02');
    });

    test('parses juan blocks and skips unknown types', () {
      final bt = JuanBlock.fromJson({
        'id': 'j1',
        'type': 'bt',
        'content': ['大般若波罗蜜多经卷第一'],
      });
      expect(bt, isNotNull);
      expect(bt!.type, JuanBlockType.bt);

      final p = JuanBlock.fromJson({
        'id': 'p-0',
        'type': 'p',
        'content': ['如是我闻：一时，薄伽梵住王舍城鹫峰山顶。', '复有五百苾刍尼众。'],
      });
      expect(p!.paragraphs.length, 2);

      expect(JuanBlock.fromJson({'id': 'x', 'type': 'weird'}), isNull);
    });
  });
}
