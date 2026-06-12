import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:qldazangjing/core/ink/ink.dart';
import 'package:qldazangjing/core/network/connectivity_service.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';
import 'package:qldazangjing/core/utils/chinese_converter.dart';
import 'package:qldazangjing/data/models/app_settings.dart';
import 'package:qldazangjing/domain/repositories/repositories.dart';
import 'package:qldazangjing/presentation/pages/dict_page.dart';
import 'package:qldazangjing/presentation/providers/app_providers.dart';

/// P3.7 字典页：砚台输入、释义笺纸卡、留白规范（边距 ≥16dp）、EnsoLoading。
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
        lexiconRepositoryProvider.overrideWithValue(_FakeLexiconRepository()),
        connectivityServiceProvider.overrideWithValue(_FakeConnectivity()),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: MaterialApp(
        theme: buildAppTheme(theme),
        home: const DictPage(),
      ),
    );
  }

  testWidgets('P3.7 释义卡 = InkCard，留白边距 ≥16dp，无 Material Card',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.enterText(find.byType(TextField), '般若');
    await tester.tap(find.text('查询'));
    await tester.pump(const Duration(milliseconds: 60)); // 越过 fake 的 50ms
    await tester.pump();

    expect(find.byType(Card), findsNothing);
    final card = find.widgetWithText(InkCard, '丁福保佛学大辞典');
    expect(card, findsOneWidget);

    final screen = tester.getSize(find.byType(DictPage));
    final rect = tester.getRect(card);
    expect(rect.left, greaterThanOrEqualTo(16));
    expect(screen.width - rect.right, greaterThanOrEqualTo(16));
  });

  testWidgets('P3.7 加载态 = EnsoLoading', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.enterText(find.byType(TextField), '般若');
    await tester.tap(find.text('查询'));
    await tester.pump(); // _loading = true，fake 尚未返回

    expect(find.byType(EnsoLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('P3.7 六主题构建无异常/overflow', (tester) async {
    for (final theme in AppThemeId.values) {
      await tester.pumpWidget(harness(theme: theme));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '主题 ${theme.key} 异常');
    }
  });
}

class _FakeLexiconRepository implements LexiconRepository {
  @override
  Future<List<({String dict, String value})>> lookup(String key) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return [
      (dict: '丁福保佛学大辞典', value: '（术语）梵语般若波罗蜜，译曰智慧到彼岸。'),
    ];
  }

  @override
  Future<String> toModernChinese(String text) async => text;

  @override
  Future<String> explain(String text) async => text;
}

class _FakeConnectivity implements ConnectivityService {
  @override
  bool get isOnline => true;

  @override
  Stream<bool> get onStatusChange => Stream.value(true);

  @override
  Future<void> dispose() async {}
}

class _NoopIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('测试中不应使用 Isar：${invocation.memberName}');
}
