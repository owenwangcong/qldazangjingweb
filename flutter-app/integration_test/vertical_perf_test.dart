import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:qldazangjing/main.dart' as app;
import 'package:qldazangjing/presentation/router/app_router.dart';

/// 竖排翻页性能采样（方案 §11,验收 C11;管线同 scroll_perf_test.dart）。
///
/// 不依赖设备预置状态：跨 build 类型安装会清空应用数据（S8 实测:
/// debug→profile 重装后 Isar 设置归零）,故本测试自行驱动设置面板
/// 切到「古籍竖排」再采样。
///
///   flutter drive --driver=test_driver/perf_driver.dart \
///     --target=integration_test/vertical_perf_test.dart --profile -d R52W809056B
///
/// 产物：build/perf/vertical_page_turn.timeline_summary.json
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  Future<void> pumpFor(WidgetTester tester, Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 横向连续翻页：偶数次左→右（下一页）、奇数次回翻,不顶死在两端。
  Future<void> turnLoop(WidgetTester tester, Finder target,
      {int rounds = 16}) async {
    for (var i = 0; i < rounds; i++) {
      final dx = i.isEven ? 700.0 : -700.0;
      await tester.fling(target, Offset(dx, 0), 2500);
      await pumpFor(tester, const Duration(milliseconds: 700));
    }
  }

  testWidgets('vertical page turn perf', (tester) async {
    await app.main();
    await pumpFor(tester, const Duration(seconds: 4));

    appRouter.push('/book/0001-01');
    await pumpFor(tester, const Duration(seconds: 8)); // 内置资产加载

    // 切到竖排：阅读设置 → 古籍竖排 → 收起面板。
    await tester.tap(find.byTooltip('阅读设置'));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.tap(find.text('古籍竖排'));
    await pumpFor(tester, const Duration(seconds: 1));
    // 点面板外 barrier 收起 BottomSheet。
    await tester.tapAt(const Offset(400, 80));
    await pumpFor(tester, const Duration(seconds: 2)); // 同步分页 + 首帧

    final pageView = find.byType(PageView).hitTestable();
    expect(pageView, findsOneWidget, reason: '竖排视图未建立');

    // 预热：首轮翻页含字形缓存构建,不计入稳态基线（同 scroll_perf 坑位）。
    await turnLoop(tester, pageView.first, rounds: 4);
    await Future<void>.delayed(const Duration(seconds: 30)); // 热控静置

    await binding.traceAction(
      () => turnLoop(tester, pageView.first),
      reportKey: 'vertical_page_turn',
    );
  }, timeout: const Timeout(Duration(minutes: 6)));
}
