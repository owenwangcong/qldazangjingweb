import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ink/ink.dart';
import '../../core/pagination/page_models.dart';
import '../../core/pagination/sutra_paginator.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/book_entities.dart';
import '../providers/app_providers.dart';
import 'reader_text_utils.dart';

/// shell（reader_page）向翻页视图发起块级跳转的句柄：
/// TOC / 书签 / 进度恢复都走 [jumpToBlock]。视图未挂载或排版未到达时挂起，
/// 就绪后自动执行。
class PagedReaderController {
  void Function(int blockIndex)? _handler;
  int? _pendingBlock;

  void jumpToBlock(int blockIndex) {
    final handler = _handler;
    if (handler != null) {
      handler(blockIndex);
    } else {
      _pendingBlock = blockIndex;
    }
  }

  void _attach(void Function(int) handler) {
    _handler = handler;
    final pending = _pendingBlock;
    _pendingBlock = null;
    if (pending != null) handler(pending);
  }

  void _detach(void Function(int) handler) {
    if (identical(_handler, handler)) _handler = null;
  }
}

/// 左右翻页阅读视图（与滚动模式互斥的 reader body）。
///
/// 职责边界：分页计算在 [SutraPaginator]；进度/书签/选择工具条等数据语义
/// 仍归 shell——本视图只通过回调上报「当前块」「阅读进度」「页码」。
class PagedReader extends ConsumerStatefulWidget {
  const PagedReader({
    super.key,
    required this.bookId,
    required this.book,
    required this.anchorBlockIndex,
    required this.highlightText,
    required this.controller,
    required this.onBlockChanged,
    required this.onProgress,
    required this.onPageInfo,
    required this.onSelectionChanged,
    required this.contextMenuBuilder,
    required this.onToggleChrome,
  });

  final String bookId;
  final BookData book;

  /// 初始锚点块（路由 ?index / 搜索命中 / 模式切换时的当前块）；null = 卷首。
  final int? anchorBlockIndex;
  final String? highlightText;
  final PagedReaderController controller;
  final ValueChanged<int> onBlockChanged;
  final ValueChanged<double> onProgress;
  final void Function(int current, int total, bool done) onPageInfo;
  final ValueChanged<String> onSelectionChanged;
  final Widget Function(BuildContext, SelectableRegionState) contextMenuBuilder;
  final VoidCallback onToggleChrome;

  /// 页面上下留白；底部为卷轴进度条留出呼吸（分页几何与渲染共用）。
  static const double topPad = 16;
  static const double bottomPad = 28;

  @override
  ConsumerState<PagedReader> createState() => _PagedReaderState();
}

class _PagedReaderState extends ConsumerState<PagedReader> {
  PaginationKey? _key;
  SutraPaginator? _paginator;
  PaginationResult? _result;
  PageController? _pageController;
  Timer? _rekeyDebounce;

