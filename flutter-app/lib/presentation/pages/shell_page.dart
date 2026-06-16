import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ink/ink.dart';
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
      // 题跋区（P3.1）：画卷下缘的题跋条，选中 tab 盖朱砂印。
      bottomNavigationBar: InkNavBar(
        selectedIndex: shell.currentIndex,
        onSelect: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        items: const [
          InkNavItem(icon: Icons.menu_book_outlined, label: '藏经', sealText: '藏'),
          InkNavItem(icon: Icons.search, label: '搜索', sealText: '搜'),
          InkNavItem(icon: Icons.person_outline, label: '我的', sealText: '我'),
        ],
      ),
    );
  }
}
