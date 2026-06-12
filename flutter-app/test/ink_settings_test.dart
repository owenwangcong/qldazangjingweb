import 'package:flutter/material.dart';
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
