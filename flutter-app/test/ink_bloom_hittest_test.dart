import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qldazangjing/core/ink/ink.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';

/// 破墨转场命中回归（2026-07-20 真机事故）：转场期间 ClipPath 按墨晕
/// 过滤命中，圈外（四角＝AppBar 按钮区）点击被吞；设备高压下动画停滞
/// 在高位时按钮长期失灵。修复 = 视觉裁剪零命中过滤 + 末梢冻结兜底。
void main() {
  Widget harness({required double progress, required VoidCallback onPressed}) {
    return MaterialApp(
      theme: buildAppTheme(AppThemeId.hupochangguang),
      home: Material(
        child: InkBloomReveal(
          progress: AlwaysStoppedAnimation(progress),
          origin: const Offset(400, 300),
          child: Stack(
            children: [
              Container(color: const Color(0xFFF4E9D3)),
              // 左上角按钮：p=0.5 时墨晕半径 ~275px（origin 距角 ~472px），
              // 按钮在墨晕圈外——修复前此点击被 ClipPath 吞掉。
              Positioned(
                left: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onPressed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('转场中（p=0.5）墨晕圈外的按钮仍可点击', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
        harness(progress: 0.5, onPressed: () => pressed++));
    await tester.tapAt(const Offset(28, 28));
    expect(pressed, 1, reason: '视觉裁剪不得过滤命中');
  });

  testWidgets('动画停滞在末梢（p=0.996）时返回裸 child，页面完全可交互', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
        harness(progress: 0.996, onPressed: () => pressed++));
    // 兜底生效 = 不再存在任何裁剪节点。
    expect(find.byType(ClipPath), findsNothing);
    await tester.tapAt(const Offset(28, 28));
    expect(pressed, 1);
  });

  testWidgets('转场中墨晕圈内点击照常命中', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(AppThemeId.hupochangguang),
      home: Material(
        child: InkBloomReveal(
          progress: const AlwaysStoppedAnimation(0.5),
          origin: const Offset(400, 300),
          child: Stack(
            children: [
              Container(color: const Color(0xFFF4E9D3)),
              Positioned(
                left: 384,
                top: 284,
                child: IconButton(
                  icon: const Icon(Icons.circle),
                  onPressed: () => pressed++,
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.tapAt(const Offset(400, 300));
    expect(pressed, 1);
  });
}
