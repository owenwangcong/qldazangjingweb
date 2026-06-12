import 'package:flutter/material.dart';

import '../tokens/ink_tokens.dart';
import 'brush_line.dart';
import 'motifs.dart';

/// 题跋区导航项：未选中 = 淡墨图标；选中 = 朱砂印（标签首字白文印）。
@immutable
class InkNavItem {
  const InkNavItem({
    required this.icon,
    required this.label,
    required this.sealText,
  }) : assert(sealText.length <= 2, '印章至多两字');

  final IconData icon;
  final String label;
  final String sealText;
}

/// 题跋区底部导航（P3.1）：替代 Material NavigationBar。
///
/// 视觉 = 画卷下缘的题跋条——顶部一道干笔分隔线把画心与题跋分开，
/// 纸面半透明让画卷透出；选中 tab 盖朱砂印 + 笔触下划线（形状差异
/// 不止颜色，满足无障碍）；未选中为淡墨图标。
///
/// 性能：无持续动画，仅选中切换时一次 200ms 渐换（§4.2 微交互档），
/// 静止时零重绘。
class InkNavBar extends StatelessWidget {
  const InkNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<InkNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// 内容高度（不含底部安全区）；≥48dp 命中区由此保证。
  static const double contentHeight = 64;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Material(
      // 与 AppBar 同款半透明纸面：题跋区不遮断画卷的连续感。
      color: scheme.surface.withValues(alpha: 0.88),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 画心与题跋的分界：干笔一道，飞白可见。
            const BrushDivider(height: 10, seed: 31),
            SizedBox(
              height: contentHeight - 10,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _InkNavDestination(
                        item: items[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InkNavDestination extends StatelessWidget {
  const _InkNavDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final InkNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 28,
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                child: selected
                    ? SealStamp(text: item.sealText, size: 26)
                    : Icon(item.icon, size: 24, color: ink.inkMedium),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                height: 1,
                color: selected ? ink.inkStrong : ink.inkMedium,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            SizedBox(
              height: 7,
              child: selected
                  ? const Center(
                      child: BrushUnderline(width: 34, thickness: 2.4, seed: 7),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
