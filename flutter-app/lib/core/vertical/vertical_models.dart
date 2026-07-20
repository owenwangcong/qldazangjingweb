import '../../domain/entities/book_entities.dart';

/// 竖排排版的数据模型（实施方案 vertical-reader-plan.md §4）。
/// S2 先落字符流层（GridToken / TokenParagraph）；
/// 列/页/分页键（VColumn / VPage / VerticalPaginationKey）随 S4 加入。

/// 一个字面框内的内容。标点不是 token——它是前一字的附属属性，
/// 这是「标点绝不占格、矩阵恒定」的数据层保证。
class GridToken {
  const GridToken({
    required this.char,
    this.trailingPunct = '',
    required this.blockIndex,
    required this.paragraphIndex,
  });

  /// 单个占格字（按 rune 切分，扩展区汉字/代理对安全）。
  final String char;

  /// 悬浮句读堆（'' 为无）。数据完整保留，绘制侧最多呈现 2 枚
  /// （§10 A5：绘制截断、数据保留）。
  final String trailingPunct;

  /// 进度锚定（与 scroll/paged 的 blockIndex 同语义）。
  final int blockIndex;
  final int paragraphIndex;

  GridToken withTrailing(String punct) => GridToken(
        char: char,
        trailingPunct: punct,
        blockIndex: blockIndex,
        paragraphIndex: paragraphIndex,
      );
}

/// 一个连续可排文本段 = 竖排的换列边界单元；插图段独立成项（独占页）。
/// 段内 <img> 会把原段落切成多个 TokenParagraph（同 paragraphIndex）。
class TokenParagraph {
  const TokenParagraph({
    required this.blockIndex,
    required this.paragraphIndex,
    required this.blockType,
    this.tokens = const [],
    this.imageUrl,
    this.verseClauseLen,
  }) : assert(imageUrl == null || tokens.length == 0,
            '插图段不携带 tokens');

  final int blockIndex;
  final int paragraphIndex;

  /// bt=卷标题列 / bm=品名列 / p=正文；列 role 映射在分页器（S4）。
  final JuanBlockType blockType;

  final List<GridToken> tokens;

  /// 非空 = 插图独占页（沿用横排语义）。
  final String? imageUrl;

  /// 偈颂句长（4/5/6/7）；null = 散文。由偈颂检测器（S3）标注，
  /// 分页器据此按句折列。
  final int? verseClauseLen;

  bool get isImage => imageUrl != null;

  TokenParagraph withVerseClauseLen(int? n) => TokenParagraph(
        blockIndex: blockIndex,
        paragraphIndex: paragraphIndex,
        blockType: blockType,
        tokens: tokens,
        imageUrl: imageUrl,
        verseClauseLen: n,
      );
}
