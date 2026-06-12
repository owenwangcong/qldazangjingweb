import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/ink_tokens.dart';

/// 墨圈 loading（P1.6）：一笔围成的圆相（ensō），笔锋起收处留缺口，
/// 缓慢旋转。替代全 App 的 CircularProgressIndicator。
///
/// 尊重无障碍：`MediaQuery.disableAnimations` 时呈静止圆相。
class EnsoLoading extends StatefulWidget {
  const EnsoLoading({super.key, this.size = 36, this.strokeWidth = 3});

  final double size;
  final double strokeWidth;

  @override
  State<EnsoLoading> createState() => _EnsoLoadingState();
}

class _EnsoLoadingState extends State<EnsoLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Semantics(
      label: '加载中',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _EnsoPainter(
              color: ink.inkStrong,
              strokeWidth: widget.strokeWidth,
              rotation: _controller.value * 2 * math.pi,
            ),
          ),
        ),
      ),
    );
  }
}

class _EnsoPainter extends CustomPainter {
  _EnsoPainter({
    required this.color,
    required this.strokeWidth,
    required this.rotation,
  });

  final Color color;
  final double strokeWidth;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth * 2.4) / 2;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(rotation)
      ..translate(-center.dx, -center.dy);

    // 一笔 300°：起笔细 → 中段满 → 收笔渐细渐淡（笔锋）。
    const sweep = math.pi * 5 / 3;
    const segments = 40;
    for (var i = 0; i < segments; i++) {
      final t = i / segments;
      final a0 = -math.pi / 2 + sweep * t;
      final a1 = -math.pi / 2 + sweep * (t + 1 / segments);
      final envelope = math.sin(t * math.pi).clamp(0.25, 1.0).toDouble();
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        a0,
        a1 - a0 + 0.01,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.45 + 0.55 * envelope)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth * (0.45 + 0.75 * envelope),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EnsoPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.rotation != rotation ||
      oldDelegate.strokeWidth != strokeWidth;
}
