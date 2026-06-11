import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/book_entities.dart';
import '../../domain/repositories/repositories.dart';
import '../providers/app_providers.dart';
import '../widgets/lexicon_result_sheet.dart';
import '../widgets/reader_settings_sheet.dart';
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
  int? _restoredIndex;
  Timer? _progressDebounce;

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
        setState(() => _restoredIndex = progress.blockIndex);
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
    super.dispose();
  }

  void _onPositionsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final first = positions
        .where((p) => p.itemTrailingEdge > 0)
        .reduce((a, b) => a.index < b.index ? a : b)
        .index;
    if (first != _firstVisibleBlock) {
      _firstVisibleBlock = first;
      _progressDebounce?.cancel();
      _progressDebounce = Timer(const Duration(seconds: 1), () {
        ref
            .read(studyRepositoryProvider)
            .saveProgress(widget.bookId, _firstVisibleBlock);
      });
    }
  }

  int _initialIndex(BookData book) {
    if (widget.initialBlockIndex != null) {
      return widget.initialBlockIndex!.clamp(0, book.blocks.length - 1);
    }
    if (widget.highlightText != null) {
      final converter = ref.read(chineseConverterProvider);
      final needle = converter.normalizeQuery(widget.highlightText!);
      final idx = book.blocks.indexWhere(
        (b) => b.paragraphs.any((p) => p.contains(needle)),
      );
      if (idx >= 0) return idx;
    }
    return (_restoredIndex ?? 0).clamp(0, book.blocks.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bookAsync = ref.watch(_bookProvider(widget.bookId));
    final book = bookAsync.value;

    return Scaffold(
      backgroundColor: colors.background,
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
                ? const CircularProgressIndicator()
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
    final isFavorite =
        ref.watch(_isFavoriteProvider(widget.bookId)).value ?? false;

    final baseStyle = TextStyle(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      letterSpacing: settings.letterSpacingEm * settings.fontSize,
      color: colors.foreground,
    );

    return Stack(
      children: [
        SafeArea(
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.reverse &&
                  _chromeVisible) {
                setState(() => _chromeVisible = false);
              } else if (notification.direction == ScrollDirection.forward &&
                  !_chromeVisible) {
                setState(() => _chromeVisible = true);
              }
              return false;
            },
            child: SelectionArea(
              onSelectionChanged: (content) =>
                  _selectedText = content?.plainText ?? '',
              contextMenuBuilder: (context, selectableRegionState) =>
                  _buildSelectionToolbar(context, selectableRegionState),
              child: ScrollablePositionedList.builder(
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                initialScrollIndex: _initialIndex(book),
                padding: EdgeInsets.only(
                  top: kToolbarHeight + 16,
                  bottom: 48,
                  left: 20,
                  right: 20,
                ),
                itemCount: book.blocks.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildBookHeader(book, colors);
                  if (index == book.blocks.length + 1) {
                    return _buildPrevNext(book, colors);
                  }
                  return _BlockView(
                    block: book.blocks[index - 1],
                    baseStyle: baseStyle,
                    paragraphSpacing: settings.paragraphSpacing,
                    display: display,
                    highlight: widget.highlightText,
                    colors: colors,
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
          child: _buildAppBar(book, colors, display, isFavorite),
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
    return Material(
      color: colors.background.withValues(alpha: 0.96),
      elevation: 1,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
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
                  color: isFavorite ? colors.destructive : colors.foreground,
                ),
              ),
              IconButton(
                tooltip: '添加书签',
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => _addBookmark(book, display),
                icon: const Icon(Icons.bookmark_add_outlined),
              ),
              IconButton(
                tooltip: '目录',
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => _showToc(book),
                icon: const Icon(Icons.toc),
              ),
              IconButton(
                tooltip: '阅读设置',
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => showReaderSettingsSheet(context),
                icon: const Icon(Icons.text_fields),
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
          const SizedBox(height: 12),
          TText(
            book.meta.author,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _buildPrevNext(BookData book, AppColors colors) {
    Widget navButton(String? id, String label, IconData icon, bool leading) {
      if (id == null || id.isEmpty) return const SizedBox.shrink();
      return Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: colors.foreground,
            side: BorderSide(color: colors.border),
          ),
          onPressed: () => context.pushReplacement('/book/$id'),
          icon: leading ? Icon(icon, size: 18) : const SizedBox.shrink(),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TText(label),
              if (!leading) Icon(icon, size: 18),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 24),
      child: Row(
        children: [
          navButton(
              book.meta.lastBuId, '上一部', Icons.chevron_left, true),
          const SizedBox(width: 12),
          navButton(
              book.meta.nextBuId, '下一部', Icons.chevron_right, false),
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
    // Anchor on the first visible block — same semantics as the web's
    // IntersectionObserver-driven currentPartId.
    final blockIndex =
        (_firstVisibleBlock - 1).clamp(0, book.blocks.length - 1);
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

// ---- Block rendering ---------------------------------------------------------

class _BlockView extends StatelessWidget {
  const _BlockView({
    required this.block,
    required this.baseStyle,
    required this.paragraphSpacing,
    required this.display,
    required this.colors,
    this.highlight,
  });

  final JuanBlock block;
  final TextStyle baseStyle;
  final double paragraphSpacing;
  final String Function(String) display;
  final AppColors colors;
  final String? highlight;

  static final _imgRegex = RegExp('<img[^>]*>');
  static final _srcRegex = RegExp('src=["\']([^"\']+)["\']');

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case JuanBlockType.bt:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            display(block.paragraphs.join().trim()),
            textAlign: TextAlign.center,
            style: baseStyle.copyWith(
              fontSize: baseStyle.fontSize! * 1.2,
              fontWeight: FontWeight.w700,
            ),
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
        return Padding(
          padding: EdgeInsets.only(bottom: paragraphSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final paragraph in block.paragraphs)
                Padding(
                  padding: EdgeInsets.only(bottom: paragraphSpacing),
                  child: _buildParagraph(paragraph),
                ),
            ],
          ),
        );
    }
  }

  Widget _buildParagraph(String raw) {
    // Mirror the web renderer: paragraphs may embed <img> tags (rare
    // illustrations); split them out and render via cached_network_image.
    final cleaned = raw.replaceAll('“', '').replaceAll('”', '');
    if (!cleaned.contains('<img')) return _buildText(cleaned);

    final children = <Widget>[];
    var cursor = 0;
    for (final match in _imgRegex.allMatches(cleaned)) {
      if (match.start > cursor) {
        children.add(_buildText(cleaned.substring(cursor, match.start)));
      }
      final src = _srcRegex.firstMatch(match.group(0)!)?.group(1);
      if (src != null && src.isNotEmpty) {
        final url = src.startsWith('http')
            ? src
            : '${AppConstants.baseUrl}${src.startsWith('/') ? '' : '/'}$src';
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: CachedNetworkImage(
              imageUrl: url,
              placeholder: (_, __) => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Icon(
                Icons.broken_image_outlined,
                color: colors.mutedForeground,
              ),
            ),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < cleaned.length) {
      children.add(_buildText(cleaned.substring(cursor)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildText(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final shown = display(text);
    final needle = highlight == null ? null : display(highlight!);
    if (needle == null || needle.isEmpty || !shown.contains(needle)) {
      return Text(shown, style: baseStyle);
    }
    // Search-jump highlight (web's yellow <mark>).
    final spans = <TextSpan>[];
    var cursor = 0;
    var idx = shown.indexOf(needle);
    while (idx >= 0) {
      if (idx > cursor) {
        spans.add(TextSpan(text: shown.substring(cursor, idx)));
      }
      spans.add(TextSpan(
        text: needle,
        style: TextStyle(
          backgroundColor: const Color(0xFFFEF08A),
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        ),
      ));
      cursor = idx + needle.length;
      idx = shown.indexOf(needle, cursor);
    }
    if (cursor < shown.length) {
      spans.add(TextSpan(text: shown.substring(cursor)));
    }
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}
