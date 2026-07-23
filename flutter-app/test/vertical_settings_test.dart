import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:qldazangjing/core/fonts/font_service.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';
import 'package:qldazangjing/core/utils/chinese_converter.dart';
import 'package:qldazangjing/data/models/app_settings.dart';
import 'package:qldazangjing/presentation/providers/app_providers.dart';
import 'package:qldazangjing/presentation/widgets/reader_settings_sheet.dart';

/// 古籍竖排 S1（设置层）：字段默认值 / 反转存储语义 / _copy 完整性 /
/// 设置面板三档切换与竖排专属开关联动。对应验收清单 C10 的设置侧断言。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChineseConverter converter;

  setUpAll(() async {
    converter = await ChineseConverter.load();
  });

  group('S1 AppSettings 字段', () {
    test('默认值：乌丝栏开（hide=false 反转存储）、白文关、模式互斥', () {
      final s = AppSettings();
      expect(s.hideColumnRules, isFalse,
          reason: 'isar 旧行新增 bool 回填 false，默认开启只能存反转字段');
      expect(s.showColumnRules, isTrue);
      expect(s.baiwenMode, isFalse);
      expect(s.isVertical, isFalse);
      expect(s.isPaged, isFalse);
    });

    test('readingMode=vertical 时 isVertical 与 isPaged 互斥', () {
      final s = AppSettings()..readingMode = 'vertical';
      expect(s.isVertical, isTrue);
      expect(s.isPaged, isFalse);
      // isar 回填空串的旧行（见 readingMode 注释）不得误判为任何翻页模式。
      final blank = AppSettings()..readingMode = '';
      expect(blank.isVertical, isFalse);
      expect(blank.isPaged, isFalse);
    });
  });

  group('S1 SettingsController', () {
    test('_copy 完整性：无关 setter 不得重置竖排字段', () async {
      final c = SettingsController(_MemIsar(), AppSettings());
      await c.setReadingMode('vertical');
      await c.setBaiwenMode(true);
      await c.setShowColumnRules(false);
      // 无关 setter 走 _copy()——若漏抄新字段，此处会被静默重置。
      await c.setMuteScrollFeedback(true);
      await c.setVerticalCharGap(0.2);
      await c.setVerticalColumnPitch(2.1);
      await c.setVerticalFontSize(30);
      await c.setFontSize(28);
      await c.setTheme('guchayese');
      expect(c.state.isVertical, isTrue);
      expect(c.state.baiwenMode, isTrue);
      expect(c.state.showColumnRules, isFalse);
      expect(c.state.hideColumnRules, isTrue, reason: '落库为反转字段');
      expect(c.state.muteScrollFeedback, isTrue);
      expect(c.state.verticalCharGapEm, 0.2);
      expect(c.state.verticalColumnPitch, 2.1);
      expect(c.state.verticalFontSize, 30);
      expect(c.state.fontSize, 28, reason: '竖排/横排字号互不覆盖');
    });

    test('竖排间距默认值、哨兵与 NaN 安全语义', () {
      final s = AppSettings();
      expect(s.effectiveVerticalCharGapEm, 0, reason: '默认紧排');
      expect(s.effectiveVerticalColumnPitch, 1.75, reason: '0 哨兵取默认列距');
      s.verticalColumnPitch = 2.4;
      expect(s.effectiveVerticalColumnPitch, 2.4);
      // isar 给旧行新增 double 字段回填 NaN(2026-07-20 真机白屏事故):
      // effective getter 是唯一安全读取口。
      s.verticalCharGapEm = double.nan;
      s.verticalColumnPitch = double.nan;
      expect(s.effectiveVerticalCharGapEm, 0);
      expect(s.effectiveVerticalColumnPitch, 1.75);
      // 越界值钳制。
      s.verticalCharGapEm = 9;
      s.verticalColumnPitch = 99;
      expect(s.effectiveVerticalCharGapEm, 0.4);
      expect(s.effectiveVerticalColumnPitch, 3.0);
    });

    test('竖排字号默认值、哨兵与 NaN 安全语义', () {
      final s = AppSettings();
      expect(s.effectiveVerticalFontSize, 26, reason: '0 哨兵取竖排默认大字号');
      expect(s.fontSize, 20, reason: '横排默认字号不受竖排解耦影响');
      s.verticalFontSize = 32;
      expect(s.effectiveVerticalFontSize, 32);
      // isar 旧行回填 NaN → 回落默认值。
      s.verticalFontSize = double.nan;
      expect(s.effectiveVerticalFontSize, 26);
      // 越界值钳制到滑杆区间 14~40。
      s.verticalFontSize = 8;
      expect(s.effectiveVerticalFontSize, 14);
      s.verticalFontSize = 99;
      expect(s.effectiveVerticalFontSize, 40);
    });

    test('setShowColumnRules 以显示语义写入反转字段', () async {
      final c = SettingsController(_MemIsar(), AppSettings());
      await c.setShowColumnRules(true);
      expect(c.state.hideColumnRules, isFalse);
      await c.setShowColumnRules(false);
      expect(c.state.hideColumnRules, isTrue);
    });
  });

  group('S1 阅读设置面板', () {
    late SettingsController controller;

    Widget harness() {
      return ProviderScope(
        overrides: [
          chineseConverterProvider.overrideWithValue(converter),
          settingsProvider.overrideWith((ref) {
            controller = SettingsController(_MemIsar(), AppSettings());
            return controller;
          }),
          fontControllerProvider.overrideWith(
            (ref) => FontController(FontService(), AppFont.system),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(AppThemeId.hupochangguang),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showReaderSettingsSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openSheet(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(harness());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('翻页方式三档；非竖排时不显示竖排专属项', (tester) async {
      await openSheet(tester);
      expect(find.text('上下滚动'), findsOneWidget);
      expect(find.text('左右翻页'), findsOneWidget);
      expect(find.text('竖排翻页'), findsOneWidget);
      expect(find.text('竖排展卷'), findsOneWidget);
      expect(find.text('竖排翻页'), findsOneWidget);
      expect(find.text('乌丝栏'), findsNothing);
      expect(find.text('白文'), findsNothing);
    });

    testWidgets('选中古籍竖排 → 模式落库并展开乌丝栏/标点两行', (tester) async {
      await openSheet(tester);
      await tester.tap(find.text('竖排翻页'));
      await tester.pumpAndSettle();

      expect(controller.state.isVertical, isTrue);
      expect(find.text('乌丝栏'), findsOneWidget);
      expect(find.text('标点'), findsOneWidget);
      // 竖排间距滑杆（D6）：字间/行间出现，横排的行距/字距/段距隐藏。
      expect(find.text('字间'), findsOneWidget);
      expect(find.text('行间'), findsOneWidget);
      expect(find.text('行距'), findsNothing);
      expect(find.text('段距'), findsNothing);
      // 默认态：乌丝栏显示、句读模式。
      expect(controller.state.showColumnRules, isTrue);
      expect(controller.state.baiwenMode, isFalse);

      await tester.tap(find.text('隐藏'));
      await tester.pumpAndSettle();
      expect(controller.state.showColumnRules, isFalse);

      await tester.tap(find.text('白文'));
      await tester.pumpAndSettle();
      expect(controller.state.baiwenMode, isTrue);
    });

    testWidgets('选中竖排展卷 → 竖排项共享显示 + 展卷反馈行(默认开)', (tester) async {
      await openSheet(tester);
      await tester.tap(find.text('竖排展卷'));
      await tester.pumpAndSettle();

      expect(controller.state.isVerticalScroll, isTrue);
      expect(controller.state.usesVerticalEngine, isTrue);
      // 竖排引擎共享项在展卷下同样显示。
      expect(find.text('乌丝栏'), findsOneWidget);
      expect(find.text('字间'), findsOneWidget);
      // 展卷专属:反馈开关,默认开。
      expect(find.text('展卷反馈'), findsOneWidget);
      expect(controller.state.muteScrollFeedback, isFalse);
      await tester.tap(find.text('关'));
      await tester.pumpAndSettle();
      expect(controller.state.muteScrollFeedback, isTrue);

      // 切回竖排翻页:反馈行收起,共享项保留。
      await tester.tap(find.text('竖排翻页'));
      await tester.pumpAndSettle();
      expect(find.text('展卷反馈'), findsNothing);
      expect(find.text('乌丝栏'), findsOneWidget);
    });

    testWidgets('切回上下滚动 → 竖排专属项收起，开关状态保留', (tester) async {
      await openSheet(tester);
      await tester.tap(find.text('竖排翻页'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('白文'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('上下滚动'));
      await tester.pumpAndSettle();
      expect(controller.state.isVertical, isFalse);
      expect(find.text('乌丝栏'), findsNothing);
      // 偏好保留：再切回竖排仍是白文。
      expect(controller.state.baiwenMode, isTrue);
    });
  });
}

/// 仅承接 SettingsController._persist 所需的最小 Isar 假件：
/// writeTxn 直接执行回调、collection 返回可 put 的空集合，其余成员禁用。
class _MemIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #writeTxn) {
      final callback = invocation.positionalArguments.first as Function;
      return callback();
    }
    if (invocation.memberName == #collection) {
      return _MemSettingsCollection();
    }
    throw StateError('测试中不应使用 Isar：${invocation.memberName}');
  }
}

class _MemSettingsCollection implements IsarCollection<AppSettings> {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #put) return Future<int>.value(0);
    throw StateError('测试中不应使用 IsarCollection：${invocation.memberName}');
  }
}
