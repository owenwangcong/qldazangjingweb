import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../canvas/ink_scroll_canvas.dart' show inkLastPointerDown;
import '../tokens/ink_tokens.dart';

/// 墨晕轮廓（32 段极坐标噪声多边形）：[InkBloomReveal]（新页正向裁剪）与
/// [InkBloomConceal]（被盖页反向裁剪）共用同一份顶点生成逻辑——
/// 同 progress 同 origin 下两页墨缘逐帧像素级互补（hardEdge 无 AA，
/// 同一扫描规则，无接缝）。
///
/// 起伏由固定相位的正弦叠加生成——确定性、跨帧连贯（同一角度的凸起
/// 随半径同步生长，像墨沿纸纤维的指状渗透）。
Path inkBloomPath(Size size, double progress, Offset? origin) {
  final o = origin == null
      ? size.center(Offset.zero)
      : Offset(
          origin.dx.clamp(0.0, size.width),
          origin.dy.clamp(0.0, size.height),
        );
  // 触点到最远角，保证 progress=1 前全屏覆盖（轮廓最小乘数 0.82，
  // 故基准半径放大到 1/0.82 ≈ 1.22 倍）。
  final dx = math.max(o.dx, size.width - o.dx);
  final dy = math.max(o.dy, size.height - o.dy);
  final maxDist = math.sqrt(dx * dx + dy * dy);
  final r = progress * progress * 0.3 * maxDist +
      progress * 1.22 * maxDist * (1 - 0.3);

  const segments = 32;
  final path = Path();
  for (var i = 0; i <= segments; i++) {
    final a = i / segments * 2 * math.pi;
    // 三组固定频率/相位的正弦 → 不规则但确定的指状前沿。
    final wobble = 1 +
        0.10 * math.sin(a * 5 + 1.3) +
        0.06 * math.sin(a * 9 + 4.1) +
        0.04 * math.sin(a * 17 + 2.6);
    final ri = r * wobble.clamp(0.82, 1.2);
    final pt = o + Offset(math.cos(a) * ri, math.sin(a) * ri);
    if (i == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  path.close();
  return path;
}

/// 破墨显现（P2.3）：新页内容自 [origin] 以噪声扰动的墨晕前沿晕开，
/// 前沿叠 3–4 道渐宽渐淡的墨缘环（晕染感，无 blur 无 saveLayer）。
///
/// 实现为**矢量 ClipPath**：早期的 AnimatedSampler 与 ShaderMask 方案都需
/// 全屏逐像素工作（saveLayer / 噪声 shader），在 Impeller 无 raster cache
/// 的 Android 端实测转场 raster p90 高达 37-40ms；矢量裁剪只付一次路径
/// 光栅化的成本（根因与数据见 ink-design-plan.md §9）。
///
/// progress 完成后直接返回 child（零转场开销）。
class InkBloomReveal extends StatelessWidget {
  const InkBloomReveal({
    super.key,
    required this.progress,
    required this.child,
    this.origin,
  });

  final Animation<double> progress;
  final Widget child;

  /// 晕开原点（全局逻辑坐标）；null = 画面中心。
  final Offset? origin;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final p = progress.value;
        if (p >= 1.0) return child;
        if (p <= 0.0) return const SizedBox.shrink();
        return Stack(
          fit: StackFit.passthrough,
          children: [
            ClipPath(
              // hardEdge：抗锯齿 clip 在 Impeller 上走 stencil 路径明显更贵；
              // 墨晕前沿由噪声轮廓 + 墨缘环打散，硬边不可辨。
              clipBehavior: Clip.hardEdge,
              clipper: _BloomClipper(progress: p, origin: origin),
              child: child,
            ),
            // 墨缘环（转场修复 F3）：画在裁剪之外、骑缝覆盖上下两页交界，
            // 既给前沿晕染感，也兜住 conceal/reveal 复合的潜在 1px 接缝。
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BloomFringePainter(
                    progress: p,
                    origin: origin,
                    ink: ink,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

/// 被盖页的反向墨缘裁剪（转场修复 F1）：裁到「全屏 − 墨晕」，与上层
/// [InkBloomReveal] 像素级互补——旧页在墨晕外保持原样可见，每像素恰好
/// 只画一页；不再用 opacity 淡出（0<α<1 的整页 FadeTransition 在 Impeller
/// 上回退 saveLayer，且早退会露出画卷/黑底，见 §9）。
class InkBloomConceal extends StatelessWidget {
  const InkBloomConceal({
    super.key,
    required this.progress,
    required this.child,
    this.origin,
  });

  final Animation<double> progress;
  final Widget child;
  final Offset? origin;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final p = progress.value;
        // 未被覆盖：裸 child——不留常驻 ClipPath，落定页滚动零裁剪税。
        if (p <= 0.0) return child;
        if (p >= 1.0) {
          // 完全被盖：空可见区裁剪——子树保活（State/滚动位置不丢，
          // 不可用 SizedBox.shrink，那会 unmount 整棵子树），paint 全
          // 剔除；随后 Overlay 因上层 opaque 路由自动转 offstage 接管。
          return ClipRect(clipper: _ZeroRectClipper(), child: child);
        }
        return ClipPath(
          clipBehavior: Clip.hardEdge,
          clipper: _ConcealClipper(progress: p, origin: origin),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// 被盖页的标准包装：正常动效 = [InkBloomConceal]（与上层 reveal 同曲线
/// 同原点，逐帧互补）；reduce-motion = 短淡出（push 末 40% 淡出 /
/// pop 头 40% 淡入，时序上始终有一页完全不透明，无黑隙）。
///
/// 供 inkBloomPage 与 _StillPageTransitionsBuilder 两个调用点共用。
class InkCoveredPage extends StatelessWidget {
  const InkCoveredPage({
    super.key,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return FadeTransition(
        opacity: ReverseAnimation(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(0.6, 1.0),
          ),
        ),
        child: child,
      );
    }
    // secondaryAnimation 与上层路由的 animation 同 controller 同帧同值；
    // 套同一 easeOutCubic（双向都不设 reverseCurve）+ 同帧读同一全局触点
    // → conceal 与 reveal 的墨晕路径严格一致。
    return InkBloomConceal(
      progress: CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
      ),
      origin: inkLastPointerDown.value,
      child: child,
    );
  }
}

class _BloomClipper extends CustomClipper<Path> {
  _BloomClipper({required this.progress, required this.origin});

  final double progress;
  final Offset? origin;

  @override
  Path getClip(Size size) => inkBloomPath(size, progress, origin);

  @override
  bool shouldReclip(_BloomClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.origin != origin;
}

/// 反向裁剪：evenOdd 双子路径（全屏矩形 + 同一份墨晕顶点）——零布尔
/// 运算，且与 [_BloomClipper] 用同一扫描规则，互补像素级精确。
class _ConcealClipper extends CustomClipper<Path> {
  _ConcealClipper({required this.progress, required this.origin});

  final double progress;
  final Offset? origin;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addPath(inkBloomPath(size, progress, origin), Offset.zero);

  @override
  bool shouldReclip(_ConcealClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.origin != origin;
}

class _ZeroRectClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) => Rect.zero;

  @override
  bool shouldReclip(_ZeroRectClipper oldClipper) => false;
}

/// 墨缘环：沿墨晕前沿描 4 道渐宽渐淡的环（round join 防 32 段折线
/// 尖刺），progress→1 时整体衰减归零，终帧干净。
class _BloomFringePainter extends CustomPainter {
  _BloomFringePainter({
    required this.progress,
    required this.origin,
    required this.ink,
  });

  final double progress;
  final Offset? origin;
  final InkTokens ink;

  @override
  void paint(Canvas canvas, Size size) {
    // 尾段衰减：p>0.7 后线性归零（晕开完成时墨缘融入页面）。
    final fade = progress < 0.7 ? 1.0 : (1 - (progress - 0.7) / 0.3);
    if (fade <= 0) return;
    final path = inkBloomPath(size, progress, origin);
    void ring(Color color, double alpha, double width) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = color.withValues(alpha: alpha * fade)
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // 由内向外：墨锋一线 → 三层渐散的晕。
    ring(ink.inkStrong, 0.14, 2.5);
    ring(ink.inkMedium, 0.08, 10);
    ring(ink.inkMedium, 0.05, 22);
    ring(ink.inkLight, 0.04, 36);
  }

  @override
  bool shouldRepaint(_BloomFringePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.origin != origin ||
      oldDelegate.ink != ink;
}
