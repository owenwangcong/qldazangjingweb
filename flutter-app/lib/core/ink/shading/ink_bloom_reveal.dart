import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tokens/ink_tokens.dart';

/// 破墨转场时长与曲线（§4.2，平滑化修订 2026-06-12）：
/// - 时长 380/300ms（原 300/240）：60Hz 下多 ~5 帧，帧间位移按比例缩小。
/// - easeOutSine（原 easeOutCubic）：归一化前沿峰速 2.1→1.36，且峰值从
///   「起点/触点附近」挪到中段（前沿已在屏幕外围）——慢放实测帧间
///   不连续感的主因正是 easeOutCubic 起点导数 3.0 的首帧巨跳。
const Curve inkBloomCurve = Curves.easeOutSine;
const Duration inkBloomPushDuration = Duration(milliseconds: 380);
const Duration inkBloomPopDuration = Duration(milliseconds: 300);

/// reduce-motion 退化的淡变区间：≤120ms（120/380 ≈ 0.31）。
const double inkReduceMotionFraction = 0.31;

/// 墨晕轮廓（32 段极坐标噪声多边形）：reveal 裁剪与墨缘环共用同一份
/// 顶点生成逻辑，逐帧贴合。
///
/// 起伏由固定相位的正弦叠加生成——确定性、跨帧连贯（同一角度的凸起
/// 随半径同步生长，像墨沿纸纤维的指状渗透）。
///
/// [radiusOffset]：沿径向整体外扩/内缩（逻辑 px），用于构造贴合噪声轮廓
/// 的同心环带（S3 纸雾软前沿）——径向渐变 shader 与 wobble（±20%r）会
/// 错位，唯有从同一顶点族派生才能逐帧贴合。
Path inkBloomPath(Size size, double progress, Offset? origin,
    {double radiusOffset = 0}) {
  final pts = _bloomRing(size, progress, origin, radiusOffset);
  final path = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (var i = 1; i < pts.length; i++) {
    path.lineTo(pts[i].dx, pts[i].dy);
  }
  path.close();
  return path;
}

const int _bloomSegments = 32;

/// 墨晕轮廓的逐角度顶点（含首尾重合点，共 segments+1 个）——
/// [inkBloomPath]（裁剪/描边）与纸雾三角带（S3）共用同一份顶点数学。
List<Offset> _bloomRing(
    Size size, double progress, Offset? origin, double radiusOffset) {
  final o = origin == null
      ? size.center(Offset.zero)
      : Offset(
          origin.dx.clamp(0.0, size.width),
          origin.dy.clamp(0.0, size.height),
        );
  // 触点到最远角，保证 progress=1 前全屏覆盖（轮廓最小乘数 0.82，
  // 故基准半径放大到 1/0.82 ≈ 1.22 倍——乘**整个包络**。修正：旧式只把
  // 1.22 乘在线性项上，p=1 时有效覆盖仅 0.946·maxDist，最远角楔形残片
  // 会在 p≥1 分支瞬间硬切，慢放下清晰可见）。
  final dx = math.max(o.dx, size.width - o.dx);
  final dy = math.max(o.dy, size.height - o.dy);
  final maxDist = math.sqrt(dx * dx + dy * dy);
  // 种子半径 r0：首帧不再「凭空出现」，且与墨滴 splash（420ms 自触点
  // 扩散）半径衔接——墨滴落纸→晕开成页连成一笔。
  const r0 = 28.0;
  final growth = 0.7 * progress + 0.3 * progress * progress;
  final r = r0 + (1.22 * maxDist - r0) * growth;

  final pts = List<Offset>.filled(_bloomSegments + 1, Offset.zero);
  for (var i = 0; i <= _bloomSegments; i++) {
    final a = i / _bloomSegments * 2 * math.pi;
    // 三组固定频率/相位的正弦 → 不规则但确定的指状前沿。
    final wobble = 1 +
        0.10 * math.sin(a * 5 + 1.3) +
        0.06 * math.sin(a * 9 + 4.1) +
        0.04 * math.sin(a * 17 + 2.6);
    final ri = math.max(0.0, r * wobble.clamp(0.82, 1.2) + radiusOffset);
    pts[i] = o + Offset(math.cos(a) * ri, math.sin(a) * ri);
  }
  return pts;
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

// 历史注：曾有 InkBloomConceal（被盖页「全屏−墨晕」evenOdd 反向裁剪，与
// reveal 互补）与 SnapshotWidget 冻结两套机制，实测均撤（2026-06-12）：
// - 互补裁剪的内容填充本就被 early-stencil 剔除，conceal 多付的是一整条
//   全屏 stencil 通道（转场 raster p90 26.3→29.1ms）；
// - 快照捕获每个转场方向打进 1-2 帧 ~38ms 的 UI 线程尖峰，而中位帧 raster
//   分毫未降（25.9ms）——瓶颈是裁剪机制与基础开销，不是内容栅格化。
// 现行方案 = 「下层页不做任何处理」：上层页（InkPaperBacking 不透明）的
// reveal 裁剪自然逐像素覆盖下层，视觉与互补裁剪逐像素相同，代价仅 blob
// 内过度绘制（纯填充带宽，便宜于 stencil 通道）。数据见 §9。

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
      // push 末段淡出 / pop 头段淡入（≤120ms），时序上始终有一页全不透明。
      return FadeTransition(
        opacity: ReverseAnimation(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(1.0 - inkReduceMotionFraction, 1.0),
          ),
        ),
        child: child,
      );
    }
    // 正常动效下不做任何处理（Plan B，见文件头历史注）：上层页不透明，
    // reveal 裁剪自然覆盖本页；被盖稳态由 Overlay 的 opaque-offstage
    // 机制免费跳绘。
    return child;
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

