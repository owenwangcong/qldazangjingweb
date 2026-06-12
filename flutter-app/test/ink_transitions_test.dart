import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:qldazangjing/core/ink/canvas/ink_scroll_canvas.dart';
import 'package:qldazangjing/core/ink/shading/ink_bloom_reveal.dart';
import 'package:qldazangjing/core/ink/shading/ink_paper_background.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';
import 'package:qldazangjing/presentation/router/app_router.dart';

/// P2.2/P2.3/P2.4 验收：相机随路由移动、破墨转场可中断、
/// reduce-motion 退化、tab 保活、深链参数解析。
///
/// 用与 appRouter 同构的 stub 路由表（同一 redirect 与转场封装），
/// 避免真实页面对 Isar/网络的依赖。
void main() {
  GoRouter buildStubRouter() {
    final router = GoRouter(
        initialLocation: '/',
        redirect: inkAppRedirect,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => Scaffold(
              body: shell,
              bottomNavigationBar: NavigationBar(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: (i) => shell.goBranch(i),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: 'A'),
                  NavigationDestination(icon: Icon(Icons.search), label: 'B'),
                  NavigationDestination(icon: Icon(Icons.person), label: 'C'),
                ],
              ),
            ),
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(path: '/', builder: (_, __) => const _Counter(tag: 'home')),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/search', builder: (_, __) => const Text('搜索页')),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/mystudy', builder: (_, __) => const Text('我的页')),
              ]),
            ],
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (_, state) => inkBloomPage(state, const Text('设置页')),
          ),
          GoRoute(
            path: '/book/:id',
            pageBuilder: (_, state) => inkBloomPage(
              state,
              Text(
                'book=${state.pathParameters['id']} '
                'index=${state.uri.queryParameters['index']}',
              ),
            ),
          ),
        ],
      );
    // 相机驱动与 appRouter 同构（routerDelegate listener，坑12）。
    attachInkCameraDriver(router);
    return router;
  }

  Widget app(GoRouter router, {bool reduceMotion = false}) =>
      MaterialApp.router(
        theme: buildAppTheme(AppThemeId.hupochangguang),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: InkScrollCanvas(child: child!),
        ),
      );

  setUp(() {
    inkCanvasCamera.moveTo(pan: 0, depth: 0);
  });

  // 坑6：静态 shader future 若在 FakeAsync 区内被首次创建（如转场路由
  // 顺带 build 了 InkBloomReveal），将永远无法完成并毒化后续所有测试的
  // runAsync 等待——每个测试必须先在真实异步区把两个 shader 都预热完。
  Future<void> warmInkShaders(WidgetTester tester) =>
      tester.runAsync(InkPaperBackground.warmUp);

  testWidgets('P2.2 相机随路由移动：tab 横移、push 纵深', (tester) async {
    await warmInkShaders(tester);
    final router = buildStubRouter();
    await tester.pumpWidget(app(router));
    // 相机延迟：tab 横移 320ms / push 跳变 400ms——假时钟推过再断言。
    Future<void> settleCamera() async {
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
    }

    await settleCamera();
    expect(inkCanvasCamera.pan, 0);
    expect(inkCanvasCamera.depth, 0);

    router.go('/search');
    await settleCamera();
    expect(inkCanvasCamera.pan, 0.5);

    router.go('/mystudy');
    await settleCamera();
    expect(inkCanvasCamera.pan, 1.0);

    router.push('/settings');
    await settleCamera();
    expect(inkCanvasCamera.depth, 1.0);
    expect(inkCanvasCamera.pan, 1.0, reason: 'push 不改变横向视点');

    router.pop();
    // 坑12 修正后：pop 回卷面立即 jump 落位（不等 320ms），
    // 否则透明 tab 页会浮在停绘的黑底上。
    await tester.pump();
    expect(inkCanvasCamera.depth, 0.0, reason: 'pop 立即回到卷面');
    await settleCamera(); // 冲掉残留定时器
  });

  testWidgets('坑12 回归：系统返回键 pop 后相机立即归零（不经 redirect）',
      (tester) async {
    await warmInkShaders(tester);
    final router = buildStubRouter();
    await tester.pumpWidget(app(router));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    router.push('/settings');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(inkCanvasCamera.depth, 1.0);

    // 系统返回：routerDelegate.popRoute() 路径，redirect 不会执行。
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await tester.pump();
    expect(inkCanvasCamera.depth, 0.0,
        reason: '系统返回必须同样驱动相机，否则画卷永久停绘（黑底）');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('设置页'), findsNothing);
  });

  test('F1 conceal 与 reveal 墨缘互补：任意采样点恰好属于一页', () {
    const size = Size(800, 600);
    const origin = Offset(200, 150);
    for (final p in [0.15, 0.4, 0.7, 0.9]) {
      final blob = inkBloomPath(size, p, origin);
      final conceal = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addPath(inkBloomPath(size, p, origin), Offset.zero);
      for (var x = 5.0; x < size.width; x += 45) {
        for (var y = 5.0; y < size.height; y += 45) {
          final pt = Offset(x, y);
          expect(conceal.contains(pt), !blob.contains(pt),
              reason: 'p=$p 处 $pt 应恰好属于 reveal 或 conceal 之一');
        }
      }
    }
  });

  testWidgets('F1 push↔push 转场：下层页反向裁剪参与绘制（非 opacity 隐身）',
      (tester) async {
    await warmInkShaders(tester);
    final router = buildStubRouter();
    await tester.pumpWidget(app(router));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // 注：shell（MaterialPage）的 canTransitionTo 不接受 CustomTransitionRoute，
    // 其 secondaryAnimation 恒为 0 → tab 页被 push 覆盖时全程保持原样绘制
    // （天然无露底）。conceal 生效区是 push↔push 之间——旧 fade 方案正是
    // 在这里把下层页隐身、露出停绘的黑底。
    router.push('/settings');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    router.push('/book/0001-01');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // 深 push 中段
    // 上层 reveal + 下层 conceal 各一个 ClipPath；下层内容仍在绘制。
    expect(find.byType(ClipPath), findsAtLeastNWidgets(2));
    expect(find.text('设置页'), findsOneWidget,
        reason: '下层 push 页以反向裁剪参与绘制，非隐身');

    // pop 早期：下层页立即以裁剪态显示（旧方案前 60% 隐身）。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60)); // pop 前段（240ms 的 1/4）
    expect(find.byType(ClipPath), findsAtLeastNWidgets(2));
    expect(find.text('设置页'), findsOneWidget,
        reason: 'pop 早期下层页即被反向裁剪显示');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('book=0001-01 index=null'), findsNothing);
  });

  testWidgets('P2.3 破墨转场存在且中途 pop 不崩溃', (tester) async {
    await warmInkShaders(tester);
    final router = buildStubRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    router.push('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120)); // 转场中段
    expect(find.byType(InkBloomReveal), findsOneWidget);

    router.pop(); // 中断转场
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400)); // 冲掉相机延迟定时器
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('设置页'), findsNothing);
  });

  testWidgets('P2.3 reduce-motion 退化为快速淡入（无破墨层）', (tester) async {
    await warmInkShaders(tester);
    final router = buildStubRouter();
    await tester.pumpWidget(app(router, reduceMotion: true));
    await tester.pumpAndSettle();

    router.push('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(InkBloomReveal), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('设置页'), findsOneWidget);
  });

  testWidgets('P2.4 tab 保活：切走再回状态不丢', (tester) async {
    await warmInkShaders(tester);
    final router = buildStubRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+1'));
    await tester.pump();
    expect(find.text('home:1'), findsOneWidget);

    router.go('/search');
    await tester.pumpAndSettle();
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('home:1'), findsOneWidget, reason: 'IndexedStack 保活');
    await tester.pump(const Duration(milliseconds: 400)); // 冲掉相机延迟定时器
  });

  testWidgets('P2.4 深链直达带参数', (tester) async {
    await warmInkShaders(tester);
    final router = buildStubRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    router.go('/book/0001-01?index=5');
    await tester.pumpAndSettle();
    expect(find.text('book=0001-01 index=5'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400)); // 冲掉相机延迟定时器
  });
}

class _Counter extends StatefulWidget {
  const _Counter({required this.tag});

  final String tag;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${widget.tag}:$n'),
        TextButton(onPressed: () => setState(() => n++), child: const Text('+1')),
      ],
    );
  }
}
