import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../domain/entities/book_entities.dart';
import 'grid_geometry.dart';
import 'token_stream.dart';
import 'vertical_models.dart';

/// 竖排算术分页器（实施方案 §7/§11，验收 C1/C4/C5）。
///
/// 与横排 SutraPaginator 的本质差异：严格网格下布局是纯算术——
/// 无 TextPainter 测量、无时间片，一遍同步完成（万字级 <10ms）。
/// 结构规则：卷首题署两列 → bt 独占列（顶格）→ bm 独占列（低一格）→
/// 正文换段换列、偈颂按句折列 → 插图独占页 → 卷尾 nav 页。
class VerticalPagination {
  VerticalPagination._();

  // ---- 结果缓存（LRU 容量 2，镜像 SutraPaginator） -------------------------

  static final Map<VerticalPaginationKey, VerticalPaginationResult> _cache = {};
  static const _cacheCapacity = 2;

  static VerticalPaginationResult? cached(VerticalPaginationKey key) {
    final hit = _cache.remove(key);
    if (hit != null) _cache[key] = hit;
    return hit;
  }

  @visibleForTesting
  static void clearCache() => _cache.clear();

  /// 缓存键快照（测试探针：断言某操作未触发重排）。
  @visibleForTesting
  static List<VerticalPaginationKey> get debugCacheKeys =>
      List.of(_cache.keys);

