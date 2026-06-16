import 'package:flutter/material.dart';

/// 墨滴涟漪（P1.6）：替代 Material 默认 ripple——触点如墨滴入纸，
/// 中心浓、边缘晕散（径向渐变），扩散用 easeOutQuart（先快后缓，
/// 似墨遇水的阻尼）。在 buildAppTheme 中全局注入 splashFactory。
class InkDropSplashFactory extends InteractiveInkFeatureFactory {
  const InkDropSplashFactory();

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    return _InkDropSplash(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      textDirection: textDirection,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
    );
  }
}

class _InkDropSplash extends InteractiveInkFeature {
  _InkDropSplash({
    required MaterialInkController controller,
    required super.referenceBox,
    required Offset position,
    required super.color,
    required this.textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    super.onRemoved,
  })  : _position = position,
        _borderRadius = borderRadius ?? BorderRadius.zero,
        _customBorder = customBorder,
        // reduce-motion：保留涟漪但幅度减半（§4.2 微交互退化）。
        _targetRadius = (radius ??
                _getTargetRadius(
                    referenceBox, containedInkWell, rectCallback, position)) *
            (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
                    .disableAnimations
                ? 0.5
                : 1.0),
        _clipCallback = _getClipCallback(referenceBox, containedInkWell, rectCallback),
        super(controller: controller) {
    _radiusController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: controller.vsync,
    )
      ..addListener(controller.markNeedsPaint)
      ..forward();
    _radius = _radiusController.drive(
      Tween<double>(begin: _targetRadius * 0.12, end: _targetRadius)
          .chain(CurveTween(curve: Curves.easeOutQuart)),
    );
    _alphaController = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: controller.vsync,
    )
      ..addListener(controller.markNeedsPaint)
      ..addStatusListener(_handleAlphaStatusChanged);
    _alpha = _alphaController
        .drive(IntTween(begin: (color.a * 255.0).round() & 0xff, end: 0));
  }

  final Offset _position;
  final BorderRadius _borderRadius;
  final ShapeBorder? _customBorder;
  final double _targetRadius;
  final RectCallback? _clipCallback;
  final TextDirection textDirection;

  late final AnimationController _radiusController;
  late final Animation<double> _radius;
  late final AnimationController _alphaController;
  late final Animation<int> _alpha;

  static double _getTargetRadius(
    RenderBox referenceBox,
    bool containedInkWell,
    RectCallback? rectCallback,
    Offset position,
  ) {
    final size = rectCallback?.call().size ?? referenceBox.size;
    final d1 = (position - size.topLeft(Offset.zero)).distance;
    final d2 = (position - size.topRight(Offset.zero)).distance;
    final d3 = (position - size.bottomLeft(Offset.zero)).distance;
    final d4 = (position - size.bottomRight(Offset.zero)).distance;
    return [d1, d2, d3, d4].reduce((a, b) => a > b ? a : b);
  }

  static RectCallback? _getClipCallback(
    RenderBox referenceBox,
    bool containedInkWell,
    RectCallback? rectCallback,
  ) {
    if (rectCallback != null) return rectCallback;
    if (containedInkWell) return () => Offset.zero & referenceBox.size;
    return null;
  }

  void _handleAlphaStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) dispose();
  }

  @override
  void confirm() => _alphaController.forward();

  @override
  void cancel() => _alphaController.forward();

  @override
  void dispose() {
    _radiusController.dispose();
    _alphaController.dispose();
    super.dispose();
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    final alpha = _alpha.value / 255.0;
    final radius = _radius.value;
    // 墨滴：中心 65% 浓度向边缘晕散到 0。
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha * 0.65),
          color.withValues(alpha: alpha * 0.35),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: _position, radius: radius));
    paintInkCircle(
      canvas: canvas,
      transform: transform,
      paint: paint,
      center: _position,
      textDirection: textDirection,
      radius: radius,
      customBorder: _customBorder,
      borderRadius: _borderRadius,
      clipCallback: _clipCallback,
    );
  }
}
