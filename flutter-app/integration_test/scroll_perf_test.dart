import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:qldazangjing/main.dart' as app;
import 'package:qldazangjing/presentation/router/app_router.dart';

/// 滚动性能采样（docs/ink-design-plan.md §6.1）。
/// gfxinfo 对 Flutter 自绘管线无效（Total frames = 0，已实测），
/// 故用 Flutter 官方 traceAction 时间线作为唯一性能口径。必须 profile 模式：
///
///   flutter drive --driver=test_driver/perf_driver.dart \
///     --target=integration_test/scroll_perf_test.dart --profile -d R52W809056B
///
/// 产物：build/perf/{home_scroll,reader_scroll}.timeline_summary.json
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // pumpAndSettle 在存在常驻动画时会挂死，统一用定长 pump。
  Future<void> pumpFor(WidgetTester tester, Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> flingLoop(WidgetTester tester, Finder target,
      {int rounds = 16}) async {
    for (var i = 0; i < rounds; i++) {
      // 偶数次向下滚（内容上移），奇数次回滚，保证不顶死在列表两端。
      final dy = i.isEven ? -900.0 : 900.0;
      await tester.fling(target, Offset(0, dy), 2500);
      await pumpFor(tester, const Duration(milliseconds: 900));
    }
  }

  // 热控（坑7）：被动散热平板上连续采样会热节流——首测 home 变重后
  // reader raster p90 被均匀钳在 31ms（基线 3.9ms）。每段采样前静置降温。
  const cooldown = Duration(seconds: 45);

  testWidgets('scroll perf: home + reader', (tester) async {
    await app.main();
    await pumpFor(tester, const Duration(seconds: 4)); // 目录流 + 首帧安定

    // ---- 首页（部类目录长列表） ----------------------------------------
    final homeList = find.byType(CustomScrollView).hitTestable().first;
    // 预热：首次滚动含 raster 缓存构建，不计入稳态基线（冒烟跑实测
    // 预热污染让 home jank_raster 高达 83%）。
    await flingLoop(tester, homeList, rounds: 4);
    await Future<void>.delayed(cooldown);
    await binding.traceAction(
      () => flingLoop(tester, homeList),
      reportKey: 'home_scroll',
    );

    // ---- Reader（正文长卷，最重的滚动场景） ------------------------------
    appRouter.push('/book/0001-01');
    await pumpFor(tester, const Duration(seconds: 8)); // 正文加载（已内置资产）

    final readerList = find.byType(Scrollable).hitTestable().first;
    await flingLoop(tester, readerList, rounds: 4); // 预热，同上
    await Future<void>.delayed(cooldown);
    await binding.traceAction(
      () => flingLoop(tester, readerList),
      reportKey: 'reader_scroll',
    );

    // ---- 破墨转场（push/pop ×10，§6.1 第 3 行） -------------------------
    appRouter.pop(); // 退出 Reader 回卷面
    await pumpFor(tester, const Duration(milliseconds: 600));
    await Future<void>.delayed(cooldown);
    await binding.traceAction(
      () async {
        for (var i = 0; i < 10; i++) {
          appRouter.push('/settings');
          await pumpFor(tester, const Duration(milliseconds: 450));
          appRouter.pop();
          await pumpFor(tester, const Duration(milliseconds: 400));
        }
      },
      reportKey: 'transition',
    );
  });
}
