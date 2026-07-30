import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ink/ink.dart';
import '../../core/theme/app_theme.dart';
import '../../core/vertical/vertical_models.dart';
import '../../core/vertical/vertical_paginator.dart';
import '../../domain/entities/book_entities.dart';
import '../providers/app_providers.dart';
import 'block_jump_controller.dart';
import 'reader_text_utils.dart';
import 'vertical_page_painter.dart';

/// 古籍竖排阅读视图（实施方案 §8，验收 C9）。
///
/// 真右开本（D1）：PageView(reverse: true)，页索引向左增长——
/// 手指左→右滑 = 下一页；点按分区与横排**镜像**（左 25% = 下一页）。
/// 分页为同步纯算术，无「排版中」状态；跳转即时生效。
/// v1 纯阅读（D3）：无文字选择，手势树无识别器竞争。
class VerticalReader extends ConsumerStatefulWidget {
  const VerticalReader({
    super.key,
    required this.bookId,
    required this.book,
    required this.anchorBlockIndex,
    required this.controller,
    required this.onBlockChanged,
    required this.onProgress,
    required this.onPageInfo,
    required this.onToggleChrome,
  });

  final String bookId;
  final BookData book;

  /// 初始锚点块（模式互切/进度恢复时的当前块）；null = 卷首。
  final int? anchorBlockIndex;
  final BlockJumpController controller;
  final ValueChanged<int> onBlockChanged;
  final ValueChanged<double> onProgress;
  final void Function(int current, int total, bool done) onPageInfo;
  final VoidCallback onToggleChrome;

  /// 页面上下留白（与横排一致；底部为卷轴进度条留呼吸）。
  static const double topPad = 16;
  static const double bottomPad = 28;

  @override
  ConsumerState<VerticalReader> createState() => _VerticalReaderState();
}

class _VerticalReaderState extends ConsumerState<VerticalReader> {
  VerticalPaginationKey? _key;
  VerticalPaginationResult? _result;
  PageController? _pageController;
  Timer? _rekeyDebounce;
  final GlyphCache _glyphs = GlyphCache();

