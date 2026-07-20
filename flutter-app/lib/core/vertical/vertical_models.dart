import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../domain/entities/book_entities.dart';
import 'grid_geometry.dart';

/// 竖排排版的数据模型（实施方案 vertical-reader-plan.md §4）：
/// 字符流层（GridToken / TokenParagraph，S2）与
/// 列/页/分页键层（VColumn / VPage / VerticalPaginationKey，S4）。

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

// ---- 列 / 页 / 分页键（S4） ------------------------------------------------

/// 列的角色：决定绘制样式与语义。title/author 为卷首题署（blockIndex -1），
/// bt/bm/body 携带真实块索引供进度锚定。
enum VColumnRole { title, author, bt, bm, body }

/// 一列。tokens 上限 = charsPerCol − indent；单列内所有 token 同段
/// （换段即换列，§7）。
class VColumn {
  const VColumn({
    required this.role,
    required this.tokens,
    this.indent = 0,
  });

  final VColumnRole role;
  final List<GridToken> tokens;

  /// 顶部空格数（bm 品名低一格 = 1、作者署名下沉等）。
  final int indent;

  /// 本列的进度锚块；题署列为 -1。
  int get blockIndex => tokens.isEmpty ? -1 : tokens.first.blockIndex;
}

/// 一页。三种形态互斥：文字页（columns）/ 插图独占页（imageUrl）/
/// 卷尾 nav 页（isNavPage）。columns 的列序即阅读序（index 0 = 最右列）。
class VPage {
  const VPage({
    this.columns = const [],
    required this.firstBlockIndex,
    this.imageUrl,
    this.isNavPage = false,
  });

  final List<VColumn> columns;

  /// 进度锚点（语义同横排 ReaderPageModel.firstBlockIndex）。
  final int firstBlockIndex;
  final String? imageUrl;
  final bool isNavPage;
}

/// 分页缓存键：任一分量变化都意味着整卷重排。
/// 乌丝栏开关**不在键内**（纯绘制属性）；白文在（改变字符流）。
@immutable
class VerticalPaginationKey {
  const VerticalPaginationKey({
    required this.bookId,
    required this.contentSize,
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacingEm,
    required this.isSimplified,
    required this.baiwen,
    required this.textScaleFactor,
  });

  final String bookId;
  final Size contentSize;

  /// 生效 family（FontState.activeFamily ?? ''，异步字体加载完成翻转）。
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final double letterSpacingEm;
  final bool isSimplified;
  final bool baiwen;
  final double textScaleFactor;

  @override
  bool operator ==(Object other) =>
      other is VerticalPaginationKey &&
      other.bookId == bookId &&
      other.contentSize == contentSize &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      other.letterSpacingEm == letterSpacingEm &&
      other.isSimplified == isSimplified &&
      other.baiwen == baiwen &&
      other.textScaleFactor == textScaleFactor;

  @override
  int get hashCode => Object.hash(bookId, contentSize, fontFamily, fontSize,
      lineHeight, letterSpacingEm, isSimplified, baiwen, textScaleFactor);
}

/// 一次分页运行的产物。分页为同步纯算术（无时间片），结果即终态。
class VerticalPaginationResult {
  VerticalPaginationResult({
    required this.key,
    required this.grid,
    required this.pages,
    required List<int> firstPageOfBlock,
  }) : _firstPageOfBlock = firstPageOfBlock;

  final VerticalPaginationKey key;
  final VerticalGridSpec grid;
  final List<VPage> pages;

  /// 块 → 首次出现页码（构建期已对无内容块做前向填充，无 null）。
  final List<int> _firstPageOfBlock;

  int pageForBlock(int blockIndex) {
    if (pages.isEmpty) return 0;
    if (_firstPageOfBlock.isEmpty) return 0;
    return _firstPageOfBlock[blockIndex.clamp(0, _firstPageOfBlock.length - 1)]
        .clamp(0, pages.length - 1);
  }

  int blockForPage(int page) => pages.isEmpty
      ? 0
      : pages[page.clamp(0, pages.length - 1)].firstBlockIndex;
}
