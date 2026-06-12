import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../domain/entities/book_entities.dart';
import 'page_models.dart';
import 'paragraph_text.dart';

/// 翻页模式排版引擎：把整本书测量、装填成定高页面序列。
///
/// 约束与策略（见计划「分页算法」节）：
/// - TextPainter 无法进 isolate（需引擎字体绑定）→ 主线程时间片：
///   每事件循环回合预算 [_budgetMs]，到时 notify + 让出，pages 只追加。
/// - 测量参数（样式/宽度/textScaler/转换后文本）与渲染侧逐字节一致，
///   否则切页错位——这是整个方案的风险点 #1。
/// - 断行稳定性：Flutter/SkParagraph 贪心断行对行边界前缀稳定，且语料为
///   等宽 CJK；从行边界切出的子串在同宽度下重排得到相同折行。
class SutraPaginator extends ChangeNotifier {
  SutraPaginator({
    required this.key,
    required this.book,
    required this.display,
    required TextStyle baseStyle,
  })  : textScaler = TextScaler.linear(key.textScaleFactor),
        result = PaginationResult(
          key: key,
          baseStyle: baseStyle,
          blockCount: book.blocks.length,
        );

  // ---- 完成结果缓存（LRU，容量 2：覆盖来回切换模式/重进路由） -------------

  static final Map<PaginationKey, PaginationResult> _cache = {};
  static const _cacheCapacity = 2;

  static PaginationResult? cached(PaginationKey key) {
    final hit = _cache.remove(key);
    if (hit != null) _cache[key] = hit; // 触达即刷新 LRU 顺序
    return hit;
  }

