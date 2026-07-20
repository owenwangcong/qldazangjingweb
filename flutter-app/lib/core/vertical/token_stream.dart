import '../../domain/entities/book_entities.dart';
import '../pagination/paragraph_text.dart';
import 'punctuation.dart';
import 'verse_detector.dart';
import 'vertical_models.dart';

/// 竖排字符流构建器（实施方案 §4/§7，验收 C2/C3）。
///
/// 与 scroll/paged 两模式共享同一段落预处理准源（paragraph_text.dart）：
/// cleanParagraph 剥弯引号 → splitParagraphSegments 切 <img> →
/// display() 按段简繁转换 → tokenize（带标点）→ 偈颂检测 →
/// （白文时）剥除标点。处理次序不可调换：标点归属必须在转换之后，
/// 偈颂检测必须在白文剥除之前（剥后无句读可切）。
List<TokenParagraph> buildTokenStream({
  required BookData book,
  required String Function(String) display,
  required bool baiwen,
}) {
  final paragraphs = <TokenParagraph>[];

  void addText(int b, int p, JuanBlockType type, String raw) {
    final cleaned = cleanParagraph(raw);
    for (final segment in splitParagraphSegments(cleaned)) {
      if (segment.imageUrl != null) {
        paragraphs.add(TokenParagraph(
          blockIndex: b,
          paragraphIndex: p,
          blockType: type,
          imageUrl: segment.imageUrl,
        ));
        continue;
      }
      // 恒以带标点形态 tokenize——偈颂检测的唯一可靠输入。
      final punctuated = tokenizeText(
        display(segment.text!),
        blockIndex: b,
        paragraphIndex: p,
        baiwen: false,
      );
      if (punctuated.isEmpty) continue;

      // 只对正文段检测；标题（bt/bm）不是偈颂。
      var verse =
          type == JuanBlockType.p ? detectVerseClauseLen(punctuated) : null;

      final tokens = baiwen ? stripTokensForBaiwen(punctuated) : punctuated;
      if (tokens.isEmpty) continue;
      // 白文剥除了独立占格标点后格数可能改变；不再整除句长时撤销
      // 标注（按散文连排，漏检无害化），维持 A6 不变式。
      if (verse != null && tokens.length % verse != 0) verse = null;
      assert(verse == null || tokens.length % verse == 0);

      paragraphs.add(TokenParagraph(
        blockIndex: b,
        paragraphIndex: p,
        blockType: type,
        tokens: tokens,
        verseClauseLen: verse,
      ));
    }
  }

  for (var b = 0; b < book.blocks.length; b++) {
    final block = book.blocks[b];
    switch (block.type) {
      case JuanBlockType.bt:
      case JuanBlockType.bm:
        // 标题块合并为单段（镜像 SutraPaginator._placeBlockTitle）。
        addText(b, 0, block.type, block.paragraphs.join().trim());
      case JuanBlockType.p:
        for (var p = 0; p < block.paragraphs.length; p++) {
          addText(b, p, block.type, block.paragraphs[p]);
        }
    }
  }
  return paragraphs;
}

/// 把（已转换的）文本段切成占格 token 序列。
///
/// 规则（§7）：
/// - 按 rune 迭代——扩展区汉字（如 𠀋）是单 token，绝不按 code unit 断裂；
/// - 空白一律剥除（古籍无空格，全角空格/换行同理）；
/// - 句读：悬浮标点附着前一字 trailingPunct（连续标点堆叠、数据全留），
///   段首前置符无所附则舍弃；非悬浮类标点（如间隔号 ·）独立占格；
/// - 白文 = 带标点形态再剥除（单一真源，见 [stripTokensForBaiwen]）。
List<GridToken> tokenizeText(
  String text, {
  required int blockIndex,
  required int paragraphIndex,
  required bool baiwen,
}) {
  final tokens = <GridToken>[];
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    if (whitespace.hasMatch(ch)) continue;
    if (isFloatingPunct(ch)) {
      if (tokens.isEmpty) continue; // 段首前置符：无所附，舍弃。
      final last = tokens.last;
      tokens[tokens.length - 1] = last.withTrailing(last.trailingPunct + ch);
      continue;
    }
    tokens.add(GridToken(
      char: ch,
      blockIndex: blockIndex,
      paragraphIndex: paragraphIndex,
    ));
  }
  // 不变式：占格 token 一律是单 rune；悬浮堆只含悬浮类标点。
  assert(tokens.every((t) => t.char.runes.length == 1));
  assert(tokens.every((t) => t.trailingPunct.runes
      .every((r) => isFloatingPunct(String.fromCharCode(r)))));
  return baiwen ? stripTokensForBaiwen(tokens) : tokens;
}

/// 白文剥除：去掉独立占格的标点/符号 token、清空悬浮堆。
/// 只留可占格文字，与直接按白文 tokenize 语义等价（C2 测试锁定）。
List<GridToken> stripTokensForBaiwen(List<GridToken> tokens) => [
      for (final t in tokens)
        if (!anyPunctOrSymbol.hasMatch(t.char))
          t.trailingPunct.isEmpty ? t : t.withTrailing(''),
    ];
