import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ink/ink.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/catalog_models.dart';
import '../../domain/entities/book_entities.dart';
import '../providers/app_providers.dart';
import '../widgets/book_list_tile.dart';
import '../widgets/t_text.dart';

/// 搜索页（web `/search` 的移动端形态）。
/// 全文搜索走线上 ES 接口（无限滚动取代分页）；标题搜索完全离线。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  bool _fulltextMode = true;
  bool _phraseMatch = false;
  bool _searched = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String _activeQuery = '';

  // Fulltext state
  final List<SearchHit> _hits = [];
  int _total = 0;
  int _page = 1;

  // Title-mode state
  List<CatalogBook> _titleResults = const [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_fulltextMode || _loadingMore || _loading) return;
    if (_hits.length >= _total) return;
    if (_scrollController.position.extentAfter < 400) {
      _loadMore();
    }
  }

  Future<void> _search() async {
    final raw = _inputController.text.trim();
    if (raw.isEmpty) return;
    FocusScope.of(context).unfocus();

    final converter = ref.read(chineseConverterProvider);
    final query = converter.normalizeQuery(raw);

    setState(() {
      _searched = true;
      _loading = true;
      _error = null;
      _activeQuery = query;
      _hits.clear();
      _total = 0;
      _page = 1;
      _titleResults = const [];
    });

    try {
      if (_fulltextMode) {
        final online = ref.read(connectivityServiceProvider).isOnline;
        if (!online) {
          throw Exception('全文搜索需要联网。离线时可使用「标题搜索」');
        }
        final result = await ref.read(searchRepositoryProvider).searchFullText(
              query: query,
              phraseMatch: _phraseMatch,
              page: 1,
            );
        setState(() {
          _hits.addAll(result.hits);
          _total = result.total;
        });
      } else {
        final results =
            await ref.read(catalogRepositoryProvider).searchTitles(query);
        setState(() => _titleResults = results);
      }
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final result = await ref.read(searchRepositoryProvider).searchFullText(
            query: _activeQuery,
            phraseMatch: _phraseMatch,
            page: next,
          );
      setState(() {
        _page = next;
        _hits.addAll(result.hits);
      });
    } catch (_) {
      // Silent: the user can scroll again to retry.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final display = ref.watch(displayTextProvider);
    final online = ref.watch(isOnlineProvider).value ?? true;

    return Scaffold(
      appBar: AppBar(title: const TText('搜索经书')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                // 墨字模式页签（P3.5）：替换 Material SegmentedButton。
                InkToggle(
                  options: [
                    display(online ? '全文搜索' : '全文搜索（需联网）'),
                    display('标题搜索'),
                  ],
                  selectedIndex: _fulltextMode ? 0 : 1,
                  onSelect: (i) => setState(() {
                    _fulltextMode = i == 0;
                    _searched = false;
                    _error = null;
                    _hits.clear();
                    _titleResults = const [];
                  }),
                ),
                if (_fulltextMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 40,
                          width: 40,
                          child: Checkbox(
                            value: _phraseMatch,
                            onChanged: (v) =>
                                setState(() => _phraseMatch = v ?? false),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _phraseMatch = !_phraseMatch),
                            child: TText(
                              '精确短语匹配（完整匹配搜索词）',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // 砚台搜索框（P3.5）：浅墨池底 + 吃墨边缘，无 Material 直线框。
                    Expanded(
                      child: InkCard(
                        seed: 37,
                        borderRadius: 10,
                        shadow: false,
                        color: colors.muted.withValues(alpha: 0.6),
                        padding: EdgeInsets.zero,
                        child: TextField(
                          controller: _inputController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search(),
                          decoration: InputDecoration(
                            hintText: display(_fulltextMode
                                ? '输入关键词或短语进行全文搜索'
                                : '输入经书名或作者'),
                            border: InputBorder.none,
                            isDense: true,
                            prefixIcon: Icon(Icons.search,
                                size: 20, color: colors.mutedForeground),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(72, 48),
                      ),
                      onPressed: _loading ? null : _search,
                      child: TText('搜索'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildResults(colors, display)),
        ],
      ),
    );
  }

  Widget _buildResults(AppColors colors, String Function(String) display) {
    if (_loading) {
      return const Center(child: EnsoLoading());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            display(_error!),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.mutedForeground),
          ),
        ),
      );
    }
    if (!_searched) {
      // 空闲态：唯一一处淡莲花（设计八则 #6）。
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LotusOutline(size: 140, opacity: 0.08),
            const SizedBox(height: 12),
            TText(
              '搜索 1669 部佛经原文',
              style: TextStyle(color: colors.mutedForeground),
            ),
          ],
        ),
      );
    }

    if (!_fulltextMode) {
      if (_titleResults.isEmpty) {
        return Center(child: TText('未找到匹配的经书'));
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _titleResults.length,
        itemBuilder: (context, index) =>
            BookListTile(book: _titleResults[index]),
      );
    }

    if (_hits.isEmpty) {
      return Center(child: TText('未找到匹配的经书'));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _hits.length + 1,
      itemBuilder: (context, index) {
        if (index == _hits.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _hits.length >= _total
                  ? TText(
                      '共 $_total 条结果',
                      style: TextStyle(
                          fontSize: 13, color: colors.mutedForeground),
                    )
                  : const EnsoLoading(size: 32),
            ),
          );
        }
        return _SearchHitCard(
          hit: _hits[index],
          query: _inputController.text.trim(),
          colors: colors,
          display: display,
        );
      },
    );
  }
}

