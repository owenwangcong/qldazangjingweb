import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qldazangjing/core/ink/shading/ink_paper_background.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';

/// P1.2 golden：宣纸纹理 × 6 主题。shader 为确定性 hash，输出逐像素稳定。
/// 更新基准：flutter test --update-goldens test/ink_paper_background_test.dart
void main() {
  testWidgets('paper shader 输出非均匀纹理（像素级回归探针）', (tester) async {
    await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset('shaders/paper.frag');
      final shader = program.fragmentShader()
        ..setFloat(0, 100)
        ..setFloat(1, 100)
        ..setFloat(2, 0.9)
        ..setFloat(3, 0.9)
        ..setFloat(4, 0.85)
        ..setFloat(5, 1)
        ..setFloat(6, 0.1)
        ..setFloat(7, 0.1)
        ..setFloat(8, 0.1)
        ..setFloat(9, 1)
        ..setFloat(10, 1);
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
          .drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint()..shader = shader);
      final image = await recorder.endRecording().toImage(100, 100);
      final data = (await image.toByteData())!;
      var minR = 255, maxR = 255;
      for (var i = 0; i < data.lengthInBytes; i += 4) {
        final r = data.getUint8(i);
        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
      }
      // 满强度下最大压暗 12%：min 应明显低于 max（纹理存在），
      // 且整体仍接近纸色（不喧宾夺主）。
      expect(maxR - minR, greaterThanOrEqualTo(8),
          reason: '纹理应产生可测的像素差异（实测 min=$minR max=$maxR）');
    });
  });

  for (final id in AppThemeId.values) {
    testWidgets('paper texture golden - ${id.key}', (tester) async {
      // FakeAsync 推不动真实的 shader 资产加载，先在真实异步区等它完成。
      await tester.runAsync(InkPaperBackground.warmUp);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(id),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 240,
                child: InkPaperBackground(),
              ),
            ),
          ),
        ),
      );
      // FragmentProgram.fromAsset 异步加载 → 多 pump 两帧到 shader 路径。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // shader 必须已接管（fallback ColoredBox 不应存在）。
      expect(
        find.descendant(
          of: find.byType(InkPaperBackground),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
        reason: 'shader 程序未加载，golden 捕获的是纯色 fallback',
      );

      await expectLater(
        find.byType(InkPaperBackground),
        matchesGoldenFile('goldens/paper_${id.key}.png'),
      );
    });
  }
}