  /// 取缓存或同步分页整卷。
  static VerticalPaginationResult run({
    required VerticalPaginationKey key,
    required BookData book,
    required String Function(String) display,
  }) {
    final hit = cached(key);
    if (hit != null) return hit;
    final result = _paginate(key: key, book: book, display: display);
    _cache.remove(key);
    _cache[key] = result;
    while (_cache.length > _cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
    return result;
  }

  // ---- 分页主体 -------------------------------------------------------------

  static VerticalPaginationResult _paginate({
    required VerticalPaginationKey key,
    required BookData book,
    required String Function(String) display,
  }) {
    final grid = VerticalGridSpec.fit(
      contentSize: key.contentSize,
      fontSize: key.fontSize * key.textScaleFactor,
      lineHeight: key.lineHeight,
      letterSpacingEm: key.letterSpacingEm,
    );

    final pages = <VPage>[];
    final cols = <VColumn>[];
    final firstPageOfBlock =
        List<int?>.filled(math.max(book.blocks.length, 1), null);

    // 当前页起点处的阅读上下文块（纯题署页的 firstBlockIndex 来源）。
    var pageStartBlock = 0;
    var lastBlockPlaced = 0;

    void flushPage() {
      if (cols.isEmpty) return;
      var first = -1;
      for (final c in cols) {
        if (c.blockIndex >= 0) {
          first = c.blockIndex;
          break;
        }
      }
      pages.add(VPage(
        columns: List.of(cols),
        firstBlockIndex: first >= 0 ? first : pageStartBlock,
      ));
      cols.clear();
      pageStartBlock = lastBlockPlaced;
    }

    void addColumn(VColumn column) {
      // 逐 token 记录块首现页：散文连排后一个块可能始于列中段
      //（排版修订 D5），只记列首 token 会让 pageForBlock 偏到前块所在页。
      for (final t in column.tokens) {
        final b = t.blockIndex;
        if (b >= 0 && b < firstPageOfBlock.length) {
          firstPageOfBlock[b] ??= pages.length; // 正在装填的页
          lastBlockPlaced = b;
        }
      }
      cols.add(column);
      if (cols.length >= grid.colsPerPage) flushPage();
    }

    /// 把一段 token 装成若干列。偈颂（verseN）按句折列：每列只装
    /// 整数个句子；句长超出列容量的退化场景回退散文连排。
    void addChunked(
      List<GridToken> tokens,
      VColumnRole role, {
      int indent = 0,
      int? verseN,
    }) {
      if (tokens.isEmpty) return;
      final safeIndent = indent.clamp(0, grid.charsPerCol - 1);
      final capacity = grid.charsPerCol - safeIndent;
      var perCol = capacity;
      if (verseN != null && verseN <= capacity) {
        perCol = (capacity ~/ verseN) * verseN;
      }
      assert(perCol >= 1);
      for (var start = 0; start < tokens.length; start += perCol) {
        final end = math.min(start + perCol, tokens.length);
        addColumn(VColumn(
          role: role,
          tokens: tokens.sublist(start, end),
          indent: safeIndent,
        ));
        // A6 不变式：偈颂列内 token 数恒为句长整数倍。
        assert(verseN == null || verseN > capacity || (end - start) % verseN == 0);
      }
    }

    // ---- 卷首题署：书名列（顶格）+ 作者列（下沉，仿卷端题署） ---------------

    List<GridToken> titleTokens(String raw) => tokenizeText(
          display(raw),
          blockIndex: -1,
          paragraphIndex: -1,
          baiwen: key.baiwen,
        );

    addChunked(titleTokens(book.meta.title), VColumnRole.title);
    final author = titleTokens(book.meta.author);
    if (author.isNotEmpty) {
      // 单列放得下 → 底部对齐（indent 下沉）；放不下 → 顶格连排。
      final sink = author.length <= grid.charsPerCol
          ? grid.charsPerCol - author.length
          : 0;
      addChunked(author, VColumnRole.author, indent: sink);
    }

    // ---- 正文流 ---------------------------------------------------------------

    // 散文连排缓冲（排版修订 D5，2026-07-20 用户反馈）：仿古籍连排，
    // 散文段落间**不断列**——句读悬浮已是天然分隔，频繁短列破坏连贯；
    // 仅偈颂、bt/bm 大章节、插图、卷尾处断列。段落锚点仍逐 token 保留。
    final proseRun = <GridToken>[];
    void flushProse() {
      if (proseRun.isEmpty) return;
      addChunked(List.of(proseRun), VColumnRole.body);
      proseRun.clear();
    }

    final stream =
        buildTokenStream(book: book, display: display, baiwen: key.baiwen);
    for (final para in stream) {
      if (para.isImage) {
        // 插图独占页：先封当前页，再单发图片页（沿用横排语义）。
        flushProse();
        flushPage();
        if (para.blockIndex >= 0 && para.blockIndex < firstPageOfBlock.length) {
          firstPageOfBlock[para.blockIndex] ??= pages.length;
          lastBlockPlaced = para.blockIndex;
        }
        pages.add(VPage(
          firstBlockIndex: para.blockIndex >= 0 ? para.blockIndex : pageStartBlock,
          imageUrl: para.imageUrl,
        ));
        pageStartBlock = lastBlockPlaced;
        continue;
      }
      switch (para.blockType) {
        case JuanBlockType.bt:
          flushProse();
          addChunked(para.tokens, VColumnRole.bt);
        case JuanBlockType.bm:
          flushProse();
          addChunked(para.tokens, VColumnRole.bm, indent: 1);
        case JuanBlockType.p:
          if (para.verseClauseLen != null) {
            // 偈颂独立断列、按句折列（用户明确保留的唯一小断）。
            flushProse();
            addChunked(para.tokens, VColumnRole.body,
                verseN: para.verseClauseLen);
          } else {
            proseRun.addAll(para.tokens);
          }
      }
    }
    flushProse();
    flushPage();

    // ---- 卷尾 nav 页（仅有前后部时） ------------------------------------------

    final hasNav = (book.meta.lastBuId?.isNotEmpty ?? false) ||
        (book.meta.nextBuId?.isNotEmpty ?? false);
    if (hasNav) {
      pages.add(VPage(firstBlockIndex: lastBlockPlaced, isNavPage: true));
    }

    // 空书兜底：至少一页，PageView 不允许 itemCount 0。
    if (pages.isEmpty) {
      pages.add(const VPage(firstBlockIndex: 0));
    }

    // ---- 块 → 页映射前向填充（无内容块锚定到前一个已知块所在页） ---------------

    final filled = List<int>.filled(firstPageOfBlock.length, 0);
    var carry = 0;
    for (var b = 0; b < firstPageOfBlock.length; b++) {
      final v = firstPageOfBlock[b];
      if (v != null) carry = math.min(v, pages.length - 1);
      filled[b] = carry;
    }

    return VerticalPaginationResult(
      key: key,
      grid: grid,
      pages: pages,
      firstPageOfBlock: filled,
    );
  }
}
