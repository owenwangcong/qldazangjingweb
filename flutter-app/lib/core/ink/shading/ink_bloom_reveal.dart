import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 破墨显现（P2.3）：新页内容自 [origin] 以噪声扰动的墨晕前沿晕开。
///
/// 实现为**矢量 ClipPath**（64 段极坐标轮廓，半径带确定性噪声起伏）：
/// 早期的 AnimatedSampler 与 ShaderMask 方案都需要全屏逐像素工作
/// （saveLayer / 噪声 shader），在 Impeller 无 raster cache 的 Android 端
/// 实测转场 raster p90 高达 37-40ms；矢量裁剪只付一次路径光栅化的成本
/// （根因与数据见 ink-design-plan.md §9）。
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
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final p = progress.value;
        if (p >= 1.0) return child;
        if (p <= 0.0) return const SizedBox.shrink();
        return ClipPath(
          // hardEdge：抗锯齿 clip 在 Impeller 上走 stencil 路径明显更贵；
          // 墨晕前沿本就由噪声轮廓打散，硬边在 300ms 动态中不可辨。
          clipBehavior: Clip.hardEdge,
          clipper: _BloomClipper(progress: p, origin: origin),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// 墨晕轮廓：以 origin 为心的近圆形，64 段半径乘 (1 + 噪声起伏)。
/// 起伏由固定相位的正弦叠加生成——确定性、跨帧连贯（同一角度的
/// 凸起随半径同步生长，像墨沿纸纤维的指状渗透）。
class _BloomClipper extends CustomClipper<Path> {
  _BloomClipper({required this.progress, required this.origin});

  final double progress;
  final Offset? origin;

  static const _segments = 32;

  @override
  Path getClip(Size size) {
    final o = origin == null
        ? size.center(Offset.zero)
        : Offset(
            origin!.dx.clamp(0.0, size.width),
            origin!.dy.clamp(0.0, size.height),
          );
    // 触点到最远角，保证 progress=1 前全屏覆盖（轮廓最小乘数 0.82，
    // 故基准半径放大到 1/0.82 ≈ 1.22 倍）。
    final dx = math.max(o.dx, size.width - o.dx);
    final dy = math.max(o.dy, size.height - o.dy);
    final maxDist = math.sqrt(dx * dx + dy * dy);
    final r = progress * progress * 0.3 * maxDist +
        progress * 1.22 * maxDist * (1 - 0.3);

    final path = Path();
    for (var i = 0; i <= _segments; i++) {
      final a = i / _segments * 2 * math.pi;
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

  @override
  bool shouldReclip(_BloomClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.origin != origin;
}
