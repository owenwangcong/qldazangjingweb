import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/ink/ink.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';

/// P3.1 题跋区底部导航：命中区尺寸、选中态形状差异、回调。
void main() {
  const items = [
    InkNavItem(icon: Icons.menu_book_outlined, label: '藏经', sealText: '藏'),
    InkNavItem(icon: Icons.search, label: '搜索', sealText: '搜'),
    InkNavItem(icon: Icons.person_outline, label: '我的', sealText: '我'),
  ];

  Widget harness({
    required int selectedIndex,
    ValueChanged<int>? onSelect,
    AppThemeId theme = AppThemeId.hupochangguang,
  }) {
    return MaterialApp(
      theme: buildAppTheme(theme),
      home: Scaffold(
        bottomNavigationBar: InkNavBar(
          items: items,
          selectedIndex: selectedIndex,
          onSelect: onSelect ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('P3.1 三 tab 命中区 ≥48dp', (tester) async {
    await tester.pumpWidget(harness(selectedIndex: 0));
    final wells = find.descendant(
      of: find.byType(InkNavBar),
      matching: find.byType(InkWell),
    );
    expect(wells, findsNWidgets(3));
    for (final well in wells.evaluate()) {
      final size = well.size!;
      expect(size.height, greaterThanOrEqualTo(48),
          reason: '题跋区 tab 命中高度不足 48dp');
      expect(size.width, greaterThanOrEqualTo(48),
          reason: '题跋区 tab 命中宽度不足 48dp');
    }
  });

  testWidgets('P3.1 选中态形状差异：朱砂印+笔触下划线；未选中为图标', (tester) async {
    await tester.pumpWidget(harness(selectedIndex: 1));
    await tester.pumpAndSettle();

    // 选中 tab：印章 + 下划线各一处；图标只剩未选中的两个。
    expect(find.byType(SealStamp), findsOneWidget);
    expect(find.byType(BrushUnderline), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.search), findsNothing);

    // 印章上的白文字是标签首字。
    expect(
      find.descendant(of: find.byType(SealStamp), matching: find.text('搜')),
      findsOneWidget,
    );

    // 无障碍：选中 tab 暴露 selected 语义。
    final semantics = tester.getSemantics(find.text('搜索'));
    expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
  });

  testWidgets('P3.1 点击未选中 tab 触发 onSelect', (tester) async {
    int? tapped;
    await tester.pumpWidget(
      harness(selectedIndex: 0, onSelect: (i) => tapped = i),
    );
    await tester.tap(find.text('我的'));
    expect(tapped, 2);
  });

  testWidgets('P3.1 六主题构建均无异常/overflow', (tester) async {
    for (final theme in AppThemeId.values) {
      await tester.pumpWidget(harness(selectedIndex: 0, theme: theme));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '主题 ${theme.key} 构建异常');
    }
  });
}
