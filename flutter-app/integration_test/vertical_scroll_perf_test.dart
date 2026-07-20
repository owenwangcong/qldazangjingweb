import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:qldazangjing/main.dart' as app;
import 'package:qldazangjing/presentation/router/app_router.dart';

/// 竖排展卷滚动性能采样（vertical-scroll-plan.md V8;管线同 scroll_perf）。
/// 自行驱动设置面板切「竖排展卷」,不依赖设备预置。
///
///   .\tool\perf.ps1 -Runs 1 -Target integration_test/vertical_scroll_perf_test.dart `
///     -Keys vertical_scroll -Label vscroll
///
/// 产物：build/perf/vertical_scroll.timeline_summary.json
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  Future<void> pumpFor(WidgetTester tester, Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 水平连滚：偶数向前（左→右滑）、奇数回滚,不顶死两端。
  Future<void> scrollLoop(WidgetTester tester, Finder target,
      {int rounds = 16}) async {
    for (var i = 0; i < rounds; i++) {
      final dx = i.isEven ? 650.0 : -650.0;
      await tester.fling(target, Offset(dx, 0), 2200);
      await pumpFor(tester, const Duration(milliseconds: 700));
    }
  }

  testWidgets('vertical scroll perf', (tester) async {
    await app.main();
    await pumpFor(tester, const Duration(seconds: 4));

    appRouter.push('/book/0001-01');
    await pumpFor(tester, const Duration(seconds: 8));

    // 切到竖排展卷：阅读设置 → 竖排展卷 → 收起面板。
    await tester.tap(find.byTooltip('阅读设置'));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.tap(find.text('竖排展卷'));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.tapAt(const Offset(400, 80));
    await pumpFor(tester, const Duration(seconds: 2));

    final list = find.byType(ListView).hitTestable();
    expect(list, findsOneWidget, reason: '展卷视图未建立');

    // 预热（字形缓存构建）后热控静置,再采样。
    await scrollLoop(tester, list.first, rounds: 4);
    await Future<void>.delayed(const Duration(seconds: 30));

    await binding.traceAction(
      () => scrollLoop(tester, list.first),
      reportKey: 'vertical_scroll',
    );
  }, timeout: const Timeout(Duration(minutes: 6)));
}
