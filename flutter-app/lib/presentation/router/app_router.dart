import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/fonts/font_service.dart';
import '../../core/ink/canvas/ink_scroll_canvas.dart';
import '../../core/ink/shading/ink_bloom_reveal.dart';

import '../pages/about_page.dart';
import '../pages/dict_page.dart';
import '../pages/downloads_page.dart';
import '../pages/home_page.dart';
import '../pages/mystudy_page.dart';
import '../pages/reader_page.dart';
import '../pages/search_page.dart';
import '../pages/section_page.dart';
import '../pages/settings_page.dart';
import '../pages/shell_page.dart';
import '../providers/app_providers.dart';

/// App 级 redirect（巡检主题切换 + 画卷相机驱动）。
/// 公开为顶层函数：路由回归测试（P2.4）用同一逻辑驱动 stub 路由表。
String? inkAppRedirect(BuildContext context, GoRouterState state) {
  if (!kReleaseMode) {
    final themeKey = state.uri.queryParameters['theme'];
    if (themeKey != null && themeKey.isNotEmpty) {
      final container = ProviderScope.containerOf(context, listen: false);
      if (container.read(settingsProvider).themeKey != themeKey) {
        // 路由解析阶段不能同步改 provider 状态，推迟到下一个事件循环。
        Future(() {
          container.read(settingsProvider.notifier).setTheme(themeKey);
        });
      }
    }
    // 巡检字体切换（P3.4 八字体截图通道）：?font=<AppFont.key>，仅切换
    // 不持久化。
    final fontKey = state.uri.queryParameters['font'];
    if (fontKey != null) {
      final container = ProviderScope.containerOf(context, listen: false);
      Future(() {
        container
            .read(fontControllerProvider.notifier)
            .select(AppFont.fromKey(fontKey));
      });
    }
  }
  // 画卷相机（P2.2）：三 tab = 长卷三段横移；push 详情 = 深入画中。
  // 延迟 320ms：与页面转场（300ms）解耦——转场期间画卷保持快照静止
  // （实画山每帧 ~7ms，叠在转场上必超预算，见 §9），转场收尾后再缓动。
  final path = state.uri.path;
  final seq = ++_cameraNavSeq;
  Future<void>.delayed(const Duration(milliseconds: 320), () {
    if (seq != _cameraNavSeq) return; // 已被更新的导航取代
    switch (path) {
      case '/':
        inkCanvasCamera.moveTo(pan: 0, depth: 0);
      case '/search':
        inkCanvasCamera.moveTo(pan: 0.5, depth: 0);
      case '/mystudy':
        inkCanvasCamera.moveTo(pan: 1, depth: 0);
      default:
        inkCanvasCamera.moveTo(depth: 1);
    }
  });
  return null;
}

int _cameraNavSeq = 0;

/// 破墨转场（P2.3，§4.2）：push 300ms / pop 240ms，自最近触点晕开；
/// reduce-motion 时退化为 ≤120ms 淡入（曲线压缩在前 40%）。
///
/// 所有 push 页统一由 [InkPaperBacking] 垫纸（不透明）——画卷层在
/// 详情页下才能停绘（Impeller 无遮挡剔除，性能修正见 §9）；
/// 叙事上 push = 凑近看纸，山在视野之外，pop 回卷面。
CustomTransitionPage<void> inkBloomPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    child: InkPaperBacking(child: child),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // 被更深一层 push 压住时快速退场（与 _StillPageTransitionsBuilder
      // 同步的优化：opacity 0 后整页跳绘，转场帧只剩新页）。
      final covered = FadeTransition(
        opacity: ReverseAnimation(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(0, 0.4),
          ),
        ),
        child: child,
      );
      if (MediaQuery.of(context).disableAnimations) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0, 0.4), // 等效 ≤120ms
          ),
          child: covered,
        );
      }
      return InkBloomReveal(
        progress: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        origin: inkLastPointerDown.value,
        child: covered,
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  // 巡检主题切换（debug/profile）+ 画卷相机驱动，见 inkAppRedirect。
  redirect: inkAppRedirect,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => ShellPage(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const HomePage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/mystudy', builder: (_, __) => const MyStudyPage()),
        ]),
      ],
    ),
    GoRoute(
      path: '/section/:id',
      pageBuilder: (_, state) => inkBloomPage(
          state, SectionPage(sectionId: state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/book/:id',
      pageBuilder: (_, state) {
        final indexParam = state.uri.queryParameters['index'];
        final highlight = state.uri.queryParameters['highlight'];
        return inkBloomPage(
          state,
          ReaderPage(
            bookId: state.pathParameters['id']!,
            initialBlockIndex:
                indexParam == null ? null : int.tryParse(indexParam),
            highlightText: highlight,
          ),
        );
      },
    ),
    GoRoute(
        path: '/dict',
        pageBuilder: (_, state) => inkBloomPage(state, const DictPage())),
    GoRoute(
        path: '/settings',
        pageBuilder: (_, state) => inkBloomPage(state, const SettingsPage())),
    GoRoute(
        path: '/downloads',
        pageBuilder: (_, state) =>
            inkBloomPage(state, const DownloadsPage())),
    GoRoute(
        path: '/about',
        pageBuilder: (_, state) => inkBloomPage(state, const AboutPage())),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(),
    body: Center(child: Text('页面不存在: ${state.uri}')),
  ),
);
