import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

final appRouter = GoRouter(
  initialLocation: '/',
  // UI 巡检通道（debug/profile 生效，release 关闭）：任意深链可带 ?theme=<key>
  // 切主题，供 adb 截图脚本逐主题验收，也让 profile 包能按主题做性能采样
  // （docs/ink-design-plan.md §6.4、tool/screenshot.ps1）。
  redirect: (context, state) {
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
    }
    return null;
  },
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
      builder: (_, state) => SectionPage(sectionId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/book/:id',
      builder: (_, state) {
        final indexParam = state.uri.queryParameters['index'];
        final highlight = state.uri.queryParameters['highlight'];
        return ReaderPage(
          bookId: state.pathParameters['id']!,
          initialBlockIndex:
              indexParam == null ? null : int.tryParse(indexParam),
          highlightText: highlight,
        );
      },
    ),
    GoRoute(path: '/dict', builder: (_, __) => const DictPage()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    GoRoute(path: '/downloads', builder: (_, __) => const DownloadsPage()),
    GoRoute(path: '/about', builder: (_, __) => const AboutPage()),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(),
    body: Center(child: Text('页面不存在: ${state.uri}')),
  ),
);
