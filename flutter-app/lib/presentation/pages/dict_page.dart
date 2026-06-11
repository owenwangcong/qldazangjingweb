import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: display('输入要查询的词'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
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
                ? const Center(child: CircularProgressIndicator())
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
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    color: colors.card,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: colors.border
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 4),
                                            decoration: BoxDecoration(
                                              color: colors.primary
                                                  .withValues(alpha: 0.18),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: TText(
                                              result.dict,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: colors.cardForeground,
                                              ),
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
