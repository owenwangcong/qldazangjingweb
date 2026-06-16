import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/ink/ink.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';

/// P4.1 overscroll 墨雾：自定义 ScrollBehavior 全局生效，
/// 替换 Material 默认 stretch/glow。
void main() {
  testWidgets('P4.1 InkMistScrollBehavior 产出墨雾 glow（非 stretch）',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(AppThemeId.hupochangguang),
        scrollBehavior: const InkMistScrollBehavior(),
        home: Scaffold(
          body: ListView(
            children: [for (var i = 0; i < 5; i++) SizedBox(height: 60, child: Text('行 $i'))],
          ),
        ),
      ),
    );

    // Android 默认是 StretchingOverscrollIndicator——墨雾行为下不应出现。
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    final glow = find.byType(GlowingOverscrollIndicator);
    expect(glow, findsOneWidget);

    // 墨雾颜色来自 InkTokens.mistColor（非 Material 默认蓝/紫）。
    final ink = InkTokens.forTheme(AppThemeId.hupochangguang);
    final widget = tester.widget<GlowingOverscrollIndicator>(glow);
    expect(widget.color, ink.mistColor);

    // 顶部越界拖拽不抛异常（glow 生命周期正常）。
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
