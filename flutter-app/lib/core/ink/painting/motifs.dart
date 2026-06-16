import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/ink_tokens.dart';

/// 装饰意象透明度上限（设计八则 #6）：浅主题 0.10，暗主题 0.14。
/// 任何白描/云雾装饰都必须经 [debugCheckMotifOpacity] 把守。
double maxMotifOpacity(Brightness brightness) =>
    brightness == Brightness.dark ? 0.14 : 0.10;

bool debugCheckMotifOpacity(BuildContext context, double opacity) {
  final cap = maxMotifOpacity(Theme.of(context).brightness);
  assert(
    opacity <= cap,
    '装饰意象 opacity=$opacity 超过设计八则 #6 上限 $cap（见 ink-design-plan.md §1）',
  );
  return true;
}

/// 白描莲花（P1.5）：内外两层花瓣 + 莲蓬，单线勾勒。
/// 用于空态/角隅点缀，默认透明度即上限的一半，似有似无。
class LotusOutline extends StatelessWidget {
  const LotusOutline({
    super.key,
    this.size = 120,
    this.opacity = 0.06,
    this.strokeWidth = 1.2,
  });

  final double size;
  final double opacity;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckMotifOpacity(context, opacity));
    final ink = context.ink;
    return IgnorePointer(
      child: CustomPaint(
        size: Size(size, size * 0.72),
        painter: _LotusPainter(
          color: ink.inkStrong.withValues(alpha: opacity),
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _LotusPainter extends CustomPainter {
  _LotusPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final base = Offset(size.width / 2, size.height * 0.92);
    final h = size.height;

    // 花瓣：从基部出发的对称闭合曲线，angle 为中轴偏转。
    Path petal(double angle, double height, double width) {
      final tip = base + Offset(math.sin(angle) * height, -math.cos(angle) * height);
      final mid = Offset.lerp(base, tip, 0.45)!;
      final normal = Offset(math.cos(angle), math.sin(angle));
      final left = mid - normal * width;
      final right = mid + normal * width;
      return Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(left.dx, left.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(right.dx, right.dy, base.dx, base.dy);
    }

    // 外层四瓣（低、宽）→ 内层三瓣（高、窄）→ 中央莲蓬。
    for (final a in [-0.85, -0.32, 0.32, 0.85]) {
      canvas.drawPath(petal(a, h * 0.52, size.width * 0.13), paint);
    }
    for (final a in [-0.42, 0.0, 0.42]) {
      canvas.drawPath(petal(a, h * 0.78, size.width * 0.11), paint);
    }
    // 莲蓬：小圆台 + 三粒莲子。
    final pod = base + Offset(0, -h * 0.18);
    canvas.drawArc(
      Rect.fromCenter(center: pod, width: size.width * 0.14, height: h * 0.10),
      math.pi, math.pi, false, paint,
    );
    for (final dx in [-0.03, 0.0, 0.03]) {
      canvas.drawCircle(pod + Offset(size.width * dx, -h * 0.015), 0.9, paint);
    }
  }

  @override
  bool shouldRepaint(_LotusPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// 如意祥云（P1.5）：三连云头 + 拖尾，单线。
class CloudPattern extends StatelessWidget {
  const CloudPattern({
    super.key,
    this.width = 96,
    this.opacity = 0.06,
    this.strokeWidth = 1.2,
  });

  final double width;
  final double opacity;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckMotifOpacity(context, opacity));
    final ink = context.ink;
    return IgnorePointer(
      child: CustomPaint(
        size: Size(width, width * 0.4),
        painter: _CloudPainter(
          color: ink.inkStrong.withValues(alpha: opacity),
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  _CloudPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final baseY = size.height * 0.62;
    // 三个云头：中间大、两侧小，上半圆弧相接。
    void head(double cx, double r) => canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, baseY), radius: r),
          math.pi * 0.95, math.pi * 1.1, false, paint,
        );
    head(w * 0.30, size.height * 0.30);
    head(w * 0.50, size.height * 0.42);
    head(w * 0.70, size.height * 0.30);
    // 云尾：底部横线向右收尾，末端轻卷。
    final tail = Path()
      ..moveTo(w * 0.16, baseY + size.height * 0.16)
      ..lineTo(w * 0.78, baseY + size.height * 0.16)
      ..quadraticBezierTo(
          w * 0.88, baseY + size.height * 0.16, w * 0.86, baseY + size.height * 0.02);
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(_CloudPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// 云雾留白带（P1.5）：横向渐隐的雾层，用于区块间的呼吸感。
/// 颜色取 mistColor，整体透明度受上限把守。
class MistBand extends StatelessWidget {
  const MistBand({
    super.key,
    this.height = 48,
    this.opacity = 0.08,
    this.seed = 23,
  });

  final double height;
  final double opacity;
  final int seed;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckMotifOpacity(context, opacity));
    final ink = context.ink;
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _MistPainter(
            color: ink.mistColor.withValues(alpha: opacity),
            seed: seed,
          ),
        ),
      ),
    );
  }
}

class _MistPainter extends CustomPainter {
  _MistPainter({required this.color, required this.seed});

  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final rnd = math.Random(seed);
    // 三条低频起伏的雾带，相互错位叠加。
    for (var layer = 0; layer < 3; layer++) {
      final path = Path()..moveTo(0, size.height);
      final baseY = size.height * (0.35 + 0.18 * layer);
      final amp = size.height * 0.12;
      final phase = rnd.nextDouble() * math.pi * 2;
      for (var x = 0.0; x <= size.width; x += 12) {
        path.lineTo(
          x,
          baseY + math.sin(x / size.width * math.pi * 2.2 + phase) * amp,
        );
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_MistPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}

/// 朱砂印章（P1.5）：功能性点睛（选中态/署名），非淡装饰——不受 0.10 上限，
/// 但每屏 ≤2 处（§4.1，代码评审项）。白文：朱底白字。
class SealStamp extends StatelessWidget {
  const SealStamp({
    super.key,
    required this.text,
    this.size = 28,
  }) : assert(text.length <= 2, '印章至多两字');

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ink.sealRed,
        borderRadius: BorderRadius.circular(size * 0.14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: text.length == 1 ? size * 0.58 : size * 0.40,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
