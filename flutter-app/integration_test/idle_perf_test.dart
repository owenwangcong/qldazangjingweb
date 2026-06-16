import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:qldazangjing/main.dart' as app;

/// P5.2 画布静止重绘探针（§6.1 末行）：首页静置 10s，期间不做任何
/// 交互——快照画卷 + RepaintBoundary 隔离下应几乎无新帧产生
/// （frame_count ≈ 0；EnsoLoading 未挂载、无常驻动画）。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 注意：不用 fullyLive（它会替我们持续打帧，污染静止口径）；
  // benchmarkLive 只在引擎自发请求帧时绘制。
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  testWidgets('idle perf: canvas at rest', (tester) async {
    await app.main();
    // 等首帧 + 纸纹/整卷快照烘焙完成（烘焙在相机停稳后触发）。
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await Future<void>.delayed(const Duration(seconds: 5));

    await binding.traceAction(
      () => Future<void>.delayed(const Duration(seconds: 10)),
      reportKey: 'idle_canvas',
    );
  });
}
