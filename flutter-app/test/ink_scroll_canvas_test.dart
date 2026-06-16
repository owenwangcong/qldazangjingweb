import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:qldazangjing/core/ink/canvas/ink_scroll_canvas.dart';
import 'package:qldazangjing/core/ink/shading/ink_paper_background.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';

/// P2.1 验收：画卷层跨路由持久（State 不重建）、相机可驱动、
/// reduce-motion 下相机瞬移。
void main() {
  GoRouter buildRouter() => GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('页A'))),
          GoRoute(path: '/b', builder: (_, __) => const Scaffold(body: Text('页B'))),
          GoRoute(path: '/c', builder: (_, __) => const Scaffold(body: Text('页C'))),
        ],
      );

  Widget app(GoRouter router) => MaterialApp.router(
        theme: buildAppTheme(AppThemeId.hupochangguang),
        routerConfig: router,
        builder: (context, child) => InkScrollCanvas(child: child!),
      );

  testWidgets('跨多次路由跳转 canvas State 不重建', (tester) async {
    await tester.runAsync(InkPaperBackground.warmUp);
    final router = buildRouter();
    await tester.pumpWidget(app(router));
    final s0 = tester.state<InkScrollCanvasState>(find.byType(InkScrollCanvas));

    router.push('/b');
    await tester.pumpAndSettle();
    expect(find.text('页B'), findsOneWidget);

    router.push('/c');
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    router.go('/');
    await tester.pumpAndSettle();

    final s1 = tester.state<InkScrollCanvasState>(find.byType(InkScrollCanvas));
    expect(identical(s0, s1), isTrue, reason: '画卷层必须跨路由持久');
  });

  testWidgets('相机 moveTo 驱动重绘且值收敛', (tester) async {
    await tester.runAsync(InkPaperBackground.warmUp);
    final router = buildRouter();
    await tester.pumpWidget(app(router));
    final ctx = tester.element(find.text('页A'));
    final camera = InkScrollCanvas.cameraOf(ctx);

    camera.moveTo(pan: 0.5, depth: 0.3);
    expect(camera.pan, 0.5);
    expect(camera.depth, 0.3);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('clamp：相机目标限制在 0..1', (tester) async {
    await tester.runAsync(InkPaperBackground.warmUp);
    final router = buildRouter();
    await tester.pumpWidget(app(router));
    final ctx = tester.element(find.text('页A'));
    final camera = InkScrollCanvas.cameraOf(ctx);
    camera.moveTo(pan: 2.0, depth: -1.0);
    expect(camera.pan, 1.0);
    expect(camera.depth, 0.0);
  });
}
