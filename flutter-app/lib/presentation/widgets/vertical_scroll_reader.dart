import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/scroll_tick_sound.dart';
import '../../core/ink/ink.dart';
import '../../core/theme/app_theme.dart';
import '../../core/vertical/vertical_models.dart';
import '../../core/vertical/vertical_paginator.dart';
import '../../domain/entities/book_entities.dart';
import '../providers/app_providers.dart';
import 'block_jump_controller.dart';
import 'column_snap_physics.dart';
import 'reader_text_utils.dart';
import 'vertical_page_painter.dart';

/// 展卷音效接口（DS4 预留）：注入后在跨列反馈节流点被调用。
typedef ScrollFeedbackSound = void Function();

/// 竖排滚动（展卷）阅读视图——第 4 种阅读方式
/// （vertical-scroll-plan.md §3，决策 DS1~DS4）。
///
/// 列带向左延伸、手指左→右滑 = 前进（DS1，与真右开本一致）；
/// 与竖排翻页共享同一分页键与缓存结果——互切零重排（§2.1）。
/// 点按任意处显隐 chrome（DS3）；无页码页脚（DS2）。
class VerticalScrollReader extends ConsumerStatefulWidget {
  const VerticalScrollReader({
    super.key,
    required this.bookId,
    required this.book,
    required this.anchorBlockIndex,
    required this.controller,
    required this.onBlockChanged,
    required this.onProgress,
    required this.onToggleChrome,
    this.soundHook,
  });

  final String bookId;
  final BookData book;
  final int? anchorBlockIndex;
  final BlockJumpController controller;
  final ValueChanged<int> onBlockChanged;
  final ValueChanged<double> onProgress;
  final VoidCallback onToggleChrome;
  final ScrollFeedbackSound? soundHook;

  /// 与竖排翻页共用的上下留白（分页键 contentSize 必须一致以共享缓存）。
  static const double topPad = 16;
  static const double bottomPad = 28;

  @override
  ConsumerState<VerticalScrollReader> createState() =>
      _VerticalScrollReaderState();
}

class _VerticalScrollReaderState extends ConsumerState<VerticalScrollReader> {
  VerticalPaginationKey? _key;
  VerticalPaginationResult? _result;
  SnapMetrics? _metrics;
  ScrollController? _scroll;
  Timer? _rekeyDebounce;
  final GlyphCache _glyphs = GlyphCache();
  late final ColumnCrossFeedback _feedback;

  int _anchorBlock = 0;
  int _leadItem = 0;

  @override
  void initState() {
    super.initState();
    _anchorBlock = widget.anchorBlockIndex ?? 0;
    _feedback = ColumnCrossFeedback(trigger: _fireFeedback);
    widget.controller.attach(_handleJumpToBlock);
  }

  @override
  void didUpdateWidget(VerticalScrollReader oldWidget) {
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
    _scroll?.dispose();
    _glyphs.clear();
    super.dispose();
  }

  void _fireFeedback() {
    if (ref.read(settingsProvider).muteScrollFeedback) return;
    HapticFeedback.selectionClick();
    // 默认播内置短嗒(无马达设备上的唯一可感知反馈);soundHook 注入可覆盖。
    final hook = widget.soundHook;
    if (hook != null) {
      hook();
    } else {
      ScrollTickSound.instance.tick();
    }
  }

  // ---- 分页/度量管理（镜像 VerticalReader 的键与防抖节奏） ------------------

