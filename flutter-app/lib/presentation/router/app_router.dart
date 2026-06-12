import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
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

/// App 级 redirect（仅剩巡检通道：主题/字体切换）。
/// 公开为顶层函数：路由回归测试（P2.4）用同一逻辑驱动 stub 路由表。
///
/// 注意：画卷相机驱动**不在这里**——系统返回键走
/// `routerDelegate.popRoute() → maybePop → notifyListeners`，根本不经
/// redirect（坑12：曾导致系统返回后相机停在 depth=1、画卷永久停绘、
/// 透明 tab 页浮在黑底上）。相机驱动见 [attachInkCameraDriver]。
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
    // 动画慢放/加速（开发者工具）：?dilation=<0.1..10>，驱动全局
    // timeDilation——慢动作转场取证不再需要临时改代码重编译（坑9）。
    // 与设置页「开发者·动画慢放」滑杆同一开关；不持久化。
    final dilationParam = state.uri.queryParameters['dilation'];
    if (dilationParam != null) {
      final v = double.tryParse(dilationParam);
      if (v != null) timeDilation = v.clamp(0.1, 10.0);
    }
  }
  return null;
}

int _cameraNavSeq = 0;

/// 画卷相机驱动（P2.2，坑12 修正版）：挂在 routerDelegate 上，
/// push/pop/go/**系统返回**全覆盖，每次导航恰好触发一次。
///
/// 规则：**depth 变化一律 jump，pan 变化保持 320ms 延迟 + drift 横移**。
/// - push 详情（depth→1）：320ms 后 jump 落位——0→1 的 drift 全程发生在
///   不透明详情页之下，纯属不可见的实画浪费；延迟保留是为了与 300ms
///   转场解耦（转场期间画卷保持快照静止）。
/// - pop 回 tab（depth→0）：**立即 jump（pan 同步落位）**——既有的
///   (pan, depth 0) 整卷快照立即生效，pop 第一帧就是一次位图 blit，
///   tab 页背景从头到尾是纸面。
/// - tab ↔ tab：维持 320ms 延迟 + 350ms drift（画卷横移本身就是要给
///   用户看的）。
void attachInkCameraDriver(GoRouter router) {
  void sync() {
    // push 出来的路由是 ImperativeRouteMatch，RouteMatchList.uri 仍指向
    // 底层 location——有效路径要从最后一个 imperative match 里取。
    final config = router.routerDelegate.currentConfiguration;
    var uri = config.uri;
    if (config.matches.isNotEmpty) {
      final last = config.matches.last;
      if (last is ImperativeRouteMatch) uri = last.matches.uri;
    }
    final path = uri.path;
    final seq = ++_cameraNavSeq;
    final double? pan = switch (path) {
      '/' => 0,
      '/search' => 0.5,
      '/mystudy' => 1,
      _ => null, // push 路由
    };
    if (pan == null) {
      // 400ms：push 转场 300ms + 100ms 安全边际（jump 即停绘，过早会让
      // tab 页留白区在墨晕未覆盖处闪黑——重帧卡顿时转场可能超 300ms）。
      // 乘 timeDilation：慢动作取证时定时器与转场保持同步（生产恒 1.0）。
      Future<void>.delayed(
          Duration(milliseconds: (400 * timeDilation).round()), () {
        if (seq != _cameraNavSeq) return; // 已被更新的导航取代
        inkCanvasCamera.jumpTo(depth: 1);
      });
    } else if (inkCanvasCamera.depth >= 1) {
      inkCanvasCamera.jumpTo(pan: pan, depth: 0);
    } else {
      // ×timeDilation：慢放调试时画卷横移与（瞬时的）tab 切换保持节奏。
      Future<void>.delayed(
          Duration(milliseconds: (320 * timeDilation).round()), () {
        if (seq != _cameraNavSeq) return;
        inkCanvasCamera.moveTo(pan: pan, depth: 0);
      });
    }
  }

  router.routerDelegate.addListener(sync);
  // 冷启动初始化：深链直达详情页时相机应直接位于画中（depth=1）。
  sync();
}

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
      // 被更深一层 push 压住时：反向墨缘裁剪（与上层 reveal 逐帧互补，
      // 墨晕外保持原样可见——旧的 opacity 淡出会在墨晕未覆盖处露底，
      // 且 0<α<1 整页 saveLayer，转场修复 F1，见 §9）。
      final covered = InkCoveredPage(
        secondaryAnimation: secondaryAnimation,
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

final appRouter = _buildAppRouter();

GoRouter _buildAppRouter() {
  final router = GoRouter(
  initialLocation: '/',
  // 巡检主题切换（debug/profile），见 inkAppRedirect；
  // 画卷相机驱动挂在 routerDelegate（attachInkCameraDriver，坑12）。
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
  attachInkCameraDriver(router);
  return router;
}
