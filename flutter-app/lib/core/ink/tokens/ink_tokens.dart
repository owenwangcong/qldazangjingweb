import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

Color _hsl(double h, double s, double l) =>
    HSLColor.fromAHSL(1, h, s / 100, l / 100).toColor();

/// 水墨设计语言的主题 token（docs/ink-design-plan.md §4.1）。
///
/// 「墨分五色」按三档落地：焦浓墨 [inkStrong]（正文级，须与纸面对比 ≥4.5:1）、
/// 重墨 [inkMedium]（次级文字/图标）、淡墨 [inkLight]（装饰线、笔触底色）。
/// 暗色主题反转——纸是夜色，墨是淡光。
@immutable
class InkTokens extends ThemeExtension<InkTokens> {
  const InkTokens({
    required this.inkStrong,
    required this.inkMedium,
    required this.inkLight,
    required this.paperTint,
    required this.sealRed,
    required this.mistColor,
    required this.washShadowColor,
    required this.washShadowBlur,
    required this.textureIntensity,
  });

  /// 焦浓墨：标题、笔触主线。
  final Color inkStrong;

  /// 重墨：次级文字、图标。
  final Color inkMedium;

  /// 淡墨/清墨：分隔线、装饰笔触。
  final Color inkLight;

  /// 宣纸底色（纹理 shader 的 tint，与 background 仅差一线）。
  final Color paperTint;

  /// 印泥朱砂：选中态、印章、搜索高亮。每屏 ≤2 处（§4.1）。
  final Color sealRed;

  /// 云雾/留白带（装饰层专用，opacity 上限由组件 assert 把守）。
  final Color mistColor;

  /// 墨晕阴影：大 blur 低 alpha（设计八则 #2，alpha ≤0.18）。
  final Color washShadowColor;
  final double washShadowBlur;

  /// 纸纹强度 0–1（浅主题 ≤0.5，暗主题 ≤0.35）。
  final double textureIntensity;

  /// 各主题的水墨配色。色值与 AppColors 同源（同色相系），但墨阶独立调校。
  static InkTokens forTheme(AppThemeId id) {
    switch (id) {
      case AppThemeId.lianchichanyun: // 莲池禅韵：青绿调，墨偏苔色
        return InkTokens(
          inkStrong: _hsl(85, 14, 20),
          inkMedium: _hsl(85, 12, 42),
          inkLight: _hsl(85, 12, 68),
          paperTint: _hsl(85, 14, 96),
          sealRed: _hsl(10, 58, 47),
          mistColor: _hsl(90, 16, 88),
          washShadowColor: _hsl(85, 20, 25).withValues(alpha: 0.14),
          washShadowBlur: 20,
          textureIntensity: 0.42,
        );
      case AppThemeId.zhulinyoujing: // 竹林幽径：竹青，墨偏翠
        return InkTokens(
          inkStrong: _hsl(140, 18, 19),
          inkMedium: _hsl(140, 15, 40),
          inkLight: _hsl(140, 15, 66),
          paperTint: _hsl(140, 18, 96),
          sealRed: _hsl(8, 56, 48),
          mistColor: _hsl(150, 20, 88),
          washShadowColor: _hsl(140, 22, 24).withValues(alpha: 0.14),
          washShadowBlur: 20,
          textureIntensity: 0.42,
        );
      case AppThemeId.yueyingqinghui: // 月映清辉：青灰冷调，最接近传统水墨
        return InkTokens(
          inkStrong: _hsl(220, 8, 18),
          inkMedium: _hsl(220, 7, 40),
          inkLight: _hsl(220, 7, 66),
          paperTint: _hsl(220, 8, 96),
          sealRed: _hsl(12, 54, 48),
          mistColor: _hsl(225, 10, 88),
          washShadowColor: _hsl(220, 12, 22).withValues(alpha: 0.13),
          washShadowBlur: 22,
          textureIntensity: 0.45,
        );
      case AppThemeId.hupochangguang: // 琥珀长光：暖纸陈墨（默认主题）
        return InkTokens(
          inkStrong: _hsl(30, 45, 18),
          inkMedium: _hsl(30, 35, 38),
          inkLight: _hsl(32, 28, 64),
          paperTint: _hsl(36, 32, 96),
          sealRed: _hsl(10, 62, 46),
          mistColor: _hsl(38, 30, 87),
          washShadowColor: _hsl(30, 45, 22).withValues(alpha: 0.15),
          washShadowBlur: 20,
          textureIntensity: 0.48,
        );
      case AppThemeId.guchayese: // 古刹夜色：夜蓝纸，月白墨
        return InkTokens(
          inkStrong: _hsl(220, 18, 88),
          inkMedium: _hsl(220, 15, 68),
          inkLight: _hsl(220, 13, 44),
          paperTint: _hsl(220, 19, 16),
          sealRed: _hsl(8, 46, 54),
          mistColor: _hsl(225, 16, 28),
          washShadowColor: _hsl(225, 30, 6).withValues(alpha: 0.45),
          washShadowBlur: 22,
          textureIntensity: 0.28,
        );
      case AppThemeId.fagufanyin: // 法鼓梵音：暖夜纸，烛光墨
        return InkTokens(
          inkStrong: _hsl(24, 22, 88),
          inkMedium: _hsl(22, 18, 68),
          inkLight: _hsl(20, 16, 44),
          paperTint: _hsl(20, 24, 16),
          sealRed: _hsl(10, 48, 55),
          mistColor: _hsl(22, 20, 28),
          washShadowColor: _hsl(18, 35, 6).withValues(alpha: 0.45),
          washShadowBlur: 22,
          textureIntensity: 0.28,
        );
    }
  }

  @override
  InkTokens copyWith({
    Color? inkStrong,
    Color? inkMedium,
    Color? inkLight,
    Color? paperTint,
    Color? sealRed,
    Color? mistColor,
    Color? washShadowColor,
    double? washShadowBlur,
    double? textureIntensity,
  }) {
    return InkTokens(
      inkStrong: inkStrong ?? this.inkStrong,
      inkMedium: inkMedium ?? this.inkMedium,
      inkLight: inkLight ?? this.inkLight,
      paperTint: paperTint ?? this.paperTint,
      sealRed: sealRed ?? this.sealRed,
      mistColor: mistColor ?? this.mistColor,
      washShadowColor: washShadowColor ?? this.washShadowColor,
      washShadowBlur: washShadowBlur ?? this.washShadowBlur,
      textureIntensity: textureIntensity ?? this.textureIntensity,
    );
  }

  @override
  InkTokens lerp(ThemeExtension<InkTokens>? other, double t) {
    if (other is! InkTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => a + (b - a) * t;
    return InkTokens(
      inkStrong: c(inkStrong, other.inkStrong),
      inkMedium: c(inkMedium, other.inkMedium),
      inkLight: c(inkLight, other.inkLight),
      paperTint: c(paperTint, other.paperTint),
      sealRed: c(sealRed, other.sealRed),
      mistColor: c(mistColor, other.mistColor),
      washShadowColor: c(washShadowColor, other.washShadowColor),
      washShadowBlur: d(washShadowBlur, other.washShadowBlur),
      textureIntensity: d(textureIntensity, other.textureIntensity),
    );
  }
}

extension InkTokensX on BuildContext {
  InkTokens get ink => Theme.of(this).extension<InkTokens>()!;
}