  void _ensurePagination(VerticalPaginationKey key,
      String Function(String) display, double contentW) {
    if (_key == key) return;
    _rekeyDebounce?.cancel();
    if (_result == null) {
      _adopt(key, display, contentW);
      return;
    }
    _rekeyDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _adopt(key, display, contentW));
    });
  }

  void _adopt(VerticalPaginationKey key, String Function(String) display,
      double contentW) {
    final result = VerticalPagination.run(
      key: key,
      book: widget.book,
      display: display,
    );
    // 条目宽表:文字列 = colPitch,插图/卷尾 = 内容区宽(§3.1)。
    final metrics = SnapMetrics([
      for (final item in result.strip)
        switch (item) {
          StripColumn() => result.grid.colPitch,
          StripImage() || StripNav() => contentW,
        },
    ]);
    _key = key;
    _result = result;
    _metrics = metrics;
    _leadItem = result.stripItemForBlock(_anchorBlock);
    _feedback.rebase();

    final old = _scroll;
    _scroll = ScrollController(
        initialScrollOffset: metrics.offsetOf(_leadItem));
    _scroll!.addListener(_onScroll);
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_result, result)) _notifyShell();
    });
  }

  void _onScroll() {
    final scroll = _scroll;
    final result = _result;
    final metrics = _metrics;
    if (scroll == null || result == null || metrics == null) return;
    if (!scroll.hasClients) return;
    final lead = metrics.indexAt(scroll.offset);
    if (lead != _leadItem) {
      _leadItem = lead;
      _anchorBlock = result.blockForStripItem(lead);
      widget.onBlockChanged(_anchorBlock);
    }
    _feedback.onLead(lead);
    _notifyShell();
  }

  void _notifyShell() {
    final scroll = _scroll;
    if (scroll == null || !scroll.hasClients) {
      widget.onProgress(0);
      return;
    }
    final max = scroll.position.maxScrollExtent;
    widget.onProgress(
        max <= 0 ? 1.0 : (scroll.offset / max).clamp(0.0, 1.0));
  }

  void _handleJumpToBlock(int blockIndex) {
    final result = _result;
    final metrics = _metrics;
    if (result == null || metrics == null) {
      _anchorBlock = blockIndex < 0 ? 0 : blockIndex;
      return;
    }
    final item = result.stripItemForBlock(blockIndex);
    final scroll = _scroll;
    var target = metrics.offsetOf(item);
    if (scroll != null && scroll.hasClients) {
      target = target.clamp(0.0, scroll.position.maxScrollExtent);
      _feedback.rebase();
      scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // ---- 视图 -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final fontState = ref.watch(fontControllerProvider);
    final display = ref.watch(displayTextProvider);
    final colors = context.colors;

    return LayoutBuilder(builder: (context, constraints) {
      // 留白规则与其余模式一致;contentSize 与竖排翻页逐分量相同 →
      // 分页键相同 → 缓存共享,翻页⇄展卷互切零重排(§2.1)。
      final screenWidth = MediaQuery.sizeOf(context).width;
      final hMargin = screenWidth >= 600 ? screenWidth * 0.10 : 20.0;
      final scaler = MediaQuery.textScalerOf(context);
      final scaleFactor = scaler.scale(settings.fontSize) / settings.fontSize;
      final contentW =
          (constraints.maxWidth - 2 * hMargin).clamp(1.0, double.infinity);
      final contentSize = Size(
        contentW,
        (constraints.maxHeight -
                VerticalScrollReader.topPad -
                VerticalScrollReader.bottomPad)
            .clamp(1.0, double.infinity),
      );
      _ensurePagination(
        VerticalPaginationKey(
          bookId: widget.bookId,
          contentSize: contentSize,
          fontFamily: fontState.activeFamily ?? '',
          fontSize: settings.fontSize,
          lineHeight: settings.effectiveVerticalColumnPitch,
          letterSpacingEm: settings.effectiveVerticalCharGapEm,
          isSimplified: settings.isSimplified,
          baiwen: settings.baiwenMode,
          textScaleFactor: scaleFactor,
        ),
        display,
        contentW,
      );

      final result = _result!;
      final metrics = _metrics!;
      final styles = VerticalPageStyles(
        fontFamily: fontState.activeFamily,
        fontSize: result.grid.fontSize,
        gap: result.grid.gap,
        foreground: colors.foreground,
        muted: colors.mutedForeground,
      );
      final dpr = MediaQuery.devicePixelRatioOf(context);

      return Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hMargin),
              child: ListView.builder(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                reverse: true, // DS1:列带向左延伸,左→右滑=前进。
                physics: ColumnSnapPhysics(metrics: metrics),
                itemExtentBuilder: (index, _) => metrics.extentOf(index),
                cacheExtent: contentW * 2,
                itemCount: result.strip.length,
                itemBuilder: (context, index) => _buildItem(
                    result.strip[index],
                    index,
                    result,
                    styles,
                    settings.showColumnRules,
                    colors,
                    dpr,
                    contentW),
              ),
            ),
          ),
          // DS3:点按任意处显隐 chrome(translucent 不抢拖动)。
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onToggleChrome,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildItem(
    VStripItem item,
    int index,
    VerticalPaginationResult result,
    VerticalPageStyles styles,
    bool showRules,
    AppColors colors,
    double dpr,
    double contentW,
  ) {
    final pad = const EdgeInsets.only(
      top: VerticalScrollReader.topPad,
      bottom: VerticalScrollReader.bottomPad,
    );
    switch (item) {
      case StripColumn(:final column):
        return Padding(
          padding: pad,
          child: CustomPaint(
            size: Size(result.grid.colPitch, double.infinity),
            painter: VerticalColumnPainter(
              column: column,
              grid: result.grid,
              styles: styles,
              glyphs: _glyphs,
              // 列隙界线在条目右侧;列带首列(最右)不画,两端语义与翻页一致。
              showRule: showRules && index > 0,
              ruleColor: colors.foreground.withValues(alpha: 0.28),
              ruleStrokeWidth: 1 / dpr,
            ),
          ),
        );
      case StripImage(:final imageUrl):
        return Padding(
          padding: pad,
          child: SizedBox(
            width: contentW,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
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
            ),
          ),
        );
      case StripNav():
        return Padding(
          padding: pad,
          child: SizedBox(
            width: contentW,
            child: Center(child: PrevNextNav(meta: widget.book.meta)),
          ),
        );
    }
  }
}
