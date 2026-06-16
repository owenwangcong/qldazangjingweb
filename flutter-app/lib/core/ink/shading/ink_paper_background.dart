import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tokens/ink_tokens.dart';

/// 宣纸纹理背景（P1.2）：把 `shaders/paper.frag` 铺满自身区域，
/// tint/墨色/强度全部来自当前主题的 [InkTokens]。
///
/// 性能契约（设计八则 #8）：
/// - 外层 [RepaintBoundary] 隔离——纹理静止时 0 重绘，滚动内容不会
///   连带重绘背景层；
/// - shader 程序进程内只加载一次（static future）。
class InkPaperBackground extends StatelessWidget {
  const InkPaperBackground({super.key, this.child});

  final Widget? child;

  static final Future<ui.FragmentProgram> _program =
      ui.FragmentProgram.fromAsset('shaders/paper.frag');

  /// 加载完成后的同步缓存：FutureBuilder 在 FakeAsync 测试下对已完成的
  /// future 也不翻转（已实测），同步分支既解决测试问题，运行时二次构建
  /// 也省掉一帧 fallback。
  static ui.FragmentProgram? _cached;

  /// 预热 shader 程序（widget 测试须先 `tester.runAsync(InkPaperBackground.warmUp)`；
  /// App 启动期调用可避免首帧纯色兜底）。
  static Future<void> warmUp() async {
    _cached = await _program;
  }

  /// 已加载的程序（画卷层直接取用，未加载时为 null → 纯纸色兜底）。
  static ui.FragmentProgram? get cachedProgram => _cached;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final program = _cached;
    return RepaintBoundary(
      child: program != null
          ? _paint(program, ink)
          : FutureBuilder<ui.FragmentProgram>(
              future: warmUp().then((_) => _cached!),
              builder: (context, snap) {
                final p = snap.data;
                if (p == null) {
                  // 一帧以内的兜底：纯纸色，加载完成后无缝换纹理。
                  return ColoredBox(color: ink.paperTint, child: child);
                }
                return _paint(p, ink);
              },
            ),
    );
  }

  Widget _paint(ui.FragmentProgram program, InkTokens ink) => CustomPaint(
        painter: _PaperPainter(program.fragmentShader(), ink),
        child: child,
      );
}

class _PaperPainter extends CustomPainter {
  _PaperPainter(this._shader, this._ink);

  final ui.FragmentShader _shader;
  final InkTokens _ink;

  @override
  void paint(Canvas canvas, Size size) {
    final tint = _ink.paperTint;
    final inkColor = _ink.inkStrong;
    _shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, tint.r)
      ..setFloat(3, tint.g)
      ..setFloat(4, tint.b)
      ..setFloat(5, 1)
      ..setFloat(6, inkColor.r)
      ..setFloat(7, inkColor.g)
      ..setFloat(8, inkColor.b)
      ..setFloat(9, 1)
      ..setFloat(10, _ink.textureIntensity);
    canvas.drawRect(Offset.zero & size, Paint()..shader = _shader);
  }

  // InkTokens 实例随主题切换而更换（ThemeData extension 同主题内恒定），
  // 据此判断即可：主题不变 → 不重绘。
  @override
  bool shouldRepaint(_PaperPainter oldDelegate) => oldDelegate._ink != _ink;
}
