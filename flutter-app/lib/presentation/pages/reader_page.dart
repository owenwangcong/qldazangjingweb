import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/ink/ink.dart';
import '../../core/pagination/paragraph_text.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/book_entities.dart';
import '../../domain/repositories/repositories.dart';
import '../providers/app_providers.dart';
import '../widgets/lexicon_result_sheet.dart';
import '../widgets/paged_reader.dart';
import '../widgets/reader_settings_sheet.dart';
import '../widgets/reader_text_utils.dart';
import '../widgets/t_text.dart';

final _bookProvider = StreamProvider.family<BookData?, String>(
  (ref, bookId) => ref.watch(bookRepositoryProvider).watchBook(bookId),
);

final _isFavoriteProvider = StreamProvider.family<bool, String>(
  (ref, bookId) => ref
      .watch(studyRepositoryProvider)
      .watchFavorites()
      .map((favs) => favs.any((f) => f.bookId == bookId)),
);

/// 阅读器（web `/books/[id]` 的移动端重构）。
///
/// 交互转换：
/// - 划词右键菜单 → SelectionArea 自定义选择工具条（复制/字典/今译/释义/笔记）
/// - 悬浮 Header 隐/显 → 随滚动方向自动隐藏/出现的 AppBar
/// - 书签段落跟踪 → 首个可见块索引（ItemPositionsListener）
/// - PDF 下载 → 离线缓存（书已读即缓存，可分享文本）
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.bookId,
    this.initialBlockIndex,
    this.highlightText,
  });

  final String bookId;
  final int? initialBlockIndex;
  final String? highlightText;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();

  BookFetchOutcome? _fetchOutcome;
  bool _chromeVisible = true;
  String _selectedText = '';
  int _firstVisibleBlock = 0;

  /// 当前阅读块（两种模式共用的位置锚点）：滚动模式 = 首个可见块，
  /// 翻页模式 = 当前页首块；进度恢复/书签/模式互切都从这里取。
  int? _currentBlock;
  Timer? _progressDebounce;

  /// 翻页模式：块级跳转句柄（TOC/书签/进度恢复）+ 页码角标数据。
  final _pagedController = PagedReaderController();
  final _pageInfo = ValueNotifier<(int, int, bool)?>(null);

  /// 卷轴式进度（P3.4）：0–1，由可见块推进；ValueNotifier 避免整页 setState。
  final _readProgress = ValueNotifier<double>(0);
  int _totalItems = 1;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final study = ref.read(studyRepositoryProvider);
    unawaited(study.recordVisit(widget.bookId));

    // Restore reading progress unless an explicit anchor was requested.
    if (widget.initialBlockIndex == null && widget.highlightText == null) {
      final progress = await study.getProgress(widget.bookId);
      if (mounted && progress != null && progress.blockIndex > 0) {
        setState(() => _currentBlock ??= progress.blockIndex);
        // The list may already be built (cache hit renders instantly) — in
        // that case initialScrollIndex is stale, so jump explicitly.
        if (_itemScrollController.isAttached) {
          _itemScrollController.jumpTo(index: progress.blockIndex + 1);
        }
        // 翻页模式：视图可能先于进度读取建成（同滚动模式的竞态）；
        // jumpToBlock 在排版未到达时自动挂起。
        if (ref.read(settingsProvider).isPaged) {
          _pagedController.jumpToBlock(progress.blockIndex);
        }
      }
    }

    // Local-first fetch: cache hit renders instantly; otherwise download or
    // queue for when the network returns.
    final outcome =
        await ref.read(bookRepositoryProvider).ensureCached(widget.bookId);
    if (mounted) setState(() => _fetchOutcome = outcome);
  }

  @override
  void dispose() {
    _progressDebounce?.cancel();
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    _readProgress.dispose();
    _pageInfo.dispose();
    super.dispose();
  }

  void _onPositionsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final last = positions
        .reduce((a, b) => a.index > b.index ? a : b)
        .index;
    _readProgress.value =
        _totalItems <= 1 ? 0 : (last / (_totalItems - 1)).clamp(0.0, 1.0);
    final first = positions
        .where((p) => p.itemTrailingEdge > 0)
        .reduce((a, b) => a.index < b.index ? a : b)
        .index;
    if (first != _firstVisibleBlock) {
      _firstVisibleBlock = first;
      _currentBlock = first <= 0 ? 0 : first - 1;
      _progressDebounce?.cancel();
      _progressDebounce = Timer(const Duration(seconds: 1), () {
        ref
            .read(studyRepositoryProvider)
            .saveProgress(widget.bookId, _firstVisibleBlock);
      });
    }
  }

  /// 翻页模式上报当前页首块：更新共用锚点 + 防抖落盘进度。
  void _onPagedBlockChanged(int blockIndex) {
    _currentBlock = blockIndex;
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(seconds: 1), () {
      ref.read(studyRepositoryProvider).saveProgress(widget.bookId, blockIndex);
    });
  }

  /// 打开/切换模式时的目标块。已有真实阅读位置（用户滚动/翻页过，或进度
  /// 已恢复）时优先——否则从搜索进入、读了半卷再切模式会跳回命中处；
  /// 首次打开 _currentBlock 为 null，自然落到路由 ?index → 搜索命中。
  int? _anchorBlockFor(BookData book) {
    if (_currentBlock != null) return _currentBlock;
    int? block;
    if (widget.initialBlockIndex != null) {
      block = widget.initialBlockIndex!.clamp(0, book.blocks.length - 1);
    } else if (widget.highlightText != null) {
      final converter = ref.read(chineseConverterProvider);
      final needle = converter.normalizeQuery(widget.highlightText!);
      final idx = book.blocks.indexWhere(
        (b) => b.paragraphs.any((p) => p.contains(needle)),
      );
      if (idx >= 0) block = idx;
    }
    return block;
  }

  /// Item index in the positioned list (block index + 1 for the header item;
  /// 0 shows the book header itself).
  int _initialItemIndex(BookData book) {
    final block = _anchorBlockFor(book);
    if (block == null || block <= 0) return 0;
    return block.clamp(0, book.blocks.length - 1) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bookAsync = ref.watch(_bookProvider(widget.bookId));
    final book = bookAsync.value;

    return Scaffold(
      // 笔记弹窗的键盘不压缩 body（翻页模式重排无谓触发；笔记 sheet 自身
      // 已 pad viewInsets，对滚动模式亦无害）。
      resizeToAvoidBottomInset: false,
      // 背景由 InkPaperBacking（路由统一垫纸）提供，保持透明让纸纹透出。
      body: book == null
          ? SafeArea(child: _buildLoadingOrOffline(colors))
          : _buildReader(context, book, colors),
    );
  }

  // ---- Empty / loading / offline states ------------------------------------

  Widget _buildLoadingOrOffline(AppColors colors) {
    final display = ref.watch(displayTextProvider);
    final online = ref.watch(isOnlineProvider).value ?? true;
    final queued = _fetchOutcome == BookFetchOutcome.queuedOffline ||
        _fetchOutcome == BookFetchOutcome.failed;

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: BackButton(onPressed: () => context.pop()),
        ),
        Expanded(
          child: Center(
            child: (!queued)
                ? const EnsoLoading()
                : Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          online ? Icons.error_outline : Icons.cloud_off,
                          size: 48,
                          color: colors.mutedForeground,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          display(online
                              ? '加载失败，已加入后台重试队列'
                              : '本书尚未离线缓存\n已加入下载队列，联网后自动下载'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: colors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () async {
                            setState(() => _fetchOutcome = null);
                            final outcome = await ref
                                .read(bookRepositoryProvider)
                                .ensureCached(widget.bookId);
                            if (mounted) {
                              setState(() => _fetchOutcome = outcome);
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(display('立即重试')),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ---- Reader body ----------------------------------------------------------

  Widget _buildReader(BuildContext context, BookData book, AppColors colors) {
    final settings = ref.watch(settingsProvider);
    final display = ref.watch(displayTextProvider);
    final ink = context.ink;
    final isFavorite =
        ref.watch(_isFavoriteProvider(widget.bookId)).value ?? false;
    _totalItems = book.blocks.length + 2;

    final baseStyle = TextStyle(
      // Bare TextStyle doesn't inherit the theme's fontFamily — set it here.
      fontFamily: ref.watch(fontControllerProvider).activeFamily,
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      letterSpacing: settings.letterSpacingEm * settings.fontSize,
      color: colors.foreground,
    );

    // 留白（设计八则 #1）：正文边距 ≥20dp；宽屏（≥600dp）≥10% 屏宽。
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hMargin = screenWidth >= 600 ? screenWidth * 0.10 : 20.0;

    final isPaged = settings.isPaged;

    return Stack(
      children: [
        SafeArea(
          child: isPaged
              ? PagedReader(
                  bookId: widget.bookId,
                  book: book,
                  anchorBlockIndex: _anchorBlockFor(book),
                  highlightText: widget.highlightText,
                  controller: _pagedController,
                  onBlockChanged: _onPagedBlockChanged,
                  onProgress: (p) => _readProgress.value = p,
                  onPageInfo: (current, total, done) =>
                      _pageInfo.value = (current, total, done),
                  onSelectionChanged: (text) => _selectedText = text,
                  contextMenuBuilder: _buildSelectionToolbar,
                  // 翻页无滚动方向信号：中区点按显隐 chrome。
                  onToggleChrome: () =>
                      setState(() => _chromeVisible = !_chromeVisible),
                )
              // 滚动方向驱动 chrome 显隐——仅滚动分支挂监听，避免
              // PageView 的横向滚动误触发。
              : NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (notification.direction == ScrollDirection.reverse &&
                        _chromeVisible) {
                      setState(() => _chromeVisible = false);
                    } else if (notification.direction ==
                            ScrollDirection.forward &&
                        !_chromeVisible) {
                      setState(() => _chromeVisible = true);
                    }
                    return false;
                  },
                  child: SelectionArea(
                    onSelectionChanged: (content) =>
                        _selectedText = content?.plainText ?? '',
                    contextMenuBuilder: (context, selectableRegionState) =>
                        _buildSelectionToolbar(
                            context, selectableRegionState),
                    child: ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      initialScrollIndex: _initialItemIndex(book),
                      padding: EdgeInsets.only(
                        top: kToolbarHeight + 16,
                        bottom: 48,
                        left: hMargin,
                        right: hMargin,
                      ),
                      itemCount: book.blocks.length + 2,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildBookHeader(book, colors);
                        }
                        if (index == book.blocks.length + 1) {
                          return PrevNextNav(meta: book.meta);
                        }
                        return _BlockView(
                          block: book.blocks[index - 1],
                          baseStyle: baseStyle,
                          paragraphSpacing: settings.paragraphSpacing,
                          display: display,
                          highlight: widget.highlightText,
                          colors: colors,
                          ink: ink,
                        );
                      },
                    ),
                  ),
                ),
        ),
        // Auto-hiding app bar (mobile replacement for web's 隐/显 toggle).
        AnimatedSlide(
          offset: _chromeVisible ? Offset.zero : const Offset(0, -1.2),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _buildAppBar(book, colors, display, isFavorite),
        ),
        // 卷轴式进度（P3.4）：底缘一线墨痕 + 朱砂卷轴杆；翻页模式附页码。
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPaged)
                    ValueListenableBuilder<(int, int, bool)?>(
                      valueListenable: _pageInfo,
                      builder: (context, info, _) => info == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                display(
                                    '第 ${info.$1} / ${info.$2}${info.$3 ? '' : '+'} 页'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.mutedForeground,
                                ),
                              ),
                            ),
                    ),
                  ValueListenableBuilder<double>(
                    valueListenable: _readProgress,
                    builder: (context, progress, _) => CustomPaint(
                      size: const Size(double.infinity, 10),
                      painter:
                          _ScrollRollPainter(progress: progress, ink: ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(
    BookData book,
    AppColors colors,
    String Function(String) display,
    bool isFavorite,
  ) {
    // 墨晕代替 Material elevation（设计八则 #2）；底缘干笔一道收口。
    return Material(
      color: colors.background.withValues(alpha: 0.96),
      child: SafeArea(
        bottom: false,
        child: _InkToolbar(
          child: Row(
            children: [
              BackButton(onPressed: () => context.pop()),
              Expanded(
                child: Text(
                  display(book.meta.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
              ),
              IconButton(
                tooltip: '收藏',
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => _toggleFavorite(isFavorite, display),
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  semanticLabel: isFavorite ? '取消收藏' : '收藏',
                  color: isFavorite ? colors.destructive : colors.foreground,
                ),
              ),
              IconButton(
                tooltip: '添加书签',
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => _addBookmark(book, display),
                icon: const Icon(Icons.bookmark_add_outlined, semanticLabel: '添加书签'),
              ),
              IconButton(
                tooltip: '目录',
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => _showToc(book),
                icon: const Icon(Icons.toc, semanticLabel: '目录'),
              ),
              IconButton(
                tooltip: '阅读设置',
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => showReaderSettingsSheet(context),
                icon: const Icon(Icons.text_fields, semanticLabel: '阅读设置'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookHeader(BookData book, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          TText(
            book.meta.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.5,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 10),
          const BrushUnderline(width: 96, thickness: 3, seed: 29),
          const SizedBox(height: 10),
          TText(
            book.meta.author,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }

  // ---- Selection toolbar (web右键菜单 → mobile 选择工具条) -------------------

  Widget _buildSelectionToolbar(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final display = ref.read(displayTextProvider);

    void run(void Function(String text) action) {
      final text = _selectedText.trim();
      selectableRegionState.hideToolbar();
      if (text.isEmpty) return;
      action(text);
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: [
        ContextMenuButtonItem(
          label: display('复制'),
          onPressed: () => run((text) {
            Clipboard.setData(ClipboardData(text: text));
            _toast(display('已复制'));
          }),
        ),
        ContextMenuButtonItem(
          label: display('字典'),
          onPressed: () => run((text) => showLexiconResultSheet(
                context,
                ref,
                action: LexiconAction.dictionary,
                selectedText: text,
              )),
        ),
        ContextMenuButtonItem(
          label: display('今译'),
          onPressed: () => run((text) => showLexiconResultSheet(
                context,
                ref,
                action: LexiconAction.toModernChinese,
                selectedText: text,
              )),
        ),
        ContextMenuButtonItem(
          label: display('释义'),
          onPressed: () => run((text) => showLexiconResultSheet(
                context,
                ref,
                action: LexiconAction.explain,
                selectedText: text,
              )),
        ),
        ContextMenuButtonItem(
          label: display('笔记'),
          onPressed: () => run(_showNoteComposer),
        ),
      ],
    );
  }

  // ---- Actions ---------------------------------------------------------------

  Future<void> _toggleFavorite(
    bool isFavorite,
    String Function(String) display,
  ) async {
    HapticFeedback.lightImpact(); // P4.3：收藏轻震
    final study = ref.read(studyRepositoryProvider);
    if (isFavorite) {
      await study.removeFavorite(widget.bookId);
      _toast(display('已从收藏中移除'));
    } else {
      await study.addFavorite(widget.bookId);
      _toast(display('已添加到收藏'));
    }
  }

  Future<void> _addBookmark(
    BookData book,
    String Function(String) display,
  ) async {
    HapticFeedback.lightImpact(); // P4.3：落签轻震
    // Anchor on the first visible block — same semantics as the web's
    // IntersectionObserver-driven currentPartId. 翻页模式取当前页首块。
    final blockIndex = ref.read(settingsProvider).isPaged
        ? (_currentBlock ?? 0).clamp(0, book.blocks.length - 1)
        : (_firstVisibleBlock - 1).clamp(0, book.blocks.length - 1);
    final block = book.blocks[blockIndex];
    final text = block.paragraphs.join();
    final label = text.substring(0, text.length < 16 ? text.length : 16);
    await ref.read(studyRepositoryProvider).addBookmark(
          bookId: widget.bookId,
          partId: 'part-${block.id}-0',
          blockIndex: blockIndex,
          content: label,
        );
    _toast('${display('已添加书签')}: $label…');
  }

  void _showToc(BookData book) {
    final colors = context.colors;
    final entries = <({int index, String title})>[];
    for (var i = 0; i < book.blocks.length; i++) {
      final block = book.blocks[i];
      if (block.type == JuanBlockType.bt && block.paragraphs.isNotEmpty) {
        entries.add((index: i, title: block.paragraphs.first.trim()));
      }
    }
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: entries.length,
        itemBuilder: (_, i) => ListTile(
          minTileHeight: 48,
          title: TText(
            entries[i].title,
            style: TextStyle(fontSize: 15, color: colors.foreground),
          ),
          onTap: () {
            Navigator.pop(sheetContext);
            if (ref.read(settingsProvider).isPaged) {
              _pagedController.jumpToBlock(entries[i].index);
              return;
            }
            // +1 for the header item in the list.
            _itemScrollController.scrollTo(
              index: entries[i].index + 1,
              duration: const Duration(milliseconds: 300),
            );
          },
        ),
      ),
    );
  }

  void _showNoteComposer(String quote) {
    final display = ref.read(displayTextProvider);
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        // Keep the composer above the soft keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                display('添加笔记'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                display(quote),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                minLines: 2,
                decoration: InputDecoration(
                  hintText: display('写下你的注释…'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style:
                    FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () async {
                  final body = controller.text.trim();
                  if (body.isEmpty) return;
                  await ref.read(studyRepositoryProvider).addNote(
                        bookId: widget.bookId,
                        quote: quote,
                        body: body,
                      );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  _toast(display('已保存笔记'));
                },
                child: Text(display('保存')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }
}

// ---- Ink chrome ----------------------------------------------------------------

/// 阅读器顶栏：工具行 + 底缘干笔分隔（取代 Material elevation 阴影）。
class _InkToolbar extends StatelessWidget {
  const _InkToolbar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: kToolbarHeight, child: child),
        const BrushDivider(height: 8, seed: 19),
      ],
    );
  }
}

/// 卷轴式进度（P3.4）：底缘一线淡墨轨 + 已读段重墨 + 朱砂「卷轴杆」。
class _ScrollRollPainter extends CustomPainter {
  _ScrollRollPainter({required this.progress, required this.ink});

  final double progress;
  final InkTokens ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final y = size.height / 2;
    // 全程淡墨轨。
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = ink.inkLight.withValues(alpha: 0.30)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    final x = size.width * progress;
    // 已读段：重一档的墨。
    if (x > 0) {
      canvas.drawLine(
        Offset(0, y),
        Offset(x, y),
        Paint()
          ..color = ink.inkMedium.withValues(alpha: 0.65)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }
    // 卷轴杆：竖向小杆，朱砂点睛（本屏 sealRed 第 2 处上限内）。
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x.clamp(2, size.width - 2), y),
            width: 3.4, height: size.height),
        const Radius.circular(1.7),
      ),
      Paint()..color = ink.sealRed.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_ScrollRollPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.ink != ink;
}

// ---- Block rendering ---------------------------------------------------------

class _BlockView extends StatelessWidget {
  const _BlockView({
    required this.block,
    required this.baseStyle,
    required this.paragraphSpacing,
    required this.display,
    required this.colors,
    required this.ink,
    this.highlight,
  });

  final JuanBlock block;
  final TextStyle baseStyle;
  final double paragraphSpacing;
  final String Function(String) display;
  final AppColors colors;
  final InkTokens ink;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case JuanBlockType.bt:
        // 章节笔触标题（P3.4）：居中题字 + 笔触下划线收笔。
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Text(
                display(block.paragraphs.join().trim()),
                textAlign: TextAlign.center,
                style: baseStyle.copyWith(
                  fontSize: baseStyle.fontSize! * 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              BrushUnderline(width: 72, thickness: 2.8, seed: 13),
            ],
          ),
        );
      case JuanBlockType.bm:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            display(block.paragraphs.join().trim()),
            textAlign: TextAlign.center,
            style: baseStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        );
      case JuanBlockType.p:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final paragraph in block.paragraphs)
              Padding(
                padding: EdgeInsets.only(bottom: paragraphSpacing),
                child: _buildParagraph(paragraph),
              ),
          ],
        );
    }
  }

  Widget _buildParagraph(String raw) {
    // Mirror the web renderer: paragraphs may embed <img> tags (rare
    // illustrations); split them out and render via cached_network_image.
    // 切分/剥引号逻辑与翻页模式共享（core/pagination/paragraph_text.dart）。
    final segments = splitParagraphSegments(cleanParagraph(raw));
    if (segments.length == 1 && segments.single.text != null) {
      return _buildText(segments.single.text!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final segment in segments)
          if (segment.imageUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: CachedNetworkImage(
                imageUrl: segment.imageUrl!,
                placeholder: (_, __) => const SizedBox(
                  height: 120,
                  child: Center(child: EnsoLoading()),
                ),
                errorWidget: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  color: colors.mutedForeground,
                ),
              ),
            )
          else
            _buildText(segment.text!),
      ],
    );
  }

  Widget _buildText(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final shown = display(text);
    // 搜索跳转高亮：朱砂淡染（P3.4，替换 web 的黄色 <mark>）。
    final span = buildHighlightedTextSpan(
      shown: shown,
      needle: highlight == null ? null : display(highlight!),
      baseStyle: baseStyle,
      highlightBackground: ink.sealRed.withValues(alpha: 0.22),
      foreground: colors.foreground,
    );
    if (span == null) return Text(shown, style: baseStyle);
    return Text.rich(span);
  }
}
