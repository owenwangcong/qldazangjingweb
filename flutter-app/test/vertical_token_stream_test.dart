import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/pagination/paragraph_text.dart';
import 'package:qldazangjing/core/vertical/punctuation.dart';
import 'package:qldazangjing/core/vertical/token_stream.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';

/// 竖排 S2（字符流层）——验收清单 C2：rune 安全、标点归属、白文过滤、
/// 图片段切分、简繁转换次序与按段应用。
void main() {
  List<GridTokenView> flat(List<dynamic> paras) => [
        for (final p in paras)
          for (final t in (p as dynamic).tokens)
            (char: t.char as String, punct: t.trailingPunct as String),
      ];

  BookData bookOf(List<JuanBlock> blocks) => BookData(
        meta: const BookMeta(id: 't', bu: '', title: '测', author: ''),
        blocks: blocks,
      );

  String identity(String s) => s;

  group('tokenizeText 标点归属', () {
    test('句读附着前一字，主体字数不变', () {
      final tokens = tokenizeText('如是我闻：一时，薄伽梵。',
          blockIndex: 0, paragraphIndex: 0, baiwen: false);
      expect(tokens.map((t) => t.char).join(), '如是我闻一时薄伽梵');
      expect(tokens[3].trailingPunct, '：');
      expect(tokens[5].trailingPunct, '，');
      expect(tokens.last.trailingPunct, '。');
    });

    test('连续标点堆叠到同一字，数据全留', () {
      final tokens = tokenizeText('度一切苦厄。」',
          blockIndex: 0, paragraphIndex: 0, baiwen: false);
      expect(tokens.last.char, '厄');
      expect(tokens.last.trailingPunct, '。」');
    });

    test('段首前置符舍弃；段中前置符并入前一字', () {
      final atStart = tokenizeText('「如是',
          blockIndex: 0, paragraphIndex: 0, baiwen: false);
      expect(atStart.map((t) => t.char).join(), '如是');
      expect(atStart.first.trailingPunct, '');

      final midText = tokenizeText('佛言「善哉」',
          blockIndex: 0, paragraphIndex: 0, baiwen: false);
      expect(midText.map((t) => t.char).join(), '佛言善哉');
      expect(midText[1].trailingPunct, '「');
      expect(midText.last.trailingPunct, '」');
    });

    test('半角标点同样悬浮', () {
      final tokens = tokenizeText('note: ok?',
          blockIndex: 0, paragraphIndex: 0, baiwen: false);
      expect(tokens.map((t) => t.char).join(), 'noteok');
      expect(tokens[3].trailingPunct, ':');
      expect(tokens.last.trailingPunct, '?');
    });

    test('非悬浮类标点（间隔号）独立占格', () {
      final tokens = tokenizeText('摩诃·般若',
          blockIndex: 0, paragraphIndex: 0, baiwen: false);
      expect(tokens.map((t) => t.char).join(), '摩诃·般若');
      expect(tokens[2].char, '·');
      expect(tokens[2].trailingPunct, '');
    });
  });

  group('tokenizeText 字符与空白', () {
    test('扩展区汉字按 rune 切分不断裂', () {
      final tokens = tokenizeText('𠀋一𠆢',
          blockIndex: 0, paragraphIndex: 0, baiwen: false);
      expect(tokens.length, 3);
      expect(tokens[0].char, '𠀋');
      expect(tokens[2].char, '𠆢');
    });

    test('空白（半角/全角/换行）一律剥除', () {
      final tokens = tokenizeText('如 是　我\n闻',
          blockIndex: 0, paragraphIndex: 0, baiwen: false);
      expect(tokens.map((t) => t.char).join(), '如是我闻');
    });
  });

  group('白文模式', () {
    test('剥除全部中英文标点与符号，字母与〇保留', () {
      final tokens = tokenizeText('如是，我闻。ok!?~·〇「」…',
          blockIndex: 0, paragraphIndex: 0, baiwen: true);
      expect(tokens.map((t) => t.char).join(), '如是我闻ok〇');
      expect(tokens.every((t) => t.trailingPunct.isEmpty), isTrue);
    });

    test('全流零标点（C2 全量扫描断言）', () {
      final book = bookOf(const [
        JuanBlock(id: 'b1', type: JuanBlockType.bt, paragraphs: ['般若经·卷一']),
        JuanBlock(id: 'b2', type: JuanBlockType.p, paragraphs: [
          '如是我闻：一时，佛在。',
          '「善哉！善哉！」…～',
        ]),
      ]);
      final paras =
          buildTokenStream(book: book, display: identity, baiwen: true);
      for (final t in flat(paras)) {
        expect(anyPunctOrSymbol.hasMatch(t.char), isFalse,
            reason: '白文流含标点: ${t.char}');
        expect(t.punct, isEmpty);
      }
    });
  });

  group('buildTokenStream 段落与块规则', () {
    test('空段与（白文后）全标点段不产出空列单元', () {
      final book = bookOf(const [
        JuanBlock(id: 'b', type: JuanBlockType.p, paragraphs: ['   ', '。。。']),
      ]);
      expect(
          buildTokenStream(book: book, display: identity, baiwen: true), isEmpty);
      // 句读模式：全段皆段首悬浮符、无所附 → 同样整段舍弃。
      expect(buildTokenStream(book: book, display: identity, baiwen: false),
          isEmpty);
    });

    test('bt/bm 标题块合并单段（镜像横排 _placeBlockTitle）', () {
      final book = bookOf(const [
        JuanBlock(
            id: 'b',
            type: JuanBlockType.bt,
            paragraphs: ['大般若经', '卷第一 ']),
      ]);
      final paras =
          buildTokenStream(book: book, display: identity, baiwen: false);
      expect(paras.length, 1);
      expect(paras.single.blockType, JuanBlockType.bt);
      expect(paras.single.tokens.map((t) => t.char).join(), '大般若经卷第一');
    });

    test('段内 <img> 切分为 文本|图片|文本 三段，同段落索引', () {
      final book = bookOf(const [
        JuanBlock(id: 'b', type: JuanBlockType.p, paragraphs: [
          '前文<img src="/images/x.png">后文',
        ]),
      ]);
      final paras =
          buildTokenStream(book: book, display: identity, baiwen: false);
      expect(paras.length, 3);
      expect(paras[0].tokens.map((t) => t.char).join(), '前文');
      expect(paras[1].isImage, isTrue);
      expect(paras[1].imageUrl, resolveImageUrl('/images/x.png'));
      expect(paras[2].tokens.map((t) => t.char).join(), '后文');
      expect(paras.map((p) => p.paragraphIndex).toSet(), {0});
      expect(paras.map((p) => p.blockIndex).toSet(), {0});
    });

    test('简繁转换按文本段应用：正文转换、图片 URL 不受染指', () {
      String fakeConvert(String s) => s.replaceAll('经', '經');
      final book = bookOf(const [
        JuanBlock(id: 'b', type: JuanBlockType.p, paragraphs: [
          '心经<img src="/images/经.png">尾经',
        ]),
      ]);
      final paras =
          buildTokenStream(book: book, display: fakeConvert, baiwen: false);
      expect(paras[0].tokens.map((t) => t.char).join(), '心經');
      expect(paras[2].tokens.map((t) => t.char).join(), '尾經');
      expect(paras[1].imageUrl, contains('经.png'),
          reason: '转换必须按段进行，URL 保持原文');
    });

    test('弯引号在转换前剥除（cleanParagraph 准源次序）', () {
      final book = bookOf(const [
        JuanBlock(id: 'b', type: JuanBlockType.p, paragraphs: ['“如是”']),
      ]);
      final paras =
          buildTokenStream(book: book, display: identity, baiwen: false);
      expect(paras.single.tokens.map((t) => t.char).join(), '如是');
      expect(paras.single.tokens.every((t) => t.trailingPunct.isEmpty), isTrue);
    });

    test('单弯引号映射为竖排直角引号 ﹁﹂，独立占格、白文剥除（FQ2）', () {
      expect(mapVerticalQuotes('曰‘如是’云'), '曰﹁如是﹂云');

      final book = bookOf(const [
        JuanBlock(id: 'b', type: JuanBlockType.p, paragraphs: ['佛言：‘善哉。’']),
      ]);
      final paras =
          buildTokenStream(book: book, display: identity, baiwen: false);
      // ﹁﹂ 不在悬浮表 → 独立占格；全角冒号/句号仍悬浮附着前一字。
      expect(paras.single.tokens.map((t) => t.char).join(), '佛言﹁善哉﹂');
      expect(paras.single.tokens[1].trailingPunct, '：');
      expect(paras.single.tokens[4].trailingPunct, '。');

      final baiwen =
          buildTokenStream(book: book, display: identity, baiwen: true);
      expect(baiwen.single.tokens.map((t) => t.char).join(), '佛言善哉');
    });

    test('blockIndex/paragraphIndex 锚定正确', () {
      final book = bookOf(const [
        JuanBlock(id: 'b0', type: JuanBlockType.bt, paragraphs: ['题']),
        JuanBlock(id: 'b1', type: JuanBlockType.p, paragraphs: ['甲。', '乙。']),
      ]);
      final paras =
          buildTokenStream(book: book, display: identity, baiwen: false);
      expect(paras.length, 3);
      expect((paras[0].blockIndex, paras[0].paragraphIndex), (0, 0));
      expect((paras[1].blockIndex, paras[1].paragraphIndex), (1, 0));
      expect((paras[2].blockIndex, paras[2].paragraphIndex), (1, 1));
    });
  });
}

typedef GridTokenView = ({String char, String punct});
