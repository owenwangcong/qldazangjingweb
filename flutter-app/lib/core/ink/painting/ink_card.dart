import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/ink_tokens.dart';

/// 墨晕阴影（P1.3，设计八则 #2）：取代 Material elevation——
/// 大 blur、低 alpha、轻微下沉，像墨在纸背洇开。
List<BoxShadow> inkWashShadow(InkTokens ink) => [
      BoxShadow(
        color: ink.washShadowColor,
        blurRadius: ink.washShadowBlur,
        offset: const Offset(0, 5),
        spreadRadius: -3,
      ),
    ];

/// 笺纸卡片（P1.3）：纸色底 + 墨晕阴影 + 吃墨边缘。
///
/// 边缘用固定 [seed] 的抖动描边模拟笔锋入纸的不均匀（积墨），
/// 同一 seed 两次绘制逐像素一致（golden 可锁定）。
class InkCard extends StatelessWidget {
  const InkCard({
    super.key,
    required this.child,
    this.seed = 7,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 10,
    this.onTap,
    this.shadow = true,
    this.color,
  });

  final Widget child;
  final int seed;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  /// 墨晕阴影开关：滚动列表里的大量小卡可关掉（模糊阴影在 Impeller
  /// 无 raster cache 下逐帧重画，§9 性能教训）。
  final bool shadow;

  /// 卡面颜色，默认 cardColor；题签等变体可传 muted。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final theme = Theme.of(context);
    // 结构：阴影在最外（DecoratedBox）→ Material 画卡面（ripple 才能浮在
    // 卡面之上，不被不透明底色盖住）→ 吃墨边缘前景描边。
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadow ? inkWashShadow(ink) : null,
      ),
      child: Material(
        color: color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: CustomPaint(
            foregroundPainter: _BrushBorderPainter(
              color: ink.inkLight,
              radius: borderRadius,
              seed: seed,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// 吃墨边缘：沿圆角矩形路径取样，做垂直于路径的微小抖动，
/// 分段宽度/透明度起伏 → 手写描边感。全程由 seed 决定，无真随机。
///
/// 性能（P3.3 教训）：逐段 drawLine 在全宽列表行上是每帧 ~400 次
/// draw call，Impeller 无 raster cache 时滚动 jank 1.49%→32%。改为
/// 按墨量分 3 桶聚合成折线 Path，每桶一次 drawPath（≤3 次/卡），
/// 抖动轮廓与飞白观感保留（墨量量化为三档）。
class _BrushBorderPainter extends CustomPainter {
  _BrushBorderPainter({
    required this.color,
    required this.radius,
    required this.seed,
  });

  final Color color;
  final double radius;
  final int seed;

  /// 墨量三档：(alpha, strokeWidth)。
  static const _buckets = [
    (0.32, 0.8),
    (0.55, 1.3),
    (0.78, 1.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect.deflate(0.8));
    final rnd = math.Random(seed);

    final bucketPaths = [Path(), Path(), Path()];

    for (final metric in path.computeMetrics()) {
      const step = 6.0;
      var distance = 0.0;
      var thickness = 1.0 + rnd.nextDouble() * 0.6;
      var alpha = 0.55 + rnd.nextDouble() * 0.25;
      var currentBucket = -1;
      Offset? prev;
      while (distance < metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent == null) break;
        // 垂直于切线方向的微抖（±0.7px），步进间平滑。
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        final jitter = (rnd.nextDouble() - 0.5) * 1.4;
        final point = tangent.position + normal * jitter;
        // 厚度与墨量缓慢游走，出现轻微「飞白」（量化进三档桶）。
        thickness =
            (thickness + (rnd.nextDouble() - 0.5) * 0.5).clamp(0.6, 2.2);
        alpha = (alpha + (rnd.nextDouble() - 0.5) * 0.18).clamp(0.25, 0.85);
        final bucket = alpha < 0.45 ? 0 : (alpha < 0.65 ? 1 : 2);
        if (prev == null) {
          bucketPaths[bucket].moveTo(point.dx, point.dy);
        } else if (bucket != currentBucket) {
          // 换桶：新桶从上一点接笔，轮廓不断线。
          bucketPaths[bucket]
            ..moveTo(prev.dx, prev.dy)
            ..lineTo(point.dx, point.dy);
        } else {
          bucketPaths[bucket].lineTo(point.dx, point.dy);
        }
        currentBucket = bucket;
        prev = point;
        distance += step;
      }
    }

    for (var i = 0; i < 3; i++) {
      if (bucketPaths[i].getBounds().isEmpty) continue;
      canvas.drawPath(
        bucketPaths[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..color = color.withValues(alpha: _buckets[i].$1)
          ..strokeWidth = _buckets[i].$2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_BrushBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.seed != seed;
}
