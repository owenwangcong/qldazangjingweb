import 'package:flutter/material.dart';

import '../../core/ink/ink.dart';
import '../../core/theme/app_theme.dart';
import 't_text.dart';

/// 古籍竖排阅读视图 —— S1 占位（实施方案 vertical-reader-plan.md §12）。
///
/// 本占位只保证两件事：三种 readingMode 互切路径畅通、中部点按显隐 chrome
/// 与其余模式一致。网格排版引擎按 S2~S6 增量接入后整体替换本实现，
/// 勿在此扩展任何布局逻辑。
class VerticalReader extends StatelessWidget {
  const VerticalReader({super.key, required this.onToggleChrome});

  final VoidCallback onToggleChrome;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggleChrome,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TText(
              '竖排书叶制版中',
              style: TextStyle(fontSize: 15, color: colors.mutedForeground),
            ),
            const SizedBox(height: 10),
            const BrushUnderline(width: 88, thickness: 2.4, seed: 41),
          ],
        ),
      ),
    );
  }
}
