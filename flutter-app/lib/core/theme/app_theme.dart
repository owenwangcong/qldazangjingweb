import 'package:flutter/material.dart';

import '../ink/painting/ink_drop_splash.dart';
import '../ink/shading/ink_bloom_reveal.dart';
import '../ink/tokens/ink_tokens.dart';

/// The six visual themes ported 1:1 from the web app's globals.css.
/// HSL triplets are transcribed verbatim so the palettes stay identical.
enum AppThemeId {
  lianchichanyun('lianchichanyun', '莲池禅韵', Brightness.light),
  zhulinyoujing('zhulinyoujing', '竹林幽径', Brightness.light),
  yueyingqinghui('yueyingqinghui', '月映清辉', Brightness.light),
  hupochangguang('hupochangguang', '琥珀长光', Brightness.light),
  guchayese('guchayese', '古刹夜色', Brightness.dark),
  fagufanyin('fagufanyin', '法鼓梵音', Brightness.dark);

  const AppThemeId(this.key, this.label, this.brightness);

  final String key;
  final String label;
  final Brightness brightness;

  static AppThemeId fromKey(String? key) => AppThemeId.values.firstWhere(
        (t) => t.key == key,
        orElse: () => AppThemeId.hupochangguang,
      );
}

Color _hsl(double h, double s, double l) =>
    HSLColor.fromAHSL(1, h, s / 100, l / 100).toColor();

/// Design tokens mirroring the CSS custom properties of the web app.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.border,
    required this.input,
    required this.ring,
  });

  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color popover;
  final Color popoverForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color border;
  final Color input;
  final Color ring;

  @override
  AppColors copyWith({Color? background}) => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      foreground: l(foreground, other.foreground),
      card: l(card, other.card),
      cardForeground: l(cardForeground, other.cardForeground),
      popover: l(popover, other.popover),
      popoverForeground: l(popoverForeground, other.popoverForeground),
      primary: l(primary, other.primary),
      primaryForeground: l(primaryForeground, other.primaryForeground),
      secondary: l(secondary, other.secondary),
      secondaryForeground: l(secondaryForeground, other.secondaryForeground),
      muted: l(muted, other.muted),
      mutedForeground: l(mutedForeground, other.mutedForeground),
      accent: l(accent, other.accent),
      accentForeground: l(accentForeground, other.accentForeground),
      destructive: l(destructive, other.destructive),
      destructiveForeground: l(destructiveForeground, other.destructiveForeground),
      border: l(border, other.border),
      input: l(input, other.input),
      ring: l(ring, other.ring),
    );
  }
}

