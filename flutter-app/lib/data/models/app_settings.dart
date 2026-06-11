import 'package:isar_community/isar.dart';

part 'app_settings.g.dart';

/// Singleton settings row (id = 0). Mirrors the web app's localStorage keys:
/// theme / isSimplified / fontSize / lineHeight / letterSpacing /
/// paragraphSpacing / fontFamily.
@collection
class AppSettings {
  Id id = 0;

  /// AppThemeId.key; default mirrors the web (hupochangguang 琥珀长光).
  String themeKey = 'hupochangguang';

  bool isSimplified = true;

  /// Logical px. Web default text-xl = 20.
  double fontSize = 20;

  /// Multiplier 1.0–3.0. Web default 1.75.
  double lineHeight = 1.75;

  /// In em units (-0.05–0.15). Web default normal = 0.
  double letterSpacingEm = 0;

  /// Logical px between paragraphs. Web default 0.75rem = 12.
  double paragraphSpacing = 12;

  /// Reserved for future bundled/downloadable fonts.
  // TODO: AI_ASSUMPTION v1 使用系统字体；Web 的按书子集 woff 字体机制不适用于移动端
  String fontFamily = '';

  /// Web: hasSeenBookTour.
  bool hasSeenReaderTips = false;

  /// Web: classicTextsActiveTab / classicTextsVisible.
  String classicsActiveTab = '般若';
  bool classicsVisible = true;
}
