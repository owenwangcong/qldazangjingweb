import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shading/ink_paper_background.dart';
import '../tokens/ink_tokens.dart';

/// 画卷相机（P2.1/P2.2）：整个 App 共享一幅超宽水墨长卷，
/// 导航不是「换页」而是视线在卷上移动。
///
/// - [pan]：横向视点 0..1（tab 切换横移）
/// - [depth]：纵深 0..1（push 详情 = 深入画中：远山微放大下沉）
class InkCanvasCamera extends ChangeNotifier {
  double _pan = 0;
  double _depth = 0;

  double get pan => _pan;
  double get depth => _depth;

  void moveTo({double? pan, double? depth}) {
    final p = (pan ?? _pan).clamp(0.0, 1.0);
    final d = (depth ?? _depth).clamp(0.0, 1.0);
    if (p == _pan && d == _depth) return;
    _pan = p;
    _depth = d;
    notifyListeners();
  }
}

/// 全局画卷相机：路由（app_router）与画卷层（InkScrollCanvas）的连接点。
/// 与 appRouter 同级的进程单例——路由 redirect 阶段无法稳定拿到画卷层
/// 之下的 context，全局量是此处最朴素可靠的桥。
final inkCanvasCamera = InkCanvasCamera();

/// 最近一次触点（全局逻辑坐标）：破墨转场（P2.3）以此为晕开原点。
final ValueNotifier<Offset?> inkLastPointerDown = ValueNotifier<Offset?>(null);

/// 烘焙好的全屏宣纸位图（物理分辨率），随主题/尺寸变化重烘。
/// 画卷层与 push 页面的纸底（InkPaperBacking）共用，全 App 只此一份。
///
/// 为什么烘焙：Impeller 没有 picture raster cache——RepaintBoundary 只是
/// 不重录 display list，每帧仍会重新光栅化；全屏噪声 shader 哪怕「静止」
/// 也每帧执行（实测 reader raster p90 3.7→31ms，§9）。烘成位图后每帧
/// 只剩一次纹理位块传送。
final ValueNotifier<ui.Image?> inkPaperImage = ValueNotifier<ui.Image?>(null);

/// 持久画卷层（P2.1）：挂在 MaterialApp.builder——跨路由不重建。
/// 三 tab（depth=0）浮于画卷上；push 详情页自带纸底（InkPaperBacking），
/// 画卷被完全遮住时停绘（Impeller 无遮挡剔除，必须自己停）。
class InkScrollCanvas extends StatefulWidget {
  const InkScrollCanvas({super.key, required this.child, this.camera});

  final Widget child;

  /// 默认用全局 [inkCanvasCamera]；测试可注入独立实例。
  final InkCanvasCamera? camera;

  /// 取画卷相机（widget 侧驱动视差用）。
  static InkCanvasCamera cameraOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_InkCanvasScope>();
    assert(scope != null, 'InkScrollCanvas 未挂载（应在 MaterialApp.builder 注入）');
    return scope!.camera;
  }

  @override
  State<InkScrollCanvas> createState() => InkScrollCanvasState();
}

