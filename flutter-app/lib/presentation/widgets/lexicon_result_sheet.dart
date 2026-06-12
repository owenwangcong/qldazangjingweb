import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ink/ink.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 't_text.dart';

enum LexiconAction { dictionary, toModernChinese, explain }

extension LexiconActionX on LexiconAction {
  String get title => switch (this) {
        LexiconAction.dictionary => '字典',
        LexiconAction.toModernChinese => '今译',
        LexiconAction.explain => '释义',
      };
}

/// 选中文本 → 字典/今译/释义 结果（web 右键菜单二级内容的 BottomSheet 形态）。
/// These are online-only features; offline shows a clear notice instead.
void showLexiconResultSheet(
  BuildContext context,
  WidgetRef ref, {
  required LexiconAction action,
  required String selectedText,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _LexiconResultSheet(
      action: action,
      selectedText: selectedText,
    ),
  );
}

class _LexiconResultSheet extends ConsumerStatefulWidget {
  const _LexiconResultSheet({
    required this.action,
    required this.selectedText,
  });

  final LexiconAction action;
  final String selectedText;

  @override
  ConsumerState<_LexiconResultSheet> createState() =>
      _LexiconResultSheetState();
}

class _LexiconResultSheetState extends ConsumerState<_LexiconResultSheet> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<String> _load() async {
    final online = ref.read(connectivityServiceProvider).isOnline;
    if (!online) {
      throw Exception('此功能需要联网，请检查网络后重试');
    }
    final lexicon = ref.read(lexiconRepositoryProvider);
    switch (widget.action) {
      case LexiconAction.dictionary:
        final entries = await lexicon.lookup(widget.selectedText);
        if (entries.isEmpty) return '找不到字典解释';
        return entries
            .map((e) => '## ${e.dict}\n\n${e.value}')
            .join('\n\n---\n\n');
      case LexiconAction.toModernChinese:
        return lexicon.toModernChinese(widget.selectedText);
      case LexiconAction.explain:
        return lexicon.explain(widget.selectedText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final display = ref.watch(displayTextProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
            child: Row(
              children: [
                TText(
                  widget.action.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    display(widget.selectedText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 13, color: colors.mutedForeground),
                  ),
                ),
                IconButton(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // BottomSheet 顶部干笔分隔（P3.9，设计八则 #3）。
          const BrushDivider(height: 10, seed: 39),
          Expanded(
            child: FutureBuilder<String>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: EnsoLoading());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 40, color: colors.mutedForeground),
                          const SizedBox(height: 12),
                          Text(
                            display(snapshot.error
                                .toString()
                                .replaceFirst('Exception: ', '')),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.mutedForeground),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () =>
                                setState(() => _future = _load()),
                            child: Text(display('重试')),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Markdown(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  data: display(snapshot.data ?? ''),
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: colors.foreground,
                    ),
                    h2: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.foreground,
                    ),
                    strong: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.foreground,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
