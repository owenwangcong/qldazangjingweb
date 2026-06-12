/// 水墨设计语言（ink design language）的统一出口。
///
/// 本目录承载水墨禅意改造的全部表现层基建（docs/ink-design-plan.md）：
/// - `tokens/`     InkTokens ThemeExtension（墨色三档、纸色、朱砂、墨晕阴影…）
/// - `painting/`   CustomPainter 类组件（笔触、白描意象、墨圈…）
/// - `shading/`    FragmentProgram 封装（宣纸纹理、破墨遮罩…）
/// - `motion/`     动效规范常量与曲线（§4.2）
///
/// 各模块随 P1/P2 落地后在此 export。
library;

export 'canvas/ink_scroll_canvas.dart';
export 'painting/brush_line.dart';
export 'painting/enso_loading.dart';
export 'painting/ink_card.dart';
export 'painting/ink_drop_splash.dart';
export 'painting/ink_nav_bar.dart';
export 'painting/motifs.dart';
export 'shading/ink_bloom_reveal.dart';
export 'shading/ink_paper_background.dart';
export 'tokens/ink_tokens.dart';
