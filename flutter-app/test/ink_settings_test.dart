import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:qldazangjing/core/fonts/font_service.dart';
import 'package:qldazangjing/core/ink/ink.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';
import 'package:qldazangjing/core/utils/chinese_converter.dart';
import 'package:qldazangjing/data/models/app_settings.dart';
import 'package:qldazangjing/presentation/pages/settings_page.dart';
import 'package:qldazangjing/presentation/providers/app_providers.dart';

/// P3.8 设置页：主题选择器 = 六幅小画卷缩略，预览底色与实际主题一致；
/// 分隔线 = BrushDivider；无 Material RadioListTile。
void main() {
  late ChineseConverter converter;

  setUpAll(() async {
    converter = await ChineseConverter.load();
  });

  Widget harness({AppThemeId theme = AppThemeId.hupochangguang}) {
    return ProviderScope(
      overrides: [
        chineseConverterProvider.overrideWithValue(converter),
        settingsProvider.overrideWith(
          (ref) => SettingsController(
              _NoopIsar(), AppSettings()..themeKey = theme.key),
        ),
        fontControllerProvider.overrideWith(
          (ref) => FontController(FontService(), AppFont.system),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(theme),
        home: const SettingsPage(),
      ),
    );
  }

  testWidgets('P3.8 主题选择器 = 六幅画卷缩略，预览底色与主题一致', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.text('主题'));
    await tester.pumpAndSettle();

    expect(find.byType(RadioListTile<String>), findsNothing);
    expect(find.byType(InkThemeThumb), findsNWidgets(6));

    for (final theme in AppThemeId.values) {
      final thumb = find.byWidgetPredicate(
        (w) => w is InkThemeThumb && w.theme == theme,
      );
      expect(thumb, findsOneWidget);
      // 预览底色 = 该主题的实际 background。
      final expected = buildAppTheme(theme).extension<AppColors>()!.background;
      final paper = find.descendant(
        of: thumb,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == expected,
        ),
      );
      expect(paper, findsOneWidget,
          reason: '主题 ${theme.key} 缩略底色与实际主题色不一致');
    }
  });

  testWidgets('P3.8 分隔线 = BrushDivider（无 Material Divider）', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(Divider), findsNothing);
    expect(find.byType(BrushDivider), findsAtLeastNWidgets(1));
  });

  testWidgets('开发者工具：动画慢放滑杆驱动全局 timeDilation（0.1–10）',
      (tester) async {
    // 框架不变量在测试体结束时检查 timeDilation 已复位（先于 tearDown），
    // 故用 finally 复位。
    try {
      await tester.pumpWidget(harness());
      await tester.pump();

      // debug/profile（测试即非 release）下可见。
      await tester.dragUntilVisible(
        find.text('动画慢放'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('动画慢放'), findsOneWidget);
      expect(find.text('1.0×'), findsOneWidget);

      // 拖到最右端 → 10 倍慢放；最左端 → 0.1 倍（夹紧范围）。
      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(400, 0));
      await tester.pump();
      expect(timeDilation, 10.0);
      expect(find.text('10.0×'), findsOneWidget);

      await tester.drag(slider, const Offset(-800, 0));
      await tester.pump();
      expect(timeDilation, moreOrLessEquals(0.1, epsilon: 0.001));
    } finally {
      timeDilation = 1.0;
    }
  });

  testWidgets('P3.8 六主题构建无异常/overflow', (tester) async {
    for (final theme in AppThemeId.values) {
      await tester.pumpWidget(harness(theme: theme));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '主题 ${theme.key} 异常');
    }
  });
}

class _NoopIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('测试中不应使用 Isar：${invocation.memberName}');
}
