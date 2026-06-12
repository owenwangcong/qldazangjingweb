import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/book_entities.dart';
import 't_text.dart';

/// 阅读器滚动/翻页两种模式共享的渲染件。

/// 搜索跳转高亮（朱砂淡染）：把 [shown] 中的 [needle] 染色。
/// 无命中返回 null（调用方退回普通 Text）。
///
/// [bold]：滚动模式沿用 w700 加重；**翻页模式必须传 false**——加粗改变
/// 字形宽度会使渲染折行偏离分页测量结果，导致页面溢出。
TextSpan? buildHighlightedTextSpan({
  required String shown,
  required String? needle,
  required TextStyle baseStyle,
  required Color highlightBackground,
  required Color foreground,
  bool bold = true,
}) {
  if (needle == null || needle.isEmpty || !shown.contains(needle)) return null;
  final highlightStyle = TextStyle(
    backgroundColor: highlightBackground,
    color: foreground,
    fontWeight: bold ? FontWeight.w700 : null,
  );
  final spans = <TextSpan>[];
  var cursor = 0;
  var idx = shown.indexOf(needle);
  while (idx >= 0) {
    if (idx > cursor) {
      spans.add(TextSpan(text: shown.substring(cursor, idx)));
    }
    spans.add(TextSpan(text: needle, style: highlightStyle));
    cursor = idx + needle.length;
    idx = shown.indexOf(needle, cursor);
  }
  if (cursor < shown.length) {
    spans.add(TextSpan(text: shown.substring(cursor)));
  }
  return TextSpan(style: baseStyle, children: spans);
}

/// 卷末「上一部 / 下一部」导航（自 reader_page._buildPrevNext 抽出，
/// 滚动列表末项与翻页末页共用）。
class PrevNextNav extends StatelessWidget {
  const PrevNextNav({super.key, required this.meta});

  final BookMeta meta;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
          navButton(meta.lastBuId, '上一部', Icons.chevron_left, true),
          const SizedBox(width: 12),
          navButton(meta.nextBuId, '下一部', Icons.chevron_right, false),
        ],
      ),
    );
  }
}
