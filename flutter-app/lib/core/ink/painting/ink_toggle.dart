import 'package:flutter/material.dart';

import '../tokens/ink_tokens.dart';
import 'brush_line.dart';

/// 墨字多态切换（P3.4/P3.5）：替换 Material SegmentedButton——
/// 选中 = 重墨 + 笔触下划线（形状差异不只换色），命中区 ≥48dp。
class InkToggle extends StatelessWidget {
  const InkToggle({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < options.length; i++)
          Semantics(
            button: true,
            selected: i == selectedIndex,
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                constraints:
                    const BoxConstraints(minHeight: 48, minWidth: 56),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      options[i],
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.2,
                        color:
                            i == selectedIndex ? ink.inkStrong : ink.inkMedium,
                        fontWeight: i == selectedIndex
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    SizedBox(
                      height: 7,
                      child: i == selectedIndex
                          ? Center(
                              child: BrushUnderline(
                                width: (options[i].length * 14.0)
                                    .clamp(24.0, 96.0),
                                thickness: 2.2,
                                seed: 15,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
