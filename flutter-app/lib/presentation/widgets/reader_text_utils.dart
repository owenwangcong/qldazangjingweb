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

/// 字重三档（claudedocs/font-weight-quotes-plan.md FQ1，滚动/翻页共用）：
/// 同色描边层叠于填充层之下使笔画增粗。描边不改变字形 advance——折行与
/// 分页测量不受档位影响（对照 [buildHighlightedTextSpan] 的加粗警告，
/// 描边方案天然规避）。描边层逐 run 保留 fontWeight（高亮加粗时两层度量
/// 一致，Stack 下折行必然相同）、剥除 color/background；并以
/// SelectionContainer.disabled + ExcludeSemantics + IgnorePointer 隔离，
/// 选区/语义/命中只在填充层。standard 档（strokeWidthEm<=0）零开销原样返回。
Widget weightedReaderText(
  TextSpan span, {
  required double strokeWidthEm,
  TextAlign? textAlign,
  TextScaler? textScaler,
}) {
  final fill = Text.rich(span, textAlign: textAlign, textScaler: textScaler);
  final fontSize = span.style?.fontSize;
  final color = span.style?.color;
  if (strokeWidthEm <= 0 || fontSize == null || color == null) return fill;
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = fontSize * strokeWidthEm
    ..color = color;
  return Stack(
    children: [
      IgnorePointer(
        child: ExcludeSemantics(
          child: SelectionContainer.disabled(
            child: Text.rich(
              _strokeClone(span, paint),
              textAlign: textAlign,
              textScaler: textScaler,
            ),
          ),
        ),
      ),
      fill,
    ],
  );
}

TextSpan _strokeClone(TextSpan span, Paint paint) {
  final s = span.style;
  return TextSpan(
    text: span.text,
    style: s == null
        ? null
        : TextStyle(
            fontFamily: s.fontFamily,
            fontSize: s.fontSize,
            height: s.height,
            letterSpacing: s.letterSpacing,
            fontWeight: s.fontWeight,
            foreground: paint,
          ),
    children: span.children
        ?.whereType<TextSpan>()
        .map((c) => _strokeClone(c, paint))
        .toList(),
  );
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