  int _anchorBlock = 0;
  int? _pendingJumpBlock;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _anchorBlock = widget.anchorBlockIndex ?? 0;
    widget.controller._attach(_handleJumpToBlock);
  }

  @override
  void didUpdateWidget(PagedReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._detach(_handleJumpToBlock);
      widget.controller._attach(_handleJumpToBlock);
    }
  }

  @override
  void dispose() {
    widget.controller._detach(_handleJumpToBlock);
    _rekeyDebounce?.cancel();
    _disposePaginator();
    _pageController?.dispose();
    super.dispose();
  }

  void _disposePaginator() {
    _paginator?.removeListener(_onPaginatorTick);
    _paginator?.dispose();
    _paginator = null;
  }

  // ---- 分页运行管理 ----------------------------------------------------------

  void _ensurePagination(
    PaginationKey key,
    TextStyle baseStyle,
    String Function(String) display,
  ) {
    if (_key == key) return;
    _key = key;
    _rekeyDebounce?.cancel();

    final cachedResult = SutraPaginator.cached(key);
    if (cachedResult != null) {
      _disposePaginator();
      // 在 build 中：采用结果须等本帧结束。
      scheduleMicrotask(() {
        if (!mounted || _key != key) return;
        setState(() => _adoptResult(cachedResult));
      });
      return;
    }

    void startRun() {
      if (!mounted || _key != key) return;
      _disposePaginator();
      final paginator = SutraPaginator(
        key: key,
        book: widget.book,
        display: display,
        baseStyle: baseStyle,
      );
      _paginator = paginator;
      paginator.addListener(_onPaginatorTick);
      paginator.start();
    }

    if (_result == null) {
      scheduleMicrotask(startRun);
    } else {
      // 设置滑杆/旋转会连发 key 变化：250ms 防抖；期间旧结果（按其自身
      // baseStyle 快照渲染，内部自洽）继续显示。
      _rekeyDebounce = Timer(const Duration(milliseconds: 250), startRun);
    }
  }

  void _onPaginatorTick() {
    if (!mounted) return;
    final paginator = _paginator;
    if (paginator == null) return;
    final r = paginator.result;

    if (!identical(_result, r)) {
      // 新一轮排版进行中：到达锚点块即原子切换，否则仅刷新进度展示。
      final target = _pendingJumpBlock ?? _anchorBlock;
      final page = r.pageForBlock(target);
      if (r.done || (page != null && page < r.pages.length)) {
        setState(() => _adoptResult(r));
      } else {
        setState(() {});
      }
      return;
    }

    // 当前结果继续增长：先消化挂起跳转，再刷新页数/完成态。
    final pending = _pendingJumpBlock;
    if (pending != null) {
      final page = r.pageForBlock(pending);
      if (page != null && page < r.pages.length) {
        _pendingJumpBlock = null;
        _animateToPage(page);
      } else if (r.done) {
        _pendingJumpBlock = null;
        if (r.pages.isNotEmpty) _animateToPage(r.pages.length - 1);
      }
    }
    // 完成瞬间 spinner 尾页消失（itemCount 收缩 1）：若恰停在尾页，退回末页。
    if (r.done && r.pages.isNotEmpty && _currentPage >= r.pages.length) {
      _animateToPage(r.pages.length - 1);
    }
    setState(() {});
    _notifyShell();
  }

  void _adoptResult(PaginationResult r) {
    _result = r;
    final target = _pendingJumpBlock ?? _anchorBlock;
    _pendingJumpBlock = null;
    var page = r.pageForBlock(target) ?? 0;
    if (page >= r.pages.length) {
      page = r.pages.isEmpty ? 0 : r.pages.length - 1;
    }
    _currentPage = page;
    // 保留精确锚点块（页首块可能更靠前，采用它会让进度逐次回漂）。
    _anchorBlock = widget.book.blocks.isEmpty
        ? 0
        : target.clamp(0, widget.book.blocks.length - 1);
    _recreateController(page);
    _notifyShell();
  }

  void _recreateController(int page) {
    final old = _pageController;
    _pageController = PageController(initialPage: page);
    if (old != null) {
      // PageView 仍持有旧控制器至下一帧换装完成，延后销毁。
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  // ---- 导航 -------------------------------------------------------------------

  void _handleJumpToBlock(int blockIndex) {
    final target = blockIndex < 0 ? 0 : blockIndex;
    final r = _result;
    if (r == null) {
      _pendingJumpBlock = target;
      _anchorBlock = target;
      return;
    }
    final page = r.pageForBlock(target);
    if (page != null && page < r.pages.length) {
      _animateToPage(page);
    } else if (!r.done) {
      // 排版尚未到达：挂起（角落 EnsoLoading 提示），到达即跳。
      setState(() => _pendingJumpBlock = target);
    } else if (r.pages.isNotEmpty) {
      _animateToPage(r.pages.length - 1);
    }
  }

  void _animateToPage(int page) {
    final controller = _pageController;
    if (controller != null && controller.hasClients) {
      controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      // PageView 尚未挂上控制器（同帧竞态）：直接重建到目标页。
      setState(() {
        _currentPage = page;
        _recreateController(page);
        final r = _result;
        if (r != null && r.pages.isNotEmpty) {
          _anchorBlock = r.blockForPage(page);
        }
        _notifyShell();
      });
    }
  }

  void _turnPage(int delta) {
    final r = _result;
    final controller = _pageController;
    if (r == null || controller == null || !controller.hasClients) return;
    final maxPage = r.pages.length - 1 + (r.done ? 0 : 1);
    if (maxPage < 0) return;
    final target = (_currentPage + delta).clamp(0, maxPage);
    if (target == _currentPage) return;
    controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int page) {
    final r = _result;
    if (r == null) return;
    _currentPage = page;
    if (page < r.pages.length) {
      _anchorBlock = r.blockForPage(page);
      widget.onBlockChanged(_anchorBlock);
    }
    _notifyShell();
  }

  void _notifyShell() {
    final r = _result;
    if (r == null) return;
    final total = r.pages.isEmpty ? 1 : r.pages.length;
    widget.onPageInfo((_currentPage + 1).clamp(1, total), total, r.done);
    widget.onProgress(
      total <= 1 ? 1.0 : (_currentPage.clamp(0, total - 1) / (total - 1)),
    );
  }

  // ---- 视图 -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final fontState = ref.watch(fontControllerProvider);
    final display = ref.watch(displayTextProvider);
    final colors = context.colors;
    final ink = context.ink;

    return LayoutBuilder(builder: (context, constraints) {
      // 留白规则与滚动模式一致（reader_page：≥600dp 宽 → 10% 屏宽）。
      final screenWidth = MediaQuery.sizeOf(context).width;
      final hMargin = screenWidth >= 600 ? screenWidth * 0.10 : 20.0;
      final scaler = MediaQuery.textScalerOf(context);
      final scaleFactor =
          scaler.scale(settings.fontSize) / settings.fontSize;
      final contentSize = Size(
        (constraints.maxWidth - 2 * hMargin).clamp(1.0, double.infinity),
        (constraints.maxHeight - PagedReader.topPad - PagedReader.bottomPad)
            .clamp(1.0, double.infinity),
      );
      final baseStyle = TextStyle(
        fontFamily: fontState.activeFamily,
        fontSize: settings.fontSize,
        height: settings.lineHeight,
        letterSpacing: settings.letterSpacingEm * settings.fontSize,
        color: colors.foreground,
      );
      _ensurePagination(
        PaginationKey(
          bookId: widget.bookId,
          contentSize: contentSize,
          fontFamily: fontState.activeFamily ?? '',
          fontSize: settings.fontSize,
          lineHeight: settings.lineHeight,
          letterSpacingEm: settings.letterSpacingEm,
          paragraphSpacing: settings.paragraphSpacing,
          isSimplified: settings.isSimplified,
          textScaleFactor: scaleFactor,
        ),
        baseStyle,
        display,
      );

      final result = _result;
      if (result == null) return _buildTypesetting(colors, display);

      // 渲染样式 = 快照仅换前景色（主题切换无需重排）。
      final renderBase = result.baseStyle.copyWith(color: colors.foreground);
      final needle = widget.highlightText == null
          ? null
          : display(widget.highlightText!);
      final busy = _pendingJumpBlock != null ||
          (_paginator != null && !identical(_paginator!.result, result));

      return Stack(
        children: [
          // SelectionArea 必须在 PageView **外层**（与滚动模式同构）：
          // 放页内会比 PageView 更深、其 TapAndDrag 识别器抢走横向拖动，
          // 翻页手势失效。
          SelectionArea(
            onSelectionChanged: (content) =>
                widget.onSelectionChanged(content?.plainText ?? ''),
            contextMenuBuilder: widget.contextMenuBuilder,
            child: PageView.builder(
              controller: _pageController,
              allowImplicitScrolling: true,
              onPageChanged: _onPageChanged,
              itemCount: result.pages.length + (result.done ? 0 : 1),
              itemBuilder: (context, index) {
                if (index >= result.pages.length) {
                  return const Center(child: EnsoLoading());
                }
                return _PageContent(
                  page: result.pages[index],
                  meta: widget.book.meta,
                  baseStyle: renderBase,
                  textScaler: TextScaler.linear(result.key.textScaleFactor),
                  needle: needle,
                  hMargin: hMargin,
                  colors: colors,
                  ink: ink,
                  display: display,
                  onTapZone: _handleTapZone,
                );
              },
            ),
          ),
          // 重排/深位置排版中：角落墨圈，不挡阅读。
          if (busy)
            const Positioned(
              right: 16,
              bottom: 24,
              child: IgnorePointer(
                child: EnsoLoading(size: 22, strokeWidth: 2),
              ),
            ),
        ],
      );
    });
  }

  void _handleTapZone(int zone) {
    if (zone == 0) {
      widget.onToggleChrome();
    } else {
      _turnPage(zone);
    }
  }

  Widget _buildTypesetting(AppColors colors, String Function(String) display) {
    final measured = _paginator?.result.blocksMeasured ?? 0;
    final total = widget.book.blocks.isEmpty ? 1 : widget.book.blocks.length;
    final pct = (measured * 100 ~/ total).clamp(0, 99);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EnsoLoading(),
          const SizedBox(height: 16),
          Text(
            display('排版中 $pct%'),
            style: TextStyle(fontSize: 13, color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

/// 单页渲染：边缘点按翻页（左 25% / 右 25%）、中间点按显隐 chrome。
/// 选词 SelectionArea 在 PageView 外层（见 PagedReader.build 注释）。
class _PageContent extends StatelessWidget {
  const _PageContent({
    required this.page,
    required this.meta,
    required this.baseStyle,
    required this.textScaler,
    required this.needle,
    required this.hMargin,
    required this.colors,
    required this.ink,
    required this.display,
    required this.onTapZone,
  });

  final ReaderPageModel page;
  final BookMeta meta;
  final TextStyle baseStyle;
  final TextScaler textScaler;
  final String? needle;
  final double hMargin;
  final AppColors colors;
  final InkTokens ink;
  final String Function(String) display;
  final ValueChanged<int> onTapZone;

  @override
  Widget build(BuildContext context) {
    final hasNav = page.slices.any((s) => s.kind == PageSliceKind.nav);
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              hMargin,
              PagedReader.topPad,
              hMargin,
              PagedReader.bottomPad,
            ),
            child: _buildBody(),
          ),
        ),
        // 点按分区放页内顶层覆盖：比外层 SelectionArea 更深，点按必胜；
        // 覆盖层只注册 tap——长按选词、PageView 横向拖动照常竞胜。
        // nav 页除外（覆盖层会吃掉按钮点击）。
        if (!hasNav)
          Positioned.fill(
            child: LayoutBuilder(builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  final x = details.localPosition.dx / constraints.maxWidth;
                  onTapZone(x < 0.25 ? -1 : (x > 0.75 ? 1 : 0));
                },
              );
            }),
          ),
      ],
    );
  }

  Widget _buildBody() {
    // 插图独占页：占满内容区等比缩放。
    if (page.slices.length == 1 &&
        page.slices.single.kind == PageSliceKind.image) {
      return Center(child: _image(page.slices.single.imageUrl!));
    }
    // 内容已按页高装填；NeverScrollable 滚动容器兜底裁切测量误差
    // （单行高于整页等极端情形），避免 debug overflow 警示。
    return ClipRect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final slice in page.slices) _sliceWidget(slice)],
        ),
      ),
    );
  }

  Widget _sliceWidget(PageSlice slice) {
    switch (slice.kind) {
      case PageSliceKind.header:
        // 与 reader_page._buildBookHeader 同构；family 显式取正文字体
        // 以与分页测量一致（主题 fontFamily 本就是 activeFamily）。
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              Text(
                display(meta.title),
                textAlign: TextAlign.center,
                textScaler: textScaler,
                style: readerHeaderTitleStyle(
                  fontFamily: baseStyle.fontFamily,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 10),
              const BrushUnderline(width: 96, thickness: 3, seed: 29),
              const SizedBox(height: 10),
              Text(
                display(meta.author),
                textAlign: TextAlign.center,
                textScaler: textScaler,
                style: readerHeaderAuthorStyle(
                  fontFamily: baseStyle.fontFamily,
                  color: colors.mutedForeground,
                ),
              ),
            ],
          ),
        );
      case PageSliceKind.title:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Text(
                slice.text!,
                textAlign: TextAlign.center,
                textScaler: textScaler,
                style: readerBtStyle(baseStyle),
              ),
              const SizedBox(height: 10),
              const BrushUnderline(width: 72, thickness: 2.8, seed: 13),
            ],
          ),
        );
      case PageSliceKind.subtitle:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            slice.text!,
            textAlign: TextAlign.center,
            textScaler: textScaler,
            style: readerBmStyle(baseStyle),
          ),
        );
      case PageSliceKind.text:
        final shown = slice.sliceText;
        final span = buildHighlightedTextSpan(
          shown: shown,
          needle: needle,
          baseStyle: baseStyle,
          highlightBackground: ink.sealRed.withValues(alpha: 0.22),
          foreground: colors.foreground,
          bold: false, // 加粗会改变折行，偏离分页测量
        );
        final text = span == null
            ? Text(shown, style: baseStyle, textScaler: textScaler)
            : Text.rich(span, textScaler: textScaler);
        return slice.paddingAfter > 0
            ? Padding(
                padding: EdgeInsets.only(bottom: slice.paddingAfter),
                child: text,
              )
            : text;
      case PageSliceKind.image:
        // 正常走独占页分支；此处兜底。
        return _image(slice.imageUrl!);
      case PageSliceKind.nav:
        return PrevNextNav(meta: meta);
    }
  }

  Widget _image(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (_, __) => const SizedBox(
        height: 120,
        child: Center(child: EnsoLoading()),
      ),
      errorWidget: (_, __, ___) => Icon(
        Icons.broken_image_outlined,
        color: colors.mutedForeground,
      ),
    );
  }
}
