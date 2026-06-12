import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/ink_tokens.dart';

/// 干笔分隔线（P1.4）：替代 Divider——起笔重、收笔轻、中段偶有飞白。
/// 同一 [seed] 输出逐像素一致。
class BrushDivider extends StatelessWidget {
  const BrushDivider({
    super.key,
    this.seed = 11,
    this.height = 16,
    this.indent = 0,
    this.endIndent = 0,
  });

  final int seed;
  final double height;
  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: indent, end: endIndent),
        child: CustomPaint(
          size: Size.infinite,
          painter: _BrushStrokePainter(
            color: ink.inkLight,
            seed: seed,
            maxThickness: 1.8,
            flyWhite: true,
          ),
        ),
      ),
    );
  }
}

/// 笔触下划线（P1.4）：选中态/标题强调，比分隔线短粗、墨色更重。
class BrushUnderline extends StatelessWidget {
  const BrushUnderline({
    super.key,
    required this.width,
    this.seed = 5,
    this.thickness = 3.5,
    this.color,
  });

  final double width;
  final int seed;
  final double thickness;

  /// 默认 inkStrong；选中态可传 sealRed。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return SizedBox(
      width: width,
      height: thickness + 3,
      child: CustomPaint(
        size: Size.infinite,
        painter: _BrushStrokePainter(
          color: color ?? ink.inkStrong,
          seed: seed,
          maxThickness: thickness,
          flyWhite: false,
        ),
      ),
    );
  }
}

/// TabBar 笔触指示器（P3.6）：选中页签下的一道短笔触，替代 Material
/// 直线 indicator。
class BrushTabIndicator extends Decoration {
  const BrushTabIndicator({
    required this.color,
    this.width = 40,
    this.thickness = 2.6,
    this.seed = 5,
  });

  final Color color;
  final double width;
  final double thickness;
  final int seed;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _BrushTabPainter(this);
}

class _BrushTabPainter extends BoxPainter {
  _BrushTabPainter(this.decoration);

  final BrushTabIndicator decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.width <= 0) return;
    final w = decoration.width.clamp(0, size.width).toDouble();
    final dx = offset.dx + (size.width - w) / 2;
    final dy = offset.dy + size.height - decoration.thickness - 4;
    canvas.save();
    canvas.translate(dx, dy);
    paintBrushStroke(
      canvas,
      Size(w, decoration.thickness + 3),
      color: decoration.color,
      seed: decoration.seed,
      maxThickness: decoration.thickness,
      flyWhite: false,
    );
    canvas.restore();
  }
}

/// 横向笔触核心算法（公共入口，供 painter 与 BoxPainter 复用）：
/// thickness 包络 = 起笔按压（快速到峰值）→ 中段游走 → 收笔提锋
/// （指数收尾）；飞白 = 周期性透明度塌陷。确定性由 seed 保证。
void paintBrushStroke(
  Canvas canvas,
  Size size, {
  required Color color,
  required int seed,
  required double maxThickness,
  required bool flyWhite,
}) {
  if (size.width <= 0) return;
  final rnd = math.Random(seed);
  final y0 = size.height / 2;
  const step = 3.0;
  var drift = 0.0;
  Offset? prev;
  for (var x = 0.0; x <= size.width; x += step) {
    final t = x / size.width;
    // 起笔 0→1 快速上升（前 8%），收笔最后 15% 指数收细。
    final attack = math.min(t / 0.08, 1.0);
    final release =
        t > 0.85 ? math.pow(1 - (t - 0.85) / 0.15, 1.6).toDouble() : 1.0;
    final envelope = attack * release;
    drift = (drift + (rnd.nextDouble() - 0.5) * 0.5).clamp(-1.2, 1.2);
    final point = Offset(x, y0 + drift);
    if (prev != null) {
      var alpha = 0.9 * envelope + 0.1;
      if (flyWhite) {
        // 飞白：噪声驱动的墨量塌陷（约 15% 路段近乎露白）。
        final dry = rnd.nextDouble();
        if (dry > 0.85) alpha *= 0.25;
      }
      canvas.drawLine(
        prev,
        point,
        Paint()
          ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
          ..strokeWidth = (maxThickness * envelope).clamp(0.4, maxThickness)
          ..strokeCap = StrokeCap.round,
      );
    }
    prev = point;
  }
}

/// CustomPainter 包装（BrushDivider/BrushUnderline 用）。
class _BrushStrokePainter extends CustomPainter {
  _BrushStrokePainter({
    required this.color,
    required this.seed,
    required this.maxThickness,
    required this.flyWhite,
  });

  final Color color;
  final int seed;
  final double maxThickness;
  final bool flyWhite;

  @override
  void paint(Canvas canvas, Size size) => paintBrushStroke(
        canvas,
        size,
        color: color,
        seed: seed,
        maxThickness: maxThickness,
        flyWhite: flyWhite,
      );

  @override
  bool shouldRepaint(_BrushStrokePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.seed != seed ||
      oldDelegate.maxThickness != maxThickness ||
      oldDelegate.flyWhite != flyWhite;
}
