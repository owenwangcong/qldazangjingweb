import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// 条目度量真源（V3，vertical-scroll-plan.md §3.3）：列带条目宽前缀表。
/// 物理吸附、条目宽回调、跨列反馈、跳转定位共用同一份表——
/// 度量只有一个真源，不存在两套算法漂移的可能。
/// 纯列书（全部等宽）走 O(1) 快路；含插图/卷尾条目走二分。
class SnapMetrics {
  factory SnapMetrics(List<double> extents) {
    final starts = List<double>.filled(extents.length + 1, 0);
    double? uniform = extents.isEmpty ? null : extents.first;
    for (var i = 0; i < extents.length; i++) {
      assert(extents[i] > 0, '条目宽必须为正: [$i]=${extents[i]}');
      starts[i + 1] = starts[i] + extents[i];
      if (uniform != null && (extents[i] - uniform).abs() > 1e-6) {
        uniform = null;
      }
    }
    return SnapMetrics._(starts, uniform);
  }

  SnapMetrics._(this.starts, this.uniform);

  /// 长度 = 条目数 + 1；starts[i] = 条目 i 起点偏移，末位 = 总长。
  final List<double> starts;

  /// 全条目等宽时的宽度（快路）；否则 null。
  final double? uniform;

  int get itemCount => starts.length - 1;
  double get totalExtent => starts.isEmpty ? 0 : starts.last;

  double extentOf(int index) =>
      starts[(index + 1).clamp(0, itemCount)] - starts[index.clamp(0, itemCount)];

  double offsetOf(int index) => starts[index.clamp(0, itemCount)];

  /// offset 所在条目（跨列反馈的 lead 计数用）：最后一个 start ≤ offset。
  int indexAt(double offset) {
    if (itemCount == 0) return 0;
    if (offset <= 0) return 0;
    final u = uniform;
    if (u != null) {
      return (offset / u).floor().clamp(0, itemCount - 1);
    }
    var lo = 0, hi = itemCount - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// x 之后最近的条目起点（含 maxExtent 收尾钳制）。
  double boundaryAfter(double x, {required double maxExtent}) {
    if (itemCount == 0) return 0;
    final u = uniform;
    final next =
        u != null ? ((x / u).floor() + 1) * u : starts[
            math.min(indexAt(x.clamp(0.0, totalExtent)) + 1, itemCount)];
    return math.min(next, maxExtent);
  }

  /// x 之前最近的条目起点。
  double boundaryBefore(double x) {
    if (itemCount == 0) return 0;
    final u = uniform;
    if (u != null) {
      final i = (x / u).ceil() - 1;
      return math.max(i, 0) * u;
    }
    final i = indexAt(x);
    return starts[x > starts[i] ? i : math.max(i - 1, 0)];
  }

  /// 最近吸附目标。候选 = 邻近条目起点，钳制到 [0, maxExtent]；
  /// 卷尾（起点超出 maxExtent 时）以 maxExtent 收尾——末屏左缘齐平，
  /// 右缘允许部分列（方案 B2：左侧是「尚未展开的卷」）。
  double nearestBoundary(double x, {required double maxExtent}) {
    if (itemCount == 0) return 0;
    final clamped = x.clamp(0.0, maxExtent);
    double lower, upper;
    final u = uniform;
    if (u != null) {
      final i = (clamped / u).floor();
      lower = i * u;
      upper = (i + 1) * u;
    } else {
      final i = indexAt(clamped);
      lower = starts[i];
      upper = starts[math.min(i + 1, itemCount)];
    }
    lower = math.min(lower, maxExtent);
    upper = math.min(upper, maxExtent);
    return (clamped - lower) <= (upper - clamped) ? lower : upper;
  }
}

/// 列级吸附物理（V3）：摩擦模拟求自然停点 → 取最近列边缘 →
/// `FrictionSimulation.through` 以摩擦手感精确停靠；
/// 松手零速/反向微距时用弹簧归位。静止态数学上必在列边缘或卷尾。
class ColumnSnapPhysics extends ScrollPhysics {
  const ColumnSnapPhysics({required this.metrics, super.parent});

  final SnapMetrics metrics;

  @override
  ColumnSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      ColumnSnapPhysics(metrics: metrics, parent: buildParent(ancestor));

