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
  GoRouter buildStubRouter() => GoRouter(
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
    // 相机 moveTo 延迟 320ms（与转场解耦）——假时钟推过它再断言。
    Future<void> settleCamera() async {
      await tester.pump(const Duration(milliseconds: 350));
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
    await settleCamera();
    expect(inkCanvasCamera.depth, 0.0, reason: 'pop 回到卷面');
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
