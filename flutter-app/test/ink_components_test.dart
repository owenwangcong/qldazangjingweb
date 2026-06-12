import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qldazangjing/core/ink/ink.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';

/// P1.3–P1.6 验收：
/// - 每主题一张组件全家福 golden（InkCard/BrushDivider/BrushUnderline/
///   LotusOutline/CloudPattern/MistBand/SealStamp/EnsoLoading 静止帧）；
/// - 意象 opacity 超上限触发 assert；
/// - 墨滴 splashFactory 全局注入；
/// - EnsoLoading 尊重 reduce-motion。
void main() {
  Widget gallery(AppThemeId id) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(id),
        // P2.1 起 Scaffold 全局透明，组件 golden 须叠在画卷层上看（真实观感）。
        builder: (context, child) => InkScrollCanvas(child: child!),
        home: Scaffold(
          body: MediaQuery(
            // 禁动画 → EnsoLoading 静止帧，golden 确定。
            data: const MediaQueryData(disableAnimations: true),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InkCard(
                    child: Text('笺纸卡片 InkCard：吃墨边缘与墨晕阴影'),
                  ),
                  const BrushDivider(),
                  const BrushUnderline(width: 96),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      LotusOutline(size: 100, opacity: 0.10),
                      SizedBox(width: 16),
                      CloudPattern(width: 90, opacity: 0.10),
                      SizedBox(width: 16),
                      SealStamp(text: '藏'),
                      SizedBox(width: 16),
                      EnsoLoading(),
                    ],
                  ),
                  const MistBand(height: 40, opacity: 0.10),
                ],
              ),
            ),
          ),
        ),
      );

  group('组件全家福 golden ×6 主题', () {
    for (final id in AppThemeId.values) {
      testWidgets('ink components golden - ${id.key}', (tester) async {
        await tester.runAsync(InkPaperBackground.warmUp);
        await tester.pumpWidget(gallery(id));
        await tester.pump();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/components_${id.key}.png'),
        );
      });
    }
  });

  group('意象透明度上限（设计八则 #6）', () {
    testWidgets('浅主题 opacity 0.2 触发 assert', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(AppThemeId.hupochangguang),
          home: const Scaffold(body: LotusOutline(opacity: 0.2)),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('暗主题 0.12 合法、0.15 越界', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(AppThemeId.guchayese),
          home: const Scaffold(body: CloudPattern(opacity: 0.12)),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(AppThemeId.guchayese),
          home: const Scaffold(body: MistBand(opacity: 0.15)),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });
  });

  group('墨滴涟漪', () {
    testWidgets('splashFactory 全局注入且按压产生 splash 帧', (tester) async {
      final theme = buildAppTheme(AppThemeId.hupochangguang);
      expect(theme.splashFactory, isA<InkDropSplashFactory>());

      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: InkWell(
                onTap: () => tapped = true,
                child: const SizedBox(width: 120, height: 48),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      // 扩散 420ms + 渐隐 550ms，中途多帧推进不抛异常即 splash 生命周期完整。
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('EnsoLoading', () {
    testWidgets('reduce-motion 下静止（无持续帧请求）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(AppThemeId.hupochangguang),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: EnsoLoading()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('正常模式下持续旋转', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(AppThemeId.hupochangguang),
          home: const Scaffold(body: EnsoLoading()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
    });
  });
}