AppColors _paletteFor(AppThemeId id) {
  switch (id) {
    case AppThemeId.lianchichanyun:
      return AppColors(
        background: _hsl(85, 15, 95),
        foreground: _hsl(85, 10, 30),
        card: _hsl(85, 12, 93),
        cardForeground: _hsl(85, 10, 30),
        popover: _hsl(85, 12, 93),
        popoverForeground: _hsl(85, 10, 30),
        primary: _hsl(90, 20, 70),
        primaryForeground: _hsl(85, 10, 25),
        secondary: _hsl(80, 15, 85),
        secondaryForeground: _hsl(85, 10, 30),
        muted: _hsl(85, 10, 90),
        mutedForeground: _hsl(85, 10, 40),
        accent: _hsl(90, 18, 75),
        accentForeground: _hsl(85, 10, 30),
        destructive: _hsl(0, 30, 65),
        destructiveForeground: _hsl(85, 10, 25),
        border: _hsl(85, 10, 85),
        input: _hsl(85, 10, 85),
        ring: _hsl(85, 10, 25),
      );
    case AppThemeId.zhulinyoujing:
      return AppColors(
        background: _hsl(140, 20, 95),
        foreground: _hsl(140, 15, 30),
        card: _hsl(140, 18, 93),
        cardForeground: _hsl(140, 15, 30),
        popover: _hsl(140, 18, 93),
        popoverForeground: _hsl(140, 15, 30),
        primary: _hsl(150, 25, 70),
        primaryForeground: _hsl(140, 15, 25),
        secondary: _hsl(130, 20, 85),
        secondaryForeground: _hsl(140, 15, 30),
        muted: _hsl(140, 15, 90),
        mutedForeground: _hsl(140, 15, 40),
        accent: _hsl(150, 22, 75),
        accentForeground: _hsl(140, 15, 30),
        destructive: _hsl(0, 30, 65),
        destructiveForeground: _hsl(140, 15, 25),
        border: _hsl(140, 15, 85),
        input: _hsl(140, 15, 85),
        ring: _hsl(140, 15, 25),
      );
    case AppThemeId.yueyingqinghui:
      return AppColors(
        background: _hsl(220, 10, 95),
        foreground: _hsl(220, 5, 30),
        card: _hsl(220, 8, 93),
        cardForeground: _hsl(220, 5, 30),
        popover: _hsl(220, 8, 93),
        popoverForeground: _hsl(220, 5, 30),
        primary: _hsl(230, 15, 70),
        primaryForeground: _hsl(220, 5, 25),
        secondary: _hsl(210, 10, 85),
        secondaryForeground: _hsl(220, 5, 30),
        muted: _hsl(220, 5, 90),
        mutedForeground: _hsl(220, 5, 40),
        accent: _hsl(230, 12, 75),
        accentForeground: _hsl(220, 5, 30),
        destructive: _hsl(0, 30, 65),
        destructiveForeground: _hsl(220, 5, 25),
        border: _hsl(220, 5, 85),
        input: _hsl(220, 5, 85),
        ring: _hsl(220, 5, 25),
      );
    case AppThemeId.hupochangguang:
      return AppColors(
        background: _hsl(35, 30, 95),
        foreground: _hsl(30, 50, 22),
        card: _hsl(35, 28, 93),
        cardForeground: _hsl(30, 50, 22),
        popover: _hsl(35, 28, 93),
        popoverForeground: _hsl(30, 50, 22),
        primary: _hsl(38, 60, 58),
        primaryForeground: _hsl(30, 50, 20),
        secondary: _hsl(40, 35, 80),
        secondaryForeground: _hsl(30, 50, 22),
        muted: _hsl(35, 25, 88),
        mutedForeground: _hsl(30, 40, 35),
        accent: _hsl(38, 55, 65),
        accentForeground: _hsl(30, 50, 22),
        destructive: _hsl(0, 50, 55),
        destructiveForeground: _hsl(30, 50, 20),
        border: _hsl(35, 25, 82),
        input: _hsl(35, 25, 82),
        ring: _hsl(30, 50, 20),
      );
    case AppThemeId.guchayese:
      return AppColors(
        background: _hsl(220, 20, 15),
        foreground: _hsl(220, 15, 85),
        card: _hsl(220, 18, 17),
        cardForeground: _hsl(220, 15, 85),
        popover: _hsl(220, 18, 17),
        popoverForeground: _hsl(220, 15, 85),
        primary: _hsl(230, 25, 40),
        primaryForeground: _hsl(220, 15, 90),
        secondary: _hsl(210, 20, 25),
        secondaryForeground: _hsl(220, 15, 85),
        muted: _hsl(220, 15, 20),
        mutedForeground: _hsl(220, 15, 70),
        accent: _hsl(230, 22, 35),
        accentForeground: _hsl(220, 15, 85),
        destructive: _hsl(0, 30, 50),
        destructiveForeground: _hsl(220, 15, 90),
        border: _hsl(220, 15, 25),
        input: _hsl(220, 15, 25),
        ring: _hsl(220, 15, 85),
      );
    case AppThemeId.fagufanyin:
      return AppColors(
        background: _hsl(20, 25, 15),
        foreground: _hsl(20, 20, 85),
        card: _hsl(20, 23, 17),
        cardForeground: _hsl(20, 20, 85),
        popover: _hsl(20, 23, 17),
        popoverForeground: _hsl(20, 20, 85),
        primary: _hsl(30, 30, 40),
        primaryForeground: _hsl(20, 20, 90),
        secondary: _hsl(10, 25, 25),
        secondaryForeground: _hsl(20, 20, 85),
        muted: _hsl(20, 20, 20),
        mutedForeground: _hsl(20, 20, 70),
        accent: _hsl(30, 27, 35),
        accentForeground: _hsl(20, 20, 85),
        destructive: _hsl(0, 30, 50),
        destructiveForeground: _hsl(20, 20, 90),
        border: _hsl(20, 20, 25),
        input: _hsl(20, 20, 25),
        ring: _hsl(20, 20, 85),
      );
  }
}

