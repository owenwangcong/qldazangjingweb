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

    // ═══ 第一层：列带生成（翻页/滚动共享,V1 两层化） ═══

    final strip = <VStripItem>[];
    final stripAnchors = <int>[];
    final blockCount = math.max(book.blocks.length, 1);
    final firstStripItemOfBlock = List<int?>.filled(blockCount, null);
    var stripLastBlock = 0;

    void addColumn(VColumn column) {
      // 逐 token 记录块首现条目（散文连排 D5 下块可始于列中段）。
      final context = stripLastBlock;
      var anchor = -1;
      for (final t in column.tokens) {
        final b = t.blockIndex;
        if (b >= 0 && b < blockCount) {
          firstStripItemOfBlock[b] ??= strip.length;
          stripLastBlock = b;
          if (anchor < 0) anchor = b;
        }
      }
      strip.add(StripColumn(column));
      stripAnchors.add(anchor >= 0 ? anchor : context);
    }

    /// 把一段 token 装成若干列。偈颂（verseN）按句折列：每列只装
    /// 整数个句子且句间空一格（D6）；句长超出列容量的退化场景回退散文连排。
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
      final verseFits = verseN != null && verseN <= capacity;
      if (verseFits) {
        // 句间空一格（D6）：k 句占 k×n + (k−1) 格 → k = (容量+1) ÷ (n+1)。
        final k = math.max(1, (capacity + 1) ~/ (verseN + 1));
        perCol = k * verseN;
      }
      assert(perCol >= 1);
      for (var start = 0; start < tokens.length; start += perCol) {
        final end = math.min(start + perCol, tokens.length);
        final chunk = tokens.sublist(start, end);
        addColumn(VColumn(
          role: role,
          tokens: chunk,
          indent: safeIndent,
          verseClauseLen: verseFits ? verseN : null,
        ));
        // A6 不变式：偈颂列内 token 数恒为句长整数倍，且含句间空格后
        // 不超列容量。
        assert(!verseFits || chunk.length % verseN == 0);
        assert(!verseFits ||
            chunk.length + (chunk.length ~/ verseN) - 1 <= capacity);
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

    // 散文连排缓冲（D5）与偈颂区段缓冲（漏检修复）：仅偈颂、bt/bm、插图、
    // 卷尾断列。段落/块锚点逐 token 保留。
    final proseRun = <GridToken>[];
    void flushProse() {
      if (proseRun.isEmpty) return;
      addChunked(List.of(proseRun), VColumnRole.body);
      proseRun.clear();
    }

    final verseRun = <GridToken>[];
    int? verseRunN;
    void flushVerse() {
      if (verseRun.isEmpty) return;
      addChunked(List.of(verseRun), VColumnRole.body, verseN: verseRunN);
      verseRun.clear();
      verseRunN = null;
    }

    final stream =
        buildTokenStream(book: book, display: display, baiwen: key.baiwen);
    for (final para in stream) {
      if (para.isImage) {
        flushProse();
        flushVerse();
        final b = para.blockIndex;
        if (b >= 0 && b < blockCount) {
          firstStripItemOfBlock[b] ??= strip.length;
        }
        strip.add(StripImage(imageUrl: para.imageUrl!, blockIndex: b));
        stripAnchors.add(b >= 0 ? b : stripLastBlock);
        if (b >= 0 && b < blockCount) stripLastBlock = b;
        continue;
      }
      switch (para.blockType) {
        case JuanBlockType.bt:
          flushProse();
          flushVerse();
          addChunked(para.tokens, VColumnRole.bt);
        case JuanBlockType.bm:
          flushProse();
          flushVerse();
          addChunked(para.tokens, VColumnRole.bm, indent: 1);
        case JuanBlockType.p:
          if (para.verseClauseLen != null) {
            // 偈颂断列、按句折列；相邻同 n 段并入同一区段。
            flushProse();
            if (verseRunN != null && verseRunN != para.verseClauseLen) {
              flushVerse();
            }
            verseRunN = para.verseClauseLen;
            verseRun.addAll(para.tokens);
          } else {
            flushVerse();
            proseRun.addAll(para.tokens);
          }
      }
    }
    flushProse();
    flushVerse();

    final hasNav = (book.meta.lastBuId?.isNotEmpty ?? false) ||
        (book.meta.nextBuId?.isNotEmpty ?? false);
    if (hasNav) {
      strip.add(const StripNav());
      stripAnchors.add(stripLastBlock);
    }

    // ═══ 第二层：页分组（仅翻页消费;语义与重构前逐位一致,指纹对拍锁定） ═══

    final pages = <VPage>[];
    final firstPageOfBlock = List<int?>.filled(blockCount, null);
    final cols = <VColumn>[];
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

    for (final item in strip) {
      switch (item) {
        case StripColumn(:final column):
          for (final t in column.tokens) {
            final b = t.blockIndex;
            if (b >= 0 && b < blockCount) {
              firstPageOfBlock[b] ??= pages.length;
              lastBlockPlaced = b;
            }
          }
          cols.add(column);
          if (cols.length >= grid.colsPerPage) flushPage();
        case StripImage(:final imageUrl, :final blockIndex):
          flushPage();
          if (blockIndex >= 0 && blockIndex < blockCount) {
            firstPageOfBlock[blockIndex] ??= pages.length;
            lastBlockPlaced = blockIndex;
          }
          pages.add(VPage(
            firstBlockIndex: blockIndex >= 0 ? blockIndex : pageStartBlock,
            imageUrl: imageUrl,
          ));
          pageStartBlock = lastBlockPlaced;
        case StripNav():
          flushPage();
          pages.add(VPage(firstBlockIndex: lastBlockPlaced, isNavPage: true));
      }
    }
    flushPage();

    // 空书兜底：至少一页，PageView 不允许 itemCount 0。
    if (pages.isEmpty) {
      pages.add(const VPage(firstBlockIndex: 0));
    }

    // ---- 块 → 页/条目映射前向填充 ---------------------------------------------

    List<int> forwardFill(List<int?> src, int maxIndex) {
      final filled = List<int>.filled(src.length, 0);
      var carry = 0;
      for (var b = 0; b < src.length; b++) {
        final v = src[b];
        if (v != null) carry = math.min(v, maxIndex);
        filled[b] = carry;
      }
      return filled;
    }

    return VerticalPaginationResult(
      key: key,
      grid: grid,
      strip: strip,
      pages: pages,
      firstPageOfBlock: forwardFill(firstPageOfBlock, pages.length - 1),
      firstStripItemOfBlock:
          forwardFill(firstStripItemOfBlock, math.max(strip.length - 1, 0)),
      stripAnchors: stripAnchors,
    );
  }
}
