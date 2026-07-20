import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/vertical/token_stream.dart';
import 'package:qldazangjing/core/vertical/verse_detector.dart';
import 'package:qldazangjing/domain/entities/book_entities.dart';

/// 竖排 S3（偈颂检测）——验收清单 C3：真实偈颂命中且句长正确、
/// 散文不误判、从严判据的各拒斥路径、白文流下标注保留与撤销。
void main() {
  int? detect(String text) => detectVerseClauseLen(tokenizeText(text,
      blockIndex: 0, paragraphIndex: 0, baiwen: false));

  group('命中：真实偈颂语料', () {
    test('四言（诸行无常偈）', () {
      expect(detect('诸行无常，是生灭法。生灭灭已，寂灭为乐。'), 4);
    });

    test('五言（法华·诸法从本来）', () {
      expect(detect('诸法从本来，常自寂灭相。佛子行道已，来世得作佛。'), 5);
    });

    test('七言（七佛通戒偈体）', () {
      expect(detect('诸恶莫作众善行，自净其意离诸相。此是诸佛真实教，护持净戒莫放逸。'), 7);
    });

    test('悬浮引号不占格不计句长', () {
      expect(detect('「诸行无常，是生灭法。生灭灭已，寂灭为乐。」'), 4);
    });

    test('句数多于四句仍命中（八句五言）', () {
      expect(
        detect('愿以此功德，庄严佛净土。上报四重恩，下济三途苦。'
            '若有见闻者，悉发菩提心。尽此一报身，同生极乐国。'),
        5,
      );
    });
  });

  group('拒斥：从严判据（漏检无害化）', () {
    test('散文长短句混合（心经节选）', () {
      expect(detect('观自在菩萨，行深般若波罗蜜多时，照见五蕴皆空，度一切苦厄。'), isNull);
    });

    test('句数不足四句', () {
      expect(detect('诸行无常，是生灭法。'), isNull);
    });

    test('句长不等', () {
      expect(detect('诸行无常，是生灭法。生灭灭已了，寂灭为乐。'), isNull);
    });

    test('句长超出四至七言', () {
      // 三言 ×4
      expect(detect('勤修戒，慎勿逸。守本心，证菩提。'), isNull);
      // 八言 ×4
      expect(detect('诸恶莫作众善奉行，自净其意是诸佛教。'
              '诸恶莫作众善奉行，自净其意是诸佛教。'),
          isNull);
    });

    test('段尾无句读收束（游离残句）', () {
      expect(detect('诸行无常，是生灭法。生灭灭已，寂灭为乐'), isNull);
    });

    test('引导语混入（说偈言：）靠等长判据拒斥', () {
      expect(detect('尔时世尊而说偈言：诸行无常，是生灭法。生灭灭已，寂灭为乐。'), isNull);
    });

    test('独立占格标点破坏等长', () {
      expect(detect('诸行·无常，是生灭法。生灭灭已，寂灭为乐。'), isNull);
    });

    test('空 token 序列', () {
      expect(detectVerseClauseLen(const []), isNull);
    });
  });

  group('buildTokenStream 集成', () {
    BookData bookOf(List<JuanBlock> blocks) => BookData(
          meta: const BookMeta(id: 't', bu: '', title: '测', author: ''),
          blocks: blocks,
        );
    String identity(String s) => s;

    test('正文偈颂段标注句长，散文段与标题段不标注', () {
      final book = bookOf(const [
        JuanBlock(
            id: 'b0',
            type: JuanBlockType.bt,
            paragraphs: ['大般若经，卷第一。大般若经，卷第一。']),
        JuanBlock(id: 'b1', type: JuanBlockType.p, paragraphs: [
          '观自在菩萨，行深般若波罗蜜多时，照见五蕴皆空，度一切苦厄。',
          '诸行无常，是生灭法。生灭灭已，寂灭为乐。',
        ]),
      ]);
      final paras =
          buildTokenStream(book: book, display: identity, baiwen: false);
      expect(paras[0].verseClauseLen, isNull, reason: 'bt 标题不是偈颂');
      expect(paras[1].verseClauseLen, isNull, reason: '散文不误判');
      expect(paras[2].verseClauseLen, 4);
    });

    test('白文流：标注保留且 A6 不变式成立（token 数整除句长）', () {
      final book = bookOf(const [
        JuanBlock(id: 'b', type: JuanBlockType.p, paragraphs: [
          '诸法从本来，常自寂灭相。佛子行道已，来世得作佛。',
        ]),
      ]);
      final paras =
          buildTokenStream(book: book, display: identity, baiwen: true);
      final para = paras.single;
      expect(para.verseClauseLen, 5);
      expect(para.tokens.length % 5, 0);
      expect(para.tokens.every((t) => t.trailingPunct.isEmpty), isTrue);
    });

    test('白文剥除独立占格标点致格数不整除时撤销标注', () {
      // 每句都含一个占格间隔号 → 带标点检测等长命中（6 格/句），
      // 白文剥除 · 后每句 5 格、段长不整除 6 → 撤销标注。
      final book = bookOf(const [
        JuanBlock(id: 'b', type: JuanBlockType.p, paragraphs: [
          '诸法·从本来，常自·寂灭相。佛子·行道已，来世·得作佛。'
              '诸法·从本来，常自·寂灭相。佛子·行道已，来世·得作佛。',
        ]),
      ]);
      final paras =
          buildTokenStream(book: book, display: identity, baiwen: true);
      expect(paras.single.verseClauseLen, isNull);
      expect(paras.single.tokens.length % 6 != 0, isTrue,
          reason: '前置条件：剥除后确实不整除原句长');
    });
  });
}
