import 'package:flutter/material.dart';
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

final appRouter = GoRouter(
  initialLocation: '/',
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