  /// 拖拽系数（2026-07-20 两轮手感调参：0.135→0.05→0.01,
  /// 「滑了很快就停」——行程 ≈ v/4.6,重惯性彻底收干）。
  static const double _drag = 0.01;

  /// 轻扫成列阈值：初速达到即保证至少推进一列（吸附果断,不回拉）。
  static const double _commitVelocity = 250;

  /// 归位弹簧（刚度 100→400）：松手微调的「吸力」明显更强。
  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 0.5,
        stiffness: 400,
        ratio: 1.1,
      );

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // 越界回弹/钳制交还父类；吸附只在界内生效。
    if (position.pixels < position.minScrollExtent ||
        position.pixels > position.maxScrollExtent) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final natural =
        FrictionSimulation(_drag, position.pixels, velocity).finalX;
    var target = metrics
        .nearestBoundary(natural, maxExtent: position.maxScrollExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    // 轻扫必进一列：有明确初速却被就近取整拉回原列时,朝滑动方向
    // 推进到相邻边界（大列距/低速场景的吸附果断性保证）。
    if (velocity.abs() >= _commitVelocity) {
      if (velocity > 0 && target <= position.pixels + 0.5) {
        target = metrics
            .boundaryAfter(position.pixels,
                maxExtent: position.maxScrollExtent)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
      } else if (velocity < 0 && target >= position.pixels - 0.5) {
        target = metrics
            .boundaryBefore(position.pixels)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
      }
    }
    final delta = target - position.pixels;
    if (delta.abs() < tolerance.distance && velocity.abs() < tolerance.velocity) {
      return null; // 已静止在列边缘。
    }
    if (velocity.abs() > tolerance.velocity && velocity.sign == delta.sign) {
      // 摩擦直达：保持惯性手感。through 到达目标时仍带末速会滑过头
      // （实测过冲 ~0.15px）——包一层「到点即止」,落点精确为列边缘。
      return _SnapArrivalSimulation(
        FrictionSimulation.through(position.pixels, target, velocity,
            tolerance.velocity * velocity.sign),
        target,
        tolerance: tolerance,
      );
    }
    // 松手零速/惯性方向与目标相反：弹簧微调归位。
    return ScrollSpringSimulation(spring, position.pixels, target, velocity,
        tolerance: tolerance);
  }
}

/// 跨列反馈调度（V5，vertical-scroll-plan.md §3.4）：lead 条目（视口
/// 右缘=阅读位置所在列）变化即一次「跨越新列」；40ms 节流防快速惯性
/// 滑动机枪式连触。初始定位不触发。
class ColumnCrossFeedback {
  ColumnCrossFeedback({
    required this.trigger,
    this.throttle = const Duration(milliseconds: 40),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// 反馈动作（触觉 + 预留音效接口的组合由调用方注入）。
  final VoidCallback trigger;
  final Duration throttle;
  final DateTime Function() _clock;

  int? _lastLead;
  DateTime? _lastFired;

  void onLead(int lead) {
    if (_lastLead == lead) return;
    final isFirst = _lastLead == null;
    _lastLead = lead;
    if (isFirst) return; // 建立基准（初始定位/跳转落点）不触发。
    final now = _clock();
    if (_lastFired != null && now.difference(_lastFired!) < throttle) return;
    _lastFired = now;
    trigger();
  }

  /// 跳转/重排后重建基准，避免落点被计为一次跨列。
  void rebase() => _lastLead = null;
}

/// 到点即止：x 钳制在目标、抵达即 done——摩擦手感 + 零过冲。
class _SnapArrivalSimulation extends Simulation {
  _SnapArrivalSimulation(this._inner, this.target, {super.tolerance})
      : _forward = target >= _inner.x(0);

  final Simulation _inner;
  final double target;
  final bool _forward;

  @override
  double x(double time) {
    final v = _inner.x(time);
    return _forward ? math.min(v, target) : math.max(v, target);
  }

  @override
  double dx(double time) => isDone(time) ? 0 : _inner.dx(time);

  @override
  bool isDone(double time) {
    final v = _inner.x(time);
    return (_forward ? v >= target : v <= target) || _inner.isDone(time);
  }
}