class _SearchHitCard extends StatelessWidget {
  const _SearchHitCard({
    required this.hit,
    required this.query,
    required this.colors,
    required this.display,
  });

  final SearchHit hit;
  final String query;
  final AppColors colors;
  final String Function(String) display;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    // 笺纸结果卡（P3.5）：吃墨边缘；长列表关阴影（§9 性能教训）。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkCard(
        seed: 53 + hit.id.hashCode % 19,
        borderRadius: 12,
        shadow: false,
        padding: const EdgeInsets.all(14),
        onTap: () => context.push('/book/${hit.id}'),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      display(hit.title),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colors.cardForeground,
                      ),
                    ),
                  ),
                  if (hit.score != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${display('匹配度')} ${hit.score!.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.foreground,
                        ),
                      ),
                    ),
                ],
              ),
              if (hit.author.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    display(hit.author),
                    style: TextStyle(
                        fontSize: 13, color: colors.mutedForeground),
                  ),
                ),
              for (final fragment in hit.contentHighlights)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push(
                      '/book/${hit.id}?highlight=${Uri.encodeComponent(query)}',
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.muted.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _EmHighlightText(
                        html: '…$fragment…',
                        baseStyle: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: colors.foreground,
                        ),
                        // 朱砂淡染高亮（P3.5）。
                        emStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.foreground,
                          backgroundColor:
                              ink.sealRed.withValues(alpha: 0.22),
                        ),
                        display: display,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Renders an Elasticsearch highlight fragment, honoring only `<em>` tags
/// (everything else is stripped).
class _EmHighlightText extends StatelessWidget {
  const _EmHighlightText({
    required this.html,
    required this.baseStyle,
    required this.emStyle,
    required this.display,
  });

  final String html;
  final TextStyle baseStyle;
  final TextStyle emStyle;
  final String Function(String) display;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final regex = RegExp('<em>(.*?)</em>', dotAll: true);
    var cursor = 0;
    final source = html.replaceAll(RegExp('<(?!/?em)[^>]*>'), '');
    for (final match in regex.allMatches(source)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: display(source.substring(cursor, match.start))));
      }
      spans.add(TextSpan(text: display(match.group(1) ?? ''), style: emStyle));
      cursor = match.end;
    }
    if (cursor < source.length) {
      spans.add(TextSpan(text: display(source.substring(cursor))));
    }
    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }
}