class InkScrollCanvasState extends State<InkScrollCanvas>
    with SingleTickerProviderStateMixin {
  late final InkCanvasCamera camera = widget.camera ?? inkCanvasCamera;

  late final AnimationController _drift = AnimationController(
    vsync: this,
    // 相机插值动画：moveTo 后 350ms easeInOutCubic 跟随（§4.2）。
    duration: const Duration(milliseconds: 350),
  );
  late final CurvedAnimation _driftCurve =
      CurvedAnimation(parent: _drift, curve: Curves.easeInOutCubic);

  double _fromPan = 0, _toPan = 0, _fromDepth = 0, _toDepth = 0;

  // 烘焙状态：per (逻辑尺寸 × 主题) 一张物理分辨率纸位图。
  Size? _bakedSize;
  InkTokens? _bakedInk;
  int _bakeEpoch = 0;

  // 整卷快照（纸+山 @ 当前视点）：相机停稳后烘焙，滚动期间画卷只剩
  // 一次位块传送（Impeller 无 raster cache，矢量山每帧重画也嫌贵——
  // home 滚动实测 +7.3ms，见 §9）。
  ui.Image? _scene;
  double? _scenePan, _sceneDepth;
  int _sceneEpoch = 0;

  @override
  void initState() {
    super.initState();
    // 冷启动深链可能在挂载前就设了相机目标——直接对齐，不播动画。
    _fromPan = _toPan = camera.pan;
    _fromDepth = _toDepth = camera.depth;
    _drift.value = 1;
    camera.addListener(_onCameraTarget);
    _drift.addStatusListener((status) {
      if (status == AnimationStatus.completed) _bakeScene();
    });
  }

  void _onCameraTarget() {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _fromPan = _currentPan;
    _fromDepth = _currentDepth;
    _toPan = camera.pan;
    _toDepth = camera.depth;
    if (reduceMotion) {
      _drift.value = 1;
      setState(() {}); // 立即落位（含停绘状态切换）
    } else {
      _drift.forward(from: 0);
    }
  }

  double get _currentPan =>
      _fromPan + (_toPan - _fromPan) * _driftCurve.value;
  double get _currentDepth =>
      _fromDepth + (_toDepth - _fromDepth) * _driftCurve.value;

  /// 被不透明 push 页完全盖住（深度到位且动画结束）→ 一笔不画。
  bool get _suppressed => _toDepth >= 1 && !_drift.isAnimating;

  /// 相机停稳后把「纸+山 @ 当前视点」烘成整卷快照。
  void _bakeScene() {
    if (_suppressed || !mounted) return;
    final size = _bakedSize;
    final paper = inkPaperImage.value;
    if (size == null || size.isEmpty || paper == null) return;
    final ink = _bakedInk;
    if (ink == null) return;
    final epoch = ++_sceneEpoch;
    final pan = _toPan, depth = _toDepth;
    scheduleMicrotask(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // 物理分辨率录制（与纸位图一致）。
      final scaleX = paper.width / size.width;
      canvas.scale(scaleX);
      _CanvasPainter(
        ink: ink,
        pan: pan,
        depth: depth,
        paper: paper,
        scene: null,
        suppressed: false,
      ).paint(canvas, size);
      final image =
          await recorder.endRecording().toImage(paper.width, paper.height);
      if (!mounted || epoch != _sceneEpoch) {
        image.dispose();
        return;
      }
      setState(() {
        _scene?.dispose();
        _scene = image;
        _scenePan = pan;
        _sceneDepth = depth;
      });
    });
  }

  /// 快照可用 = 相机静止且快照与当前视点一致。
  ui.Image? get _validScene =>
      (!_drift.isAnimating && _scenePan == _toPan && _sceneDepth == _toDepth)
          ? _scene
          : null;

  void _ensureBaked(Size logicalSize, double dpr, InkTokens ink) {
    if (logicalSize.isEmpty) return;
    if (_bakedSize == logicalSize && _bakedInk == ink) return;
    _bakedSize = logicalSize;
    _bakedInk = ink;
    // 纸要重烘 → 旧快照随之作废。
    _sceneEpoch++;
    _scene?.dispose();
    _scene = null;
    _scenePan = _sceneDepth = null;
    final epoch = ++_bakeEpoch;
    // scheduleMicrotask 而非 Future()：后者经 Timer.run 启动，会在
    // widget 测试结束时触发「Timer still pending」断言（坑8）。
    scheduleMicrotask(() async {
      await InkPaperBackground.warmUp();
      final program = InkPaperBackground.cachedProgram;
      if (program == null || epoch != _bakeEpoch) return;
      final w = (logicalSize.width * dpr).ceil();
      final h = (logicalSize.height * dpr).ceil();
      final tint = ink.paperTint;
      final inkColor = ink.inkStrong;
      final shader = program.fragmentShader()
        ..setFloat(0, w.toDouble())
        ..setFloat(1, h.toDouble())
        ..setFloat(2, tint.r)
        ..setFloat(3, tint.g)
        ..setFloat(4, tint.b)
        ..setFloat(5, 1)
        ..setFloat(6, inkColor.r)
        ..setFloat(7, inkColor.g)
        ..setFloat(8, inkColor.b)
        ..setFloat(9, 1)
        ..setFloat(10, ink.textureIntensity);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..shader = shader,
      );
      final image = await recorder.endRecording().toImage(w, h);
      if (!mounted || epoch != _bakeEpoch) {
        image.dispose();
        return;
      }
      inkPaperImage.value?.dispose();
      inkPaperImage.value = image;
      setState(() {});
      _bakeScene(); // 纸就绪后立刻补整卷快照
    });
  }

  @override
  void dispose() {
    camera.removeListener(_onCameraTarget);
    _drift.dispose();
    _driftCurve.dispose();
    _scene?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return _InkCanvasScope(
      camera: camera,
      child: Listener(
        // 记录触点供破墨转场定位晕开原点；translucent 不拦截任何手势。
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => inkLastPointerDown.value = event.position,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _ensureBaked(
              constraints.biggest,
              MediaQuery.maybeOf(context)?.devicePixelRatio ??
                  View.of(context).devicePixelRatio,
              ink,
            );
            return Stack(
              textDirection: TextDirection.ltr,
              fit: StackFit.expand,
              children: [
                AnimatedBuilder(
                  animation: _driftCurve,
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    isComplex: true,
                    painter: _CanvasPainter(
                      ink: ink,
                      pan: _currentPan,
                      depth: _currentDepth,
                      paper: inkPaperImage.value,
                      scene: _validScene,
                      suppressed: _suppressed,
                    ),
                  ),
                ),
                widget.child,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InkCanvasScope extends InheritedWidget {
  const _InkCanvasScope({required this.camera, required super.child});

  final InkCanvasCamera camera;

  @override
  bool updateShouldNotify(_InkCanvasScope oldWidget) =>
      oldWidget.camera != camera;
}

/// push 页面的纸底：烘焙位图位块传送（未就绪时纯纸色）。
/// 用于 inkBloomPage 统一垫底，使所有详情页不透明（画卷得以停绘）。
class InkPaperBacking extends StatelessWidget {
  const InkPaperBacking({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return ValueListenableBuilder<ui.Image?>(
      valueListenable: inkPaperImage,
      builder: (context, image, _) => CustomPaint(
        painter: _PaperBlitPainter(image: image, fallback: ink.paperTint),
        child: child,
      ),
    );
  }
}

class _PaperBlitPainter extends CustomPainter {
  _PaperBlitPainter({required this.image, required this.fallback});

  final ui.Image? image;
  final Color fallback;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = fallback);
      return;
    }
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_PaperBlitPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.fallback != fallback;
}

/// 画卷绘制：整卷快照位块传送（相机静止时）或 纸位图 + 远山实画
/// （相机动画 350ms 内）。被盖住时（suppressed）一笔不画。
/// 山景裁剪到上半屏——下半屏雾色≈纸色，省一半填充带宽。
class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.ink,
    required this.pan,
    required this.depth,
    required this.paper,
    required this.scene,
    required this.suppressed,
  });

  final InkTokens ink;
  final double pan;
  final double depth;
  final ui.Image? paper;
  final ui.Image? scene;
  final bool suppressed;

  /// 山景只占上半屏；以下到屏底雾色与纸色一致，无须绘制。
  static const _skylineFraction = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || suppressed) return;

    // ---- 快照路径：滚动期间的唯一开销 = 一次位块传送 --------------------
    final snap = scene;
    if (snap != null) {
      canvas.drawImageRect(
        snap,
        Rect.fromLTWH(0, 0, snap.width.toDouble(), snap.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.none,
      );
      return;
    }

    // ---- 实画路径（相机动画中 / 快照未就绪） ---------------------------
    final img = paper;
    if (img == null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = ink.paperTint);
    } else {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.none,
      );
    }

    // ---- 远山（上半屏裁剪） -------------------------------------------
    final skyline = size.height * _skylineFraction;
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, size.width, skyline));

    final virtualWidth = size.width * 3;
    final scale = 1.0 + depth * 0.06;
    canvas
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-size.width / 2, -size.height / 2 + depth * size.height * 0.02);

    for (var layer = 0; layer < 3; layer++) {
      final parallax = 0.4 + layer * 0.3; // 远层动得慢
      final dx = -pan * (virtualWidth - size.width) * parallax;
      final baseY = size.height * (0.30 + layer * 0.07);
      final amp = size.height * (0.10 - layer * 0.02);
      final alpha = (0.045 - layer * 0.012) *
          (ink.paperTint.computeLuminance() > 0.5 ? 1.0 : 1.5);

      final path = Path()..moveTo(dx, baseY);
      final rnd = math.Random(31 + layer * 17);
      final phase = rnd.nextDouble() * math.pi * 2;
      for (var x = 0.0; x <= virtualWidth; x += 24) {
        final t = x / virtualWidth;
        final y = baseY -
            amp *
                (0.62 * math.sin(t * math.pi * 7 + phase) +
                    0.38 * math.sin(t * math.pi * 17 + phase * 1.7))
                    .abs();
        path.lineTo(dx + x, y);
      }
      path
        ..lineTo(dx + virtualWidth, skyline)
        ..lineTo(dx, skyline)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = ink.inkStrong.withValues(alpha: alpha.clamp(0.0, 0.08)),
      );

      // 山脚雾：从山脊渐隐到 skyline 处与纸色一致（米氏云山）。
      final mistTop = baseY - amp * 0.2;
      final mist = Rect.fromLTWH(0, mistTop, size.width, skyline - mistTop);
      canvas.drawRect(
        mist,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.55, 1],
            colors: [
              ink.paperTint.withValues(alpha: 0),
              ink.paperTint.withValues(alpha: 0.85),
              ink.paperTint.withValues(alpha: 1),
            ],
          ).createShader(mist),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CanvasPainter oldDelegate) =>
      oldDelegate.ink != ink ||
      oldDelegate.pan != pan ||
      oldDelegate.depth != depth ||
      oldDelegate.paper != paper ||
      oldDelegate.scene != scene ||
      oldDelegate.suppressed != suppressed;
}