  static void _store(PaginationResult r) {
    _cache.remove(r.key);
    _cache[r.key] = r;
    while (_cache.length > _cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  @visibleForTesting
  static void clearCache() => _cache.clear();

  // ---- 实例状态 -------------------------------------------------------------

  final PaginationKey key;
  final BookData book;
  final String Function(String) display;
  final TextScaler textScaler;
  final PaginationResult result;

  /// 每回合主线程预算（毫秒）。
  static const _budgetMs = 8;

  /// 单次 TextPainter.layout 不可中断 → 超长段落先切块测量，保证有界。
  static const _measureChunkChars = 8000;

  /// 亚像素舍入余量：装页高度按 contentHeight − 1 计。
  static const _epsilon = 1.0;

  bool _disposed = false;
  bool _started = false;

  final _stopwatch = Stopwatch();
  final List<PageSlice> _slices = [];
  late double _remaining;

  /// 当前页起点处的阅读上下文块（纯页眉/纯 nav 页的 firstBlockIndex 来源）。
  int _pageStartBlock = 0;
  int _lastBlockPlaced = 0;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    unawaited(_run());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ---- 主循环 ---------------------------------------------------------------

  double get _pageHeight => key.contentSize.height - _epsilon;

  Future<void> _run() async {
    // 先让出一拍：start() 可能在 build 期间被调用，notify 不能落在 build 里。
    await Future<void>.delayed(Duration.zero);
    if (_disposed) return;

    _remaining = _pageHeight;
    _stopwatch.start();

    _placeHeader();

    for (var b = 0; b < book.blocks.length; b++) {
      final block = book.blocks[b];
      switch (block.type) {
        case JuanBlockType.bt:
          _placeBlockTitle(b, block, isSubtitle: false);
        case JuanBlockType.bm:
          _placeBlockTitle(b, block, isSubtitle: true);
        case JuanBlockType.p:
          for (var p = 0; p < block.paragraphs.length; p++) {
            final cleaned = cleanParagraph(block.paragraphs[p]);
            for (final segment in splitParagraphSegments(cleaned)) {
              if (segment.imageUrl != null) {
                _placeImage(b, p, segment.imageUrl!);
              } else {
                if (!await _placeTextSegment(b, p, display(segment.text!))) {
                  return; // 已取消
                }
              }
            }
            _applyParagraphSpacing();
          }
      }
      result.blocksMeasured = b + 1;
      if (!await _maybeYield()) return;
    }

    _placeNav();
    _flushPage();

    result.done = true;
    _store(result);
    _safeNotify();
  }

  Future<bool> _maybeYield() async {
    if (_stopwatch.elapsedMilliseconds < _budgetMs) return true;
    _safeNotify();
    // 不用 endOfFrame：无帧调度时（页面被遮挡等）会停摆。
    await Future<void>.delayed(Duration.zero);
    if (_disposed) return false;
    _stopwatch
      ..reset()
      ..start();
    return true;
  }

  // ---- 装页原语 -------------------------------------------------------------

  void _flushPage() {
    if (_slices.isEmpty) return;
    var first = -1;
    for (final s in _slices) {
      if (s.blockIndex >= 0) {
        first = s.blockIndex;
        break;
      }
    }
    result.pages.add(ReaderPageModel(
      slices: List.of(_slices),
      firstBlockIndex: first >= 0 ? first : _pageStartBlock,
    ));
    _slices.clear();
    _remaining = _pageHeight;
    _pageStartBlock = _lastBlockPlaced;
  }

  void _addSlice(PageSlice slice, double height) {
    if (slice.blockIndex >= 0) {
      result.recordBlockPage(slice.blockIndex, result.pages.length);
      _lastBlockPlaced = slice.blockIndex;
    }
    _slices.add(slice);
    _remaining -= height;
    if (_remaining < 0) _remaining = 0;
  }

  /// 原子单元：装不下整体翻页；比整页还高则强放（渲染侧 ClipRect 裁切），
  /// 保证永远向前推进。
  void _placeAtomic(PageSlice slice, double height) {
    if (height > _remaining && _slices.isNotEmpty) _flushPage();
    _addSlice(slice, height);
    if (_remaining <= 0) _flushPage();
  }

  double _measure(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: key.contentSize.width);
    final h = tp.height;
    tp.dispose();
    return h;
  }

  // ---- 各单元测量（高度公式镜像 reader_page.dart 滚动渲染） -----------------

  void _placeHeader() {
    // _buildBookHeader：title(24/w700/h1.5) +10 +BrushUnderline(3+3) +10
    // +author(16)，外层 Padding(bottom: 24)。
    final family = result.baseStyle.fontFamily;
    final h = _measure(display(book.meta.title),
            readerHeaderTitleStyle(fontFamily: family)) +
        10 +
        6 +
        10 +
        _measure(display(book.meta.author),
            readerHeaderAuthorStyle(fontFamily: family)) +
        24;
    _placeAtomic(PageSlice(kind: PageSliceKind.header), h);
  }

  void _placeBlockTitle(int blockIndex, JuanBlock block,
      {required bool isSubtitle}) {
    // bt：vertical 20 + 题字(×1.2/w700) + 10 + BrushUnderline(2.8+3)
    // bm：vertical 12 + 题字(w600)
    final text = display(block.paragraphs.join().trim());
    final style = isSubtitle
        ? readerBmStyle(result.baseStyle)
        : readerBtStyle(result.baseStyle);
    final h = isSubtitle
        ? 12 + _measure(text, style) + 12
        : 20 + _measure(text, style) + 10 + 5.8 + 20;
    _placeAtomic(
      PageSlice(
        kind: isSubtitle ? PageSliceKind.subtitle : PageSliceKind.title,
        blockIndex: blockIndex,
        text: text,
        charEnd: text.length,
      ),
      h,
    );
  }

  void _placeImage(int blockIndex, int paragraphIndex, String url) {
    // 插图独占一页：图片尺寸网络加载前未知，独占页让分页与加载状态解耦。
    _flushPage();
    _addSlice(
      PageSlice(
        kind: PageSliceKind.image,
        blockIndex: blockIndex,
        paragraphIndex: paragraphIndex,
        imageUrl: url,
      ),
      _pageHeight,
    );
    _flushPage();
  }

  void _placeNav() {
    // _buildPrevNext：Padding(top:24, bottom:24) + 按钮高 48（无前后部时
    // Row 内全是 shrink → 高 0）。
    final meta = book.meta;
    final hasNav = (meta.lastBuId?.isNotEmpty ?? false) ||
        (meta.nextBuId?.isNotEmpty ?? false);
    _placeAtomic(
        PageSlice(kind: PageSliceKind.nav), hasNav ? 24.0 + 48 + 24 : 48.0);
  }

  /// 文本段：逐行测量、贪心装页，跨页处按行边界切字符区间。
  /// 返回 false 表示运行被取消。
  Future<bool> _placeTextSegment(
      int blockIndex, int paragraphIndex, String converted) async {
    if (converted.trim().isEmpty) return true; // 滚动模式渲染为 shrink

    // 超长段落切块测量：块边界处可能产生一次提前换行（约每 ~10 页一次的
    // 短行），换取单次 layout 有界、时间片可控。
    for (var offset = 0; offset < converted.length; offset += _measureChunkChars) {
      final chunkEnd = (offset + _measureChunkChars < converted.length)
          ? offset + _measureChunkChars
          : converted.length;
      final chunk = converted.substring(offset, chunkEnd);

      final tp = TextPainter(
        text: TextSpan(text: chunk, style: result.baseStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: key.contentSize.width);
      final lines = tp.computeLineMetrics();

      var cursor = 0;
      var lineIdx = 0;
      while (lineIdx < lines.length) {
        var take = 0;
        var height = 0.0;
        while (lineIdx + take < lines.length &&
            height + lines[lineIdx + take].height <= _remaining) {
          height += lines[lineIdx + take].height;
          take++;
        }
        if (take == 0) {
          if (_slices.isNotEmpty) {
            _flushPage();
            continue;
          }
          // 单行高于整页：强放一行，渲染侧裁切，保证前进。
          take = 1;
          height = lines[lineIdx].height;
        }

        // 行边界 → 字符区间：逐行推进 end（软换行 end == 下一行起点）。
        var end = cursor;
        for (var k = 0; k < take; k++) {
          final boundary = tp.getLineBoundary(TextPosition(offset: end));
          end = boundary.end > end ? boundary.end : end + 1; // 防停滞
        }
        if (end > chunk.length) end = chunk.length;

        _addSlice(
          PageSlice(
            kind: PageSliceKind.text,
            blockIndex: blockIndex,
            paragraphIndex: paragraphIndex,
            text: chunk,
            charStart: cursor,
            charEnd: end,
          ),
          height,
        );

        cursor = end;
        lineIdx += take;
        if (_remaining <= 0 && lineIdx < lines.length) _flushPage();
        if (!await _maybeYield()) {
          tp.dispose();
          return false;
        }
      }
      tp.dispose();
    }
    return true;
  }

  /// 段距只在页内放得下时附着到段落最后一个切片；页尾自然丢弃。
  void _applyParagraphSpacing() {
    if (_slices.isEmpty) return;
    final spacing = key.paragraphSpacing;
    if (spacing <= 0) return;
    if (_remaining >= spacing) {
      _slices.last.paddingAfter += spacing;
      _remaining -= spacing;
    } else {
      _flushPage();
    }
  }
}

// ---- 渲染/测量共用的样式公式（镜像 reader_page.dart 字面样式） ---------------

/// 书名页眉标题（scroll: TText fontSize24/w700/h1.5，family 继承主题 =
/// activeFamily；翻页侧显式传入同一 family 以保证测量一致）。
TextStyle readerHeaderTitleStyle({String? fontFamily, Color? color}) =>
    TextStyle(
      fontFamily: fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.5,
      color: color,
    );

TextStyle readerHeaderAuthorStyle({String? fontFamily, Color? color}) =>
    TextStyle(fontFamily: fontFamily, fontSize: 16, color: color);

/// bt 卷标题：正文样式 ×1.2 加粗（letterSpacing 保持绝对值不变，与滚动一致）。
TextStyle readerBtStyle(TextStyle base) =>
    base.copyWith(fontSize: base.fontSize! * 1.2, fontWeight: FontWeight.w700);

/// bm 品名：正文样式加粗。
TextStyle readerBmStyle(TextStyle base) =>
    base.copyWith(fontWeight: FontWeight.w600);
