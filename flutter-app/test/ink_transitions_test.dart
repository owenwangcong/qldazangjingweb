import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
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
            // 与 appRouter 同构：shell 走 CustomTransitionPage，
            // secondaryAnimation 接线（conceal 生效，平滑化步骤 3）。
            pageBuilder: (context, state, shell) => CustomTransitionPage<void>(
              key: state.pageKey,
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      InkCoveredPage(
                secondaryAnimation: secondaryAnimation,
                child: child,
              ),
              child: Scaffold(
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
      await tester.pump(const Duration(milliseconds: 550));
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
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    router.push('/settings');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(inkCanvasCamera.depth, 1.0);

    // 系统返回：routerDelegate.popRoute() 路径，redirect 不会执行。
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await tester.pump();
    expect(inkCanvasCamera.depth, 0.0,
        reason: '系统返回必须同样驱动相机，否则画卷永久停绘（黑底）');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('设置页'), findsNothing);
  });

  test('步骤0 半径包络：p=1 全屏覆盖（最小 wobble 方向亦然）、p→0 收敛到种子斑',
      () {
    const size = Size(800, 600);
    for (final origin in [const Offset(200, 150), const Offset(780, 580)]) {
      // p=1：四角全部在墨晕内（修复 1.22 只乘线性项导致的远角残片）。
      final full = inkBloomPath(size, 1.0, origin);
      for (final corner in [
        Offset.zero,
        Offset(size.width, 0),
        Offset(0, size.height),
        Offset(size.width, size.height),
      ]) {
        expect(full.contains(corner), isTrue,
            reason: 'p=1 时角 $corner 应已被墨晕覆盖（origin=$origin）');
      }
      // p→0⁺：种子斑存在（origin 邻域内）而非凭空出现的零半径。
      final seed = inkBloomPath(size, 0.001, origin);
      expect(seed.contains(origin), isTrue, reason: '种子斑应包含触点');
      expect(seed.getBounds().width, greaterThan(20),
          reason: '种子斑半径应有可见尺度（r0≈28）');

      // S3 径向偏移：外扩/内缩路径与基准路径严格嵌套（环带构造前提）。
      final base = inkBloomPath(size, 0.5, origin);
      final outer = inkBloomPath(size, 0.5, origin, radiusOffset: 30);
      final inner = inkBloomPath(size, 0.5, origin, radiusOffset: -30);
      for (var t = 0.0; t < 1.0; t += 0.1) {
        final m = base.computeMetrics().first;
        final pt = m.getTangentForOffset(m.length * t)!.position;
        expect(outer.contains(pt), isTrue,
            reason: '基准轮廓上的点应在 +30 外扩路径内');
        expect(inner.contains(pt), isFalse,
            reason: '基准轮廓上的点应在 -30 内缩路径外');
      }
    }
  });

  testWidgets('S 平滑化：tab→push 转场 shell 也被反向裁剪（secondary 已接线）',
      (tester) async {
    await warmInkShaders(tester);
    final router = buildStubRouter();
    await tester.pumpWidget(app(router));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    router.push('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120)); // 转场中段
    // shell 改 CustomTransitionPage 后 secondaryAnimation 不再恒 0
    // （InkCoveredPage 接线；Plan B 下正常动效为裸 child，shell 全程绘制）。
    expect(find.byType(InkCoveredPage), findsWidgets,
        reason: 'shell 的 secondaryAnimation 应已接线');
    expect(find.byType(ClipPath), findsAtLeastNWidgets(1),
        reason: '上层 reveal 裁剪在场');
    expect(find.text('+1'), findsOneWidget, reason: 'shell 内容仍在绘制');

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  });

  testWidgets('F1 push↔push 转场：下层页反向裁剪参与绘制（非 opacity 隐身）',
      (tester) async {
    await warmInkShaders(tester);
    final router = buildStubRouter();
    await tester.pumpWidget(app(router));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Plan B：被盖页不做任何处理（无 conceal 裁剪、无 opacity 隐身），
    // 上层 opaque 页的 reveal 裁剪自然覆盖——旧 fade 方案曾把下层页
    // 隐身、露出停绘的黑底。
    router.push('/settings');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    router.push('/book/0001-01');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // 深 push 中段
    // 上层 reveal 一个 ClipPath；下层内容原样在绘（无 FadeTransition 隐身）。
    expect(find.byType(ClipPath), findsAtLeastNWidgets(1));
    expect(find.text('设置页'), findsOneWidget,
        reason: '下层 push 页原样参与绘制，非隐身');

    // pop 早期：下层页即刻可见（旧方案前 60% 隐身）。
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60)); // pop 前段
    expect(find.byType(ClipPath), findsAtLeastNWidgets(1));
    expect(find.text('设置页'), findsOneWidget,
        reason: 'pop 早期下层页即刻可见');

    await tester.pump(const Duration(milliseconds: 600));
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
    await tester.pump(const Duration(milliseconds: 600)); // 冲掉相机延迟定时器
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
    await tester.pump(const Duration(milliseconds: 600));
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
    await tester.pump(const Duration(milliseconds: 600)); // 冲掉相机延迟定时器
  });

  testWidgets('P2.4 深链直达带参数', (tester) async {
    await warmInkShaders(tester);
    final router = buildStubRouter();
    await tester.pumpWidget(app(router));
    await tester.pumpAndSettle();

    router.go('/book/0001-01?index=5');
    await tester.pumpAndSettle();
    expect(find.text('book=0001-01 index=5'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600)); // 冲掉相机延迟定时器
  });

  testWidgets('开发者工具：深链 ?dilation= 设置全局 timeDilation 并夹紧范围',
      (tester) async {
    // 框架不变量要求测试体结束前复位 timeDilation → finally 兜底。
    try {
      await warmInkShaders(tester);
      final router = buildStubRouter();
      await tester.pumpWidget(app(router));
      await tester.pumpAndSettle();

      router.go('/search?dilation=4');
      await tester.pump();
      expect(timeDilation, 4.0);

      router.go('/?dilation=99'); // 超界 → 夹到 10
      await tester.pump();
      expect(timeDilation, 10.0);
    } finally {
      timeDilation = 1.0;
    }
    // 复位后再冲掉（按慢放 ×10 调度的）相机定时器。
    await tester.pump(const Duration(milliseconds: 6000));
    await tester.pumpAndSettle();
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
