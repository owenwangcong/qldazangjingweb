import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/offline_banner.dart';

/// Bottom-navigation shell: 首页 / 搜索 / 我的.
/// Replaces the web app's floating header button stack with a thumb-friendly
/// mobile navigation pattern.
class ShellPage extends StatelessWidget {
  const ShellPage({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: '藏经'),
          NavigationDestination(icon: Icon(Icons.search), label: '搜索'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
        ],
      ),
    );
  }
}
