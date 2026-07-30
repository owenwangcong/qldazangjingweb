import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:qldazangjing/main.dart' as app;
import 'package:qldazangjing/presentation/router/app_router.dart';

/// 字重档竖排翻页性能对拍（FQ1 验收 CW,font-weight-quotes-plan.md §4;
/// 管线同 vertical_perf_test.dart）。同一轮内先采标准档基线,再切加粗档
/// (0.04em,每字形 +1 次描边绘制的最坏档)复采,同热况直接对比。
///
/// 不依赖设备预置状态：自行驱动设置面板切「竖排翻页」与「加粗」。
///
///   .\tool\perf.ps1 -Label vweight `
///     -Target integration_test/vertical_weight_perf_test.dart `
///     -Keys vertical_turn_normal,vertical_turn_bold
///
/// 产物：build/perf/vertical_turn_normal|vertical_turn_bold.timeline_summary.json
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

  /// 打开阅读设置弹层,滚到目标项点掉,再点 barrier 收起。
  Future<void> tapInSettingsSheet(WidgetTester tester, String option) async {
    await tester.tap(find.byTooltip('阅读设置'));
    await pumpFor(tester, const Duration(seconds: 1));
    // 弹层主体是 ListView,平板横竖屏下目标行可能在折叠线以下。
    await tester.scrollUntilVisible(find.text(option), 80,
        scrollable: find.byType(Scrollable).hitTestable().first);
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text(option));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.tapAt(const Offset(400, 80));
    await pumpFor(tester, const Duration(seconds: 2));
  }

  testWidgets('vertical page turn perf by font weight gear', (tester) async {
    await app.main();
    await pumpFor(tester, const Duration(seconds: 4));

    appRouter.push('/book/0001-01');
    await pumpFor(tester, const Duration(seconds: 8)); // 内置资产加载

    await tapInSettingsSheet(tester, '竖排翻页'); // 收起后含同步分页 + 首帧

    final pageView = find.byType(PageView).hitTestable();
    expect(pageView, findsOneWidget, reason: '竖排视图未建立');

    // —— 标准档基线 ——
    // 预热：首轮翻页含字形缓存构建,不计入稳态（同 scroll_perf 坑位）。
    await turnLoop(tester, pageView.first, rounds: 4);
    await Future<void>.delayed(const Duration(seconds: 30)); // 热控静置
    await binding.traceAction(
      () => turnLoop(tester, pageView.first),
      reportKey: 'vertical_turn_normal',
    );

    // —— 加粗档（最坏档）——
    // strokeWidthEm 只进样式签名不进分页键：切档不重分页,但字形缓存
    // 整体失效,预热轮重建填充+描边两套 painter。
    await tapInSettingsSheet(tester, '加粗');
    await turnLoop(tester, pageView.first, rounds: 4);
    await Future<void>.delayed(const Duration(seconds: 30)); // 热控静置
    await binding.traceAction(
      () => turnLoop(tester, pageView.first),
      reportKey: 'vertical_turn_bold',
    );
  }, timeout: const Timeout(Duration(minutes: 12)));
}