ThemeData buildAppTheme(AppThemeId id, {String? fontFamily}) {
  final c = _paletteFor(id);
  final ink = InkTokens.forTheme(id);
  final scheme = ColorScheme(
    brightness: id.brightness,
    primary: c.primary,
    onPrimary: c.primaryForeground,
    secondary: c.secondary,
    onSecondary: c.secondaryForeground,
    error: c.destructive,
    onError: c.destructiveForeground,
    surface: c.background,
    onSurface: c.foreground,
    surfaceContainerHighest: c.card,
    surfaceContainerHigh: c.card,
    surfaceContainer: c.card,
    outline: c.border,
    outlineVariant: c.border,
  );
  return ThemeData(
    useMaterial3: true,
    // 全 App 统一阅读字体（对齐 web 的全站换字行为）；缺字自动回退系统字体。
    fontFamily: fontFamily,
    colorScheme: scheme,
    // 默认页转场置为静止：水墨转场全部由 inkBloomPage（破墨）承担；
    // Android 默认 Zoom 转场会给 outgoing 页加 scrim+scale 合成层，
    // 在 Impeller 无 raster cache 下白白多付一层全屏（§9 性能教训）。
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _StillPageTransitionsBuilder(),
      TargetPlatform.iOS: _StillPageTransitionsBuilder(),
      TargetPlatform.windows: _StillPageTransitionsBuilder(),
      TargetPlatform.macOS: _StillPageTransitionsBuilder(),
      TargetPlatform.linux: _StillPageTransitionsBuilder(),
    }),
    // 墨滴涟漪（P1.6）：触点如墨入纸，全局替换 Material ripple。
    splashFactory: const InkDropSplashFactory(),
    splashColor: ink.inkMedium.withValues(alpha: 0.16),
    highlightColor: ink.inkLight.withValues(alpha: 0.08),
    // 一卷画布（P2.1）：页面不再各自铺底色，背景统一由 InkScrollCanvas
    // 持久层绘制（纸纹理+远山），Scaffold 一律透明。
    scaffoldBackgroundColor: Colors.transparent,
    cardColor: c.card,
    dividerColor: c.border,
    appBarTheme: AppBarTheme(
      // 半透明纸色：标题可读，又不遮断画卷的连续感。
      backgroundColor: c.background.withValues(alpha: 0.88),
      foregroundColor: c.foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.popover,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      indicatorColor: c.primary.withValues(alpha: 0.25),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: c.foreground)),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: c.foreground, fontSize: 12),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.mutedForeground,
      textColor: c.foreground,
    ),
    // 勾选/开关墨色化（P3.5/P3.8）：浓墨实底、纸色对勾，无 Material 原色。
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ink.inkStrong
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(c.background),
      side: BorderSide(color: ink.inkMedium, width: 1.4),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ink.inkStrong
            : ink.inkLight,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ink.inkMedium.withValues(alpha: 0.45)
            : ink.inkLight.withValues(alpha: 0.25),
      ),
      trackOutlineColor: WidgetStatePropertyAll(
        ink.inkLight.withValues(alpha: 0.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.popover,
      contentTextStyle: TextStyle(color: c.popoverForeground),
      behavior: SnackBarBehavior.floating,
    ),
    extensions: [c, InkTokens.forTheme(id)],
  );
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// 静止页转场 + 反向墨缘裁剪：自身出入场不做动画（让位给 inkBloomPage
/// 的破墨层）；被新页压住时改为 [InkCoveredPage]——墨晕外保持原样可见、
/// 与上层 reveal 逐帧互补（旧方案的前 40% 淡出会在墨晕未覆盖处露出
/// 画卷/黑底，且 0<α<1 整页 saveLayer；转场修复 F1，见 §9）。
class _StillPageTransitionsBuilder extends PageTransitionsBuilder {
  const _StillPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return InkCoveredPage(
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}
