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

  /// AppFont.key（见 core/fonts/font_service.dart）；'' = 系统默认。
  /// 默认与 Web 一致：--font-lxgw 落霞孤鹜。
  String fontFamily = 'lxgw';

  /// 阅读方式：'scroll' 上下滚动（默认）| 'paged' 左右翻页 | 'vertical' 古籍竖排。
  /// 注意：isar_community 3.x 给旧行新增的非空 String 回填**空串**而非
  /// Dart 初始值——判断只能用 == 'paged'（见 [isPaged]），不能比对 'scroll'。
  String readingMode = 'scroll';

  /// 唯一合法的翻页判断入口（getter 不入库）。
  @ignore
  bool get isPaged => readingMode == 'paged';

  /// 唯一合法的竖排判断入口（getter 不入库）。
  @ignore
  bool get isVertical => readingMode == 'vertical';

  /// 竖排乌丝栏（列间界线）显隐——**反转存储**：isar_community 3.x 给旧行
  /// 新增 bool 字段回填 false（同 [readingMode] 的回填陷阱），「默认开启」
  /// 只能以 hide=false 表达才对既有用户生效。读取一律走 [showColumnRules]。
  bool hideColumnRules = false;

  @ignore
  bool get showColumnRules => !hideColumnRules;

  /// 竖排白文模式（剥除全部标点）；默认关，旧行回填 false 恰为所需。
  bool baiwenMode = false;

  /// Web: hasSeenBookTour.
  bool hasSeenReaderTips = false;

  /// Web: classicTextsActiveTab / classicTextsVisible.
  String classicsActiveTab = '般若';
  bool classicsVisible = true;
}
