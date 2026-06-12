import 'package:flutter/material.dart';

import '../tokens/ink_tokens.dart';

/// overscroll 墨雾（P4.1）：列表越界时不再用 Material 的 stretch/glow
/// 原色，而是以当前主题的 mistColor 晕出一层淡墨雾，似卷边遇潮。
/// 通过 `MaterialApp.scrollBehavior` 全局注入。
class InkMistScrollBehavior extends MaterialScrollBehavior {
  const InkMistScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: context.ink.mistColor,
      child: child,
    );
  }
}