  int _anchorBlock = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _anchorBlock = widget.anchorBlockIndex ?? 0;
    widget.controller.attach(_handleJumpToBlock);
  }

  @override
  void didUpdateWidget(VerticalReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.detach(_handleJumpToBlock);
      widget.controller.attach(_handleJumpToBlock);
    }
  }

  @override
  void dispose() {
    widget.controller.detach(_handleJumpToBlock);
    _rekeyDebounce?.cancel();
    _pageController?.dispose();
    _glyphs.clear();
    super.dispose();
  }

  // ---- 分页管理（同步；键变化防抖沿用横排节奏） ------------------------------

  void _ensurePagination(
      VerticalPaginationKey key, String Function(String) display) {
    if (_key == key) return;
    _rekeyDebounce?.cancel();

    if (_result == null) {
      // 首次：同步算出即可渲染本帧（纯算术 <10ms）；仅赋值不 setState。
      _adopt(key, display, notify: false);
      return;
    }
    // 设置滑杆/旋转连发 key 变化：250ms 防抖，期间旧结果继续显示。
    _rekeyDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _adopt(key, display, notify: true));
    });
  }

  void _adopt(VerticalPaginationKey key, String Function(String) display,
      {required bool notify}) {
    final result = VerticalPagination.run(
      key: key,
      book: widget.book,
      display: display,
    );
    _key = key;
    _result = result;
    _currentPage = result.pageForBlock(_anchorBlock);
    final old = _pageController;
    _pageController = PageController(initialPage: _currentPage);
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    // 回调不得落在 build/layout 里，统一延至帧末。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_result, result)) _notifyShell();
    });
  }

  void _notifyShell() {
    final r = _result;
    if (r == null) return;
    final total = r.pages.isEmpty ? 1 : r.pages.length;
    widget.onPageInfo((_currentPage + 1).clamp(1, total), total, true);
    widget.onProgress(
      total <= 1 ? 1.0 : (_currentPage.clamp(0, total - 1) / (total - 1)),
    );
  }

  // ---- 导航 -------------------------------------------------------------------

  void _handleJumpToBlock(int blockIndex) {
    final r = _result;
    if (r == null) {
      _anchorBlock = blockIndex < 0 ? 0 : blockIndex;
      return;
    }
    _animateToPage(r.pageForBlock(blockIndex));
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
      setState(() {
        _currentPage = page;
        final old = _pageController;
        _pageController = PageController(initialPage: page);
        if (old != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
        }
        final r = _result;
        if (r != null) _anchorBlock = r.blockForPage(page);
        _notifyShell();
      });
    }
  }

  void _turnPage(int delta) {
    final r = _result;
    final controller = _pageController;
    if (r == null || controller == null || !controller.hasClients) return;
    final target = (_currentPage + delta).clamp(0, r.pages.length - 1);
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
    _anchorBlock = r.blockForPage(page);
    widget.onBlockChanged(_anchorBlock);
    _notifyShell();
  }

  // ---- 视图 -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final fontState = ref.watch(fontControllerProvider);
    final display = ref.watch(displayTextProvider);
    final colors = context.colors;

    return LayoutBuilder(builder: (context, constraints) {
      // 留白规则与横排一致（≥600dp 宽 → 10% 屏宽）。
      final screenWidth = MediaQuery.sizeOf(context).width;
      final hMargin = screenWidth >= 600 ? screenWidth * 0.10 : 20.0;
      final scaler = MediaQuery.textScalerOf(context);
      // 竖排独立字号（默认大于横排,见 AppSettings.verticalFontSize）。
      final fontSize = settings.effectiveVerticalFontSize;
      final scaleFactor = scaler.scale(fontSize) / fontSize;
      final contentSize = Size(
        (constraints.maxWidth - 2 * hMargin).clamp(1.0, double.infinity),
        (constraints.maxHeight - VerticalReader.topPad - VerticalReader.bottomPad)
            .clamp(1.0, double.infinity),
      );
      _ensurePagination(
        VerticalPaginationKey(
          bookId: widget.bookId,
          contentSize: contentSize,
          fontFamily: fontState.activeFamily ?? '',
          fontSize: fontSize,
          // 竖排独立间距（D6 设置项）：行间=列距倍率、字间=列内字距，
          // 与横排的 lineHeight/letterSpacing 语义解耦。
          lineHeight: settings.effectiveVerticalColumnPitch,
          letterSpacingEm: settings.effectiveVerticalCharGapEm,
          isSimplified: settings.isSimplified,
          baiwen: settings.baiwenMode,
          textScaleFactor: scaleFactor,
        ),
        display,
      );

      final result = _result!;
      final styles = VerticalPageStyles(
        fontFamily: fontState.activeFamily,
        fontSize: result.grid.fontSize,
        gap: result.grid.gap,
        foreground: colors.foreground,
        muted: colors.mutedForeground,
        strokeWidthEm: settings.fontWeightStrokeEm,
      );
      final dpr = MediaQuery.devicePixelRatioOf(context);

      return PageView.builder(
        controller: _pageController,
        reverse: true, // 真右开本（D1）：下一页在左，手指左→右滑前进。
        allowImplicitScrolling: true,
        onPageChanged: _onPageChanged,
        itemCount: result.pages.length,
        itemBuilder: (context, index) {
          final page = result.pages[index];
          return _buildPage(page, result, styles, settings.showColumnRules,
              colors, hMargin, dpr);
        },
      );
    });
  }

  Widget _buildPage(
    VPage page,
    VerticalPaginationResult result,
    VerticalPageStyles styles,
    bool showRules,
    AppColors colors,
    double hMargin,
    double dpr,
  ) {
    final Widget body;
    if (page.imageUrl != null) {
      body = Center(
        child: CachedNetworkImage(
          imageUrl: page.imageUrl!,
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox(
            height: 120,
            child: Center(child: EnsoLoading()),
          ),
          errorWidget: (_, __, ___) => Icon(
            Icons.broken_image_outlined,
            color: colors.mutedForeground,
          ),
        ),
      );
    } else if (page.isNavPage) {
      body = Center(child: PrevNextNav(meta: widget.book.meta));
    } else {
      body = RepaintBoundary(
        child: CustomPaint(
          isComplex: true,
          size: Size.infinite,
          painter: VerticalPagePainter(
            page: page,
            grid: result.grid,
            styles: styles,
            glyphs: _glyphs,
            showColumnRules: showRules,
            ruleColor: colors.foreground.withValues(alpha: 0.28),
            ruleStrokeWidth: 1 / dpr,
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              hMargin,
              VerticalReader.topPad,
              hMargin,
              VerticalReader.bottomPad,
            ),
            child: body,
          ),
        ),
        // 点按分区与横排镜像（下一页在左）：左 25% 下一页、右 25% 上一页、
        // 中部显隐 chrome。nav 页除外（覆盖层会吃掉按钮点击）。
        if (!page.isNavPage)
          Positioned.fill(
            child: LayoutBuilder(builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  final x = details.localPosition.dx / constraints.maxWidth;
                  if (x < 0.25) {
                    _turnPage(1);
                  } else if (x > 0.75) {
                    _turnPage(-1);
                  } else {
                    widget.onToggleChrome();
                  }
                },
              );
            }),
          ),
      ],
    );
  }
}
