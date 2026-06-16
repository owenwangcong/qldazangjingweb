import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../tokens/ink_tokens.dart';

/// 主题画卷缩略（P3.8）：每个主题渲染成一幅微型水墨小品——
/// 该主题的纸色为底、远山两叠用该主题的墨阶、底缘题主题名；
/// 选中 = 朱砂印点 + 重墨描边。预览色全部取自目标主题的真实
/// token（与实际主题色逐值一致，由 widget test 锁定）。
class InkThemeThumb extends StatelessWidget {
  const InkThemeThumb({
    super.key,
    required this.theme,
    required this.selected,
    required this.onTap,
    this.width = 96,
  });

  final AppThemeId theme;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final palette = buildAppTheme(theme).extension<AppColors>()!;
    final targetInk = InkTokens.forTheme(theme);
    return Semantics(
      button: true,
      selected: selected,
      label: theme.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    width: width,
                    height: width * 0.62,
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? ink.inkStrong.withValues(alpha: 0.75)
                            : ink.inkLight.withValues(alpha: 0.45),
                        width: selected ? 1.6 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CustomPaint(
                      painter: _MiniScrollPainter(ink: targetInk),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: ink.sealRed,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                theme.label,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.1,
                  color: selected ? ink.inkStrong : ink.inkMedium,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 微型画卷：两叠远山 + 一弯水线，全部取目标主题的墨阶。
class _MiniScrollPainter extends CustomPainter {
  _MiniScrollPainter({required this.ink});

  final InkTokens ink;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 远山（淡墨）。
    final far = Path()
      ..moveTo(0, h * 0.58)
      ..quadraticBezierTo(w * 0.22, h * 0.30, w * 0.42, h * 0.52)
      ..quadraticBezierTo(w * 0.52, h * 0.62, w * 0.62, h * 0.55)
      ..lineTo(w, h * 0.62)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = ink.inkLight.withValues(alpha: 0.45));
    // 近山（重墨）。
    final near = Path()
      ..moveTo(w * 0.30, h)
      ..quadraticBezierTo(w * 0.55, h * 0.42, w * 0.78, h * 0.70)
      ..quadraticBezierTo(w * 0.90, h * 0.84, w, h * 0.78)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
        near, Paint()..color = ink.inkMedium.withValues(alpha: 0.55));
    // 水线（清墨一笔）。
    canvas.drawLine(
      Offset(w * 0.08, h * 0.86),
      Offset(w * 0.46, h * 0.86),
      Paint()
        ..color = ink.inkLight.withValues(alpha: 0.6)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_MiniScrollPainter oldDelegate) => oldDelegate.ink != ink;
}