/// 墨缘前沿：纸雾软带（S3）+ 墨缘环。
///
/// 纸雾软带 = **单次 drawVertices 环形三角带**：7 圈顶点沿 [inkBloomPath]
/// 的同一顶点族径向偏移（−60..+60px），顶点 alpha 0→0.5→0，GPU 插值出
/// 真正连续的纸色（paperTint）渐变——前沿两侧的新旧内容都向纸色消融，
/// 硬切被掩、帧间位移被软带吸收（透明渐变方案）。
/// 构造方式是被两轮性能数据逼出来的：
/// - 宽 stroke：Impeller 对凹折点宽描边产生自重叠几何，半透明双混合出斑块；
/// - evenOdd 环带填充 ×6：每道一条 stencil-then-cover 通道（bounding 近全
///   屏），实测转场 raster p90 28.8→60.1ms ❌；
/// - drawVertices 三角带：单 draw call、零 stencil、顶点色硬件插值。
///
/// 墨缘环 = 沿前沿描 4 道渐宽渐淡的环（round join 防 32 段折线尖刺）。
/// progress>0.8 后整体衰减归零，终帧干净。
class _BloomFringePainter extends CustomPainter {
  _BloomFringePainter({
    required this.progress,
    required this.origin,
    required this.ink,
  });

  final double progress;
  final Offset? origin;
  final InkTokens ink;

  /// 软带圈层：径向偏移（px）→ 顶点 alpha（首尾 0 = 真渐出）。
  static const _mistOffsets = [-60.0, -40.0, -20.0, 0.0, 20.0, 40.0, 60.0];
  static const _mistAlphas = [0.0, 0.18, 0.38, 0.50, 0.38, 0.18, 0.0];

  @override
  void paint(Canvas canvas, Size size) {
    // 尾段衰减：p>0.8 后线性归零（晕开完成时前沿融入页面）。
    final fade = progress < 0.8 ? 1.0 : (1 - progress) / 0.2;
    if (fade <= 0) return;

    _paintMistBand(canvas, size, fade);

    // ---- 墨缘环（骑缝盖在软带之上） ----------------------------------
    final path = inkBloomPath(size, progress, origin);
    _paintInkRings(canvas, path, fade);
  }

  /// 纸雾软带：环形三角形网格一次 drawVertices（零 stencil 通道）。
  void _paintMistBand(Canvas canvas, Size size, double fade) {
    const ringCount = 7; // _mistOffsets.length
    const ptsPerRing = _bloomSegments + 1;
    final positions = Float32List(ringCount * ptsPerRing * 2);
    final colors = Int32List(ringCount * ptsPerRing);
    var pi = 0, ci = 0;
    for (var ring = 0; ring < ringCount; ring++) {
      final pts = _bloomRing(size, progress, origin, _mistOffsets[ring]);
      final argb = ink.paperTint
          .withValues(alpha: _mistAlphas[ring] * fade)
          .toARGB32();
      for (final pt in pts) {
        positions[pi++] = pt.dx;
        positions[pi++] = pt.dy;
        colors[ci++] = argb;
      }
    }
    // 相邻两圈之间组四边形（两三角形）。
    final indices = Uint16List((ringCount - 1) * _bloomSegments * 6);
    var ii = 0;
    for (var ring = 0; ring < ringCount - 1; ring++) {
      final a0 = ring * ptsPerRing;
      final b0 = (ring + 1) * ptsPerRing;
      for (var i = 0; i < _bloomSegments; i++) {
        indices[ii++] = a0 + i;
        indices[ii++] = b0 + i;
        indices[ii++] = a0 + i + 1;
        indices[ii++] = a0 + i + 1;
        indices[ii++] = b0 + i;
        indices[ii++] = b0 + i + 1;
      }
    }
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      colors: colors,
      indices: indices,
    );
    // BlendMode.dst：只用顶点色（paint 不参与）。
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    vertices.dispose();
  }

  void _paintInkRings(Canvas canvas, Path path, double fade) {
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
