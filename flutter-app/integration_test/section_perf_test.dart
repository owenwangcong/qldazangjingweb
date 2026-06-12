import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:qldazangjing/main.dart' as app;
import 'package:qldazangjing/presentation/router/app_router.dart';

/// P3.3 专用：Section 长列表滚动采样（部类 01 = 大乘般若部，55 册）。
/// 与 scroll_perf_test 同口径（profile + traceAction + 热控协议）；
/// 独立成文件以免拖长 §6.1 主采样的轮时长。改造前基线在 e26eef92
/// worktree 上跑同一文件取得。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  Future<void> pumpFor(WidgetTester tester, Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> flingLoop(WidgetTester tester, Finder target,
      {int rounds = 16}) async {
    for (var i = 0; i < rounds; i++) {
      final dy = i.isEven ? -900.0 : 900.0;
      await tester.fling(target, Offset(0, dy), 2500);
      await pumpFor(tester, const Duration(milliseconds: 900));
    }
  }

  const cooldown = Duration(seconds: 45);

  testWidgets('scroll perf: section list', (tester) async {
    await app.main();
    await pumpFor(tester, const Duration(seconds: 4));

    appRouter.push('/section/01');
    await pumpFor(tester, const Duration(seconds: 2));

    final list = find.byType(ListView).hitTestable().first;
    await flingLoop(tester, list, rounds: 4); // 预热（首滚污染，见 §6.1）
    await Future<void>.delayed(cooldown);
    await binding.traceAction(
      () => flingLoop(tester, list),
      reportKey: 'section_scroll',
    );
  });
}
