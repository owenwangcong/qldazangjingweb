import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qldazangjing/core/ink/tokens/ink_tokens.dart';
import 'package:qldazangjing/core/theme/app_theme.dart';

/// P1.1 验收（docs/ink-design-plan.md）：
/// 1. 六主题 token 全量定义且注入 ThemeData；
/// 2. 有效对比度 ≥4.5（含纹理叠加后的最深纸面）；
/// 3. 朱砂与 destructive 红可区分（CIE76 ΔE）；
/// 4. 墨晕阴影与纹理强度不超设计八则上限。

/// WCAG 相对亮度对比度。
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// 纹理把纸面推向墨色的最坏情况：按 intensity 的 12% 向 inkStrong 插值
/// （paper.frag 的纹理幅度上限，见 shader 注释——纤维噪声以 0.12*intensity
/// 调制 tint 与墨色的混合）。
Color _darkestPaper(InkTokens t) =>
    Color.lerp(t.paperTint, t.inkStrong, 0.12 * t.textureIntensity)!;

// ---- CIE76 ΔE（sRGB → XYZ(D65) → Lab） -------------------------------------

List<double> _toLab(Color c) {
  double f(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = f(c.r), g = f(c.g), b = f(c.b);
  // sRGB D65 矩阵
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double g3(double v) =>
      v > 0.008856 ? math.pow(v, 1 / 3).toDouble() : (7.787 * v) + 16 / 116;
  final fx = g3(x), fy = g3(y), fz = g3(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

double _deltaE(Color a, Color b) {
  final la = _toLab(a), lb = _toLab(b);
  return math.sqrt(math.pow(la[0] - lb[0], 2) +
      math.pow(la[1] - lb[1], 2) +
      math.pow(la[2] - lb[2], 2));
}

void main() {
  group('InkTokens', () {
    for (final id in AppThemeId.values) {
      final t = InkTokens.forTheme(id);
      final theme = buildAppTheme(id);
      final colors = theme.extension<AppColors>()!;

      group(id.label, () {
        test('注入 ThemeData extension', () {
          expect(theme.extension<InkTokens>(), isNotNull);
        });

        test('正文对比度：foreground vs 纹理最深纸面 ≥ 4.5', () {
          expect(_contrast(colors.foreground, _darkestPaper(t)),
              greaterThanOrEqualTo(4.5));
        });

        test('焦浓墨对比度：inkStrong vs 纹理最深纸面 ≥ 4.5', () {
          expect(_contrast(t.inkStrong, _darkestPaper(t)),
              greaterThanOrEqualTo(4.5));
        });

        test('重墨对比度：inkMedium vs paperTint ≥ 3.0（大字/图形级）', () {
          expect(_contrast(t.inkMedium, t.paperTint),
              greaterThanOrEqualTo(3.0));
        });

        test('墨阶单调：焦浓 > 重 > 淡（与纸面的对比度递减）', () {
          final s = _contrast(t.inkStrong, t.paperTint);
          final m = _contrast(t.inkMedium, t.paperTint);
          final l = _contrast(t.inkLight, t.paperTint);
          expect(s, greaterThan(m));
          expect(m, greaterThan(l));
        });

        test('朱砂 vs destructive 红 ΔE ≥ 10（语义可区分）', () {
          expect(_deltaE(t.sealRed, colors.destructive),
              greaterThanOrEqualTo(10));
        });

        test('朱砂在纸面上可辨：对比度 ≥ 3.0', () {
          expect(
              _contrast(t.sealRed, t.paperTint), greaterThanOrEqualTo(3.0));
        });

        test('纸面与背景仅一线之差（ΔE < 6，纹理不得喧宾夺主）', () {
          expect(_deltaE(t.paperTint, colors.background), lessThan(6));
        });

        test('设计八则上限：阴影 alpha / 纹理强度', () {
          final isDark = id.brightness == Brightness.dark;
          // 暗主题阴影本就是深色加重，放宽到 0.5；浅主题严格 ≤0.18。
          expect(t.washShadowColor.a, lessThanOrEqualTo(isDark ? 0.5 : 0.18));
          expect(t.washShadowBlur, greaterThanOrEqualTo(16));
          expect(t.textureIntensity, lessThanOrEqualTo(isDark ? 0.35 : 0.5));
        });
      });
    }
  });
}
