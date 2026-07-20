import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/presentation/widgets/column_snap_physics.dart';

/// V3——SnapMetrics 与 ColumnSnapPhysics（vertical-scroll-plan.md §3.3）：
/// A-VS1 任意初速的 ballistic 落点 ∈ 边界表；A-VS2 均匀快路与二分同输出。
void main() {
  group('SnapMetrics', () {
    test('均匀表:前缀/定位/最近边界', () {
      final m = SnapMetrics(List.filled(10, 35.0));
      expect(m.uniform, 35.0);
      expect(m.totalExtent, 350);
      expect(m.offsetOf(3), 105);
      expect(m.indexAt(0), 0);
      expect(m.indexAt(34.9), 0);
      expect(m.indexAt(35.0), 1);
      expect(m.nearestBoundary(52, maxExtent: 300), 35);
      expect(m.nearestBoundary(53, maxExtent: 300), 70);
      expect(m.nearestBoundary(9999, maxExtent: 300), 300,
          reason: '卷尾以 maxExtent 收尾(B2)');
    });

    test('非均匀表(含插图条目):二分与暴力最近一致(A-VS2)', () {
      final extents = [35.0, 35.0, 640.0, 35.0, 35.0, 640.0, 35.0];
      final m = SnapMetrics(extents);
      expect(m.uniform, isNull);
      const maxExtent = 1000.0;
      final candidates = [
        for (final s in m.starts)
          if (s <= maxExtent) s,
        maxExtent,
      ];
      for (var x = 0.0; x <= maxExtent; x += 7.3) {
        double brute = candidates.first;
        for (final c in candidates) {
          if ((x - c).abs() < (x - brute).abs()) brute = c;
        }
        expect(m.nearestBoundary(x, maxExtent: maxExtent),
            moreOrLessEquals(brute),
            reason: 'x=$x');
      }
    });

    test('空表/单条目退化', () {
      expect(SnapMetrics(const []).nearestBoundary(50, maxExtent: 100), 0);
      final one = SnapMetrics(const [35.0]);
      expect(one.indexAt(10), 0);
      expect(one.nearestBoundary(10, maxExtent: 0), 0);
    });
  });

  group('ColumnSnapPhysics（A-VS1:落点恒为列边缘）', () {
    final metrics = SnapMetrics(List.filled(60, 35.0)); // 总长 2100
    const viewport = 630.0;
    final maxExtent = metrics.totalExtent - viewport; // 1470

    double settle(double pixels, double velocity) {
      final physics = ColumnSnapPhysics(metrics: metrics);
      final position = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: maxExtent,
        pixels: pixels,
        viewportDimension: viewport,
        axisDirection: AxisDirection.left,
        devicePixelRatio: 1.5,
      );
      final sim = physics.createBallisticSimulation(position, velocity);
      if (sim == null) return pixels; // 已静止于边界
      var t = 0.0;
      while (!sim.isDone(t) && t < 30) {
        t += 1 / 60;
      }
      return sim.x(t);
    }

    test('多组初速/位置的落点都在列边缘(含零速微调与反向)', () {
      final boundaries = {
        for (final s in metrics.starts)
          if (s <= maxExtent) (s * 10).round(),
        (maxExtent * 10).round(),
      };
      for (final pixels in [0.0, 17.0, 35.0, 700.0, 703.3, 1460.0]) {
        for (final v in [-3000.0, -800.0, -90.0, 0.0, 90.0, 800.0, 3000.0]) {
          final end = settle(pixels, v);
          expect(end, inInclusiveRange(0, maxExtent),
              reason: 'p=$pixels v=$v 落点越界');
          expect(boundaries.contains((end * 10).round()), isTrue,
              reason: 'p=$pixels v=$v → $end 不是列边缘');
        }
      }
    });

    test('轻扫必进一列:初速≥阈值时不被就近取整拉回原列', () {
      // 从列边缘 700 出发。v=300(≥250 阈值):即使自然停点取整回落,
      // 也必须推进到相邻边界 735/665。
      expect(settle(700, 300), greaterThanOrEqualTo(735));
      expect(settle(700, -300), lessThanOrEqualTo(665));
      // v=100(<阈值)的微推:允许就近回位,但仍必须落在边界上
      // (由上面的全组落点断言覆盖)。
    });

    test('boundaryAfter/Before:相邻边界与收尾钳制', () {
      final m = SnapMetrics(List.filled(10, 35.0));
      expect(m.boundaryAfter(700 % 350, maxExtent: 300), 35);
      expect(m.boundaryAfter(35, maxExtent: 300), 70);
      expect(m.boundaryAfter(295, maxExtent: 300), 300, reason: '收尾钳制');
      expect(m.boundaryBefore(35), 0);
      expect(m.boundaryBefore(36), 35);
      expect(m.boundaryBefore(0), 0);
      final nu = SnapMetrics(const [35.0, 640.0, 35.0]);
      expect(nu.boundaryAfter(10, maxExtent: 1000), 35);
      expect(nu.boundaryAfter(35, maxExtent: 1000), 675);
      expect(nu.boundaryBefore(675), 35);
      expect(nu.boundaryBefore(700), 675);
    });

    test('大初速直达为摩擦模拟(惯性手感),微距归位为弹簧', () {
      final physics = ColumnSnapPhysics(metrics: metrics);
      final pos = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: maxExtent,
        pixels: 700,
        viewportDimension: viewport,
        axisDirection: AxisDirection.left,
        devicePixelRatio: 1.5,
      );
      expect(physics.createBallisticSimulation(pos, 2500),
          isNot(isA<ScrollSpringSimulation>()));
      final drift = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: maxExtent,
        pixels: 703.3,
        viewportDimension: viewport,
        axisDirection: AxisDirection.left,
        devicePixelRatio: 1.5,
      );
      expect(physics.createBallisticSimulation(drift, 0),
          isA<ScrollSpringSimulation>());
    });
  });

  group('ColumnCrossFeedback（V5:跨列反馈调度）', () {
    test('lead 变化触发;建立基准不触发;同 lead 不重复;回退也算跨列', () {
      var fired = 0;
      var now = DateTime(2026, 1, 1);
      final f = ColumnCrossFeedback(trigger: () => fired++, clock: () => now);
      f.onLead(3);
      expect(fired, 0, reason: '首个 lead 是基准');
      now = now.add(const Duration(milliseconds: 100));
      f.onLead(4);
      expect(fired, 1);
      f.onLead(4);
      expect(fired, 1, reason: '同 lead 不重复');
      now = now.add(const Duration(milliseconds: 100));
      f.onLead(3);
      expect(fired, 2, reason: '回退方向同样是跨列');
    });

    test('40ms 节流:快速连跨合并', () {
      var fired = 0;
      var now = DateTime(2026, 1, 1);
      final f = ColumnCrossFeedback(trigger: () => fired++, clock: () => now);
      f.onLead(0);
      now = now.add(const Duration(milliseconds: 50));
      f.onLead(1);
      expect(fired, 1);
      now = now.add(const Duration(milliseconds: 10));
      f.onLead(2);
      now = now.add(const Duration(milliseconds: 10));
      f.onLead(3);
      expect(fired, 1, reason: '节流窗口内不重复触发');
      now = now.add(const Duration(milliseconds: 50));
      f.onLead(4);
      expect(fired, 2);
    });

    test('rebase 后的落点不计为跨列（跳转/重排场景）', () {
      var fired = 0;
      var now = DateTime(2026, 1, 1);
      final f = ColumnCrossFeedback(trigger: () => fired++, clock: () => now);
      f.onLead(0);
      now = now.add(const Duration(milliseconds: 100));
      f.onLead(5);
      expect(fired, 1);
      f.rebase();
      f.onLead(20);
      expect(fired, 1, reason: '跳转落点不震');
    });
  });
}
