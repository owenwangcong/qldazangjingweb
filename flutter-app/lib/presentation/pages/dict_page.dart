import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ink/ink.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../widgets/t_text.dart';

/// 佛学辞典查询（web `/dicts` 的移动端形态，在线功能）。
class DictPage extends ConsumerStatefulWidget {
  const DictPage({super.key});

  @override
  ConsumerState<DictPage> createState() => _DictPageState();
}

class _DictPageState extends ConsumerState<DictPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _searched = false;
  String? _error;
  List<({String dict, String value})> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final term = _controller.text.trim();
    if (term.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
      _results = const [];
    });
    try {
      if (!ref.read(connectivityServiceProvider).isOnline) {
        throw Exception('辞典查询需要联网，请检查网络后重试');
      }
      final results =
          await ref.read(lexiconRepositoryProvider).lookup(term);
      setState(() => _results = results);
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final display = ref.watch(displayTextProvider);

    return Scaffold(
      appBar: AppBar(title: const TText('搜索辞典')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                // 砚台输入框（P3.7）：浅墨池底 + 吃墨边缘。
                Expanded(
                  child: InkCard(
                    seed: 43,
                    borderRadius: 10,
                    shadow: false,
                    color: colors.muted.withValues(alpha: 0.6),
                    padding: EdgeInsets.zero,
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: display('输入要查询的词'),
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
                  child: TText('查询'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: EnsoLoading())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            display(_error!),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.mutedForeground),
                          ),
                        ),
                      )
                    : !_searched
                        ? Center(
                            child: TText(
                              '查询佛学辞典释义',
                              style:
                                  TextStyle(color: colors.mutedForeground),
                            ),
                          )
                        : _results.isEmpty
                            ? Center(child: TText('未找到匹配的结果'))
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: _results.length,
                                itemBuilder: (context, index) {
                                  final result = _results[index];
                                  // 释义笺纸卡（P3.7）：辞书名题字 +
                                  // 笔触下划线，正文留白行距 1.7。
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    child: InkCard(
                                      seed: 71 + index,
                                      borderRadius: 12,
                                      shadow: false,
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Center(
                                            child: Column(
                                              children: [
                                                TText(
                                                  result.dict,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: colors
                                                        .cardForeground,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                BrushUnderline(
                                                  width: (result.dict.length *
                                                          15.0)
                                                      .clamp(32.0, 120.0),
                                                  thickness: 2.2,
                                                  seed: 25,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          TText(
                                            result.value,
                                            style: TextStyle(
                                              fontSize: 15,
                                              height: 1.7,
                                              color: colors.cardForeground,
                                            ),
                                          ),
                                        ],
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
