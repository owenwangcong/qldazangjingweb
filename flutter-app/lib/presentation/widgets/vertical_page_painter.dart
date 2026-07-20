import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/vertical/grid_geometry.dart';
import '../../core/vertical/vertical_models.dart';

/// 竖排页面样式集（实施方案 §5/§7）。
///
/// 关键：全部样式 height 固定 1.0——TextPainter 的行盒高即等于字号，
/// 字形在字面框内的双向居中公式才是精确的（矩阵对齐由公式保证，
/// 不受字体行高元数据影响）。
class VerticalPageStyles {
  VerticalPageStyles({
    required String? fontFamily,
    required double fontSize,
    required double gap,
    required Color foreground,
    required Color muted,
  })  : body = TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: 1.0,
          color: foreground,
        ),
        bt = TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: 1.0,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
        bm = TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
        title = TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: 1.0,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
        author = TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize * 0.8,
          height: 1.0,
          color: muted,
        ),
        // 标点字号几何自适应（S5 坐标推演）：0.45×fs 在默认行距下会超出
        // 悬浮区触碰乌丝栏，故以 gap×0.52 约束；0.28×fs 为可读性保底——
        // 行距 <1.6 时保底生效，em 框可略过界但墨迹（居框左下象限）仍在
        // 界内（vertical_painter_test C7 按默认行距做严格 em 框断言）。
        punct = TextStyle(
          fontFamily: fontFamily,
          fontSize: (gap * 0.52).clamp(fontSize * 0.28, fontSize * 0.45),
          height: 1.0,
          color: foreground.withValues(alpha: 0.85),
        );

  final TextStyle body;
  final TextStyle bt;
  final TextStyle bm;
  final TextStyle title;
  final TextStyle author;
  final TextStyle punct;

  TextStyle forRole(VColumnRole role) => switch (role) {
        VColumnRole.title => title,
        VColumnRole.author => author,
        VColumnRole.bt => bt,
        VColumnRole.bm => bm,
        VColumnRole.body => body,
      };

  /// 缓存失效签名：任一分量变化都必须重建字形缓存。
  String get signature => [
        body.fontFamily,
        body.fontSize,
        punct.fontSize,
        body.color?.toARGB32(),
        author.color?.toARGB32(),
      ].join('|');
}

/// 字形缓存：(role|char) → 已 layout 的 TextPainter，跨页共享。
/// 一卷经书去重字符量通常 <3000，首页排布后命中率趋近 100%。
class GlyphCache {
  final _map = <String, TextPainter>{};
  String _signature = '';
  static const _capacity = 4096;

  /// 样式代际检查：签名变化（字体/字号/主题色）→ 全量废弃。
  void ensureSignature(String signature) {
    if (_signature == signature) return;
    _signature = signature;
    clear();
  }

  TextPainter painterFor(String roleKey, String text, TextStyle style) {
    final key = '$roleKey|$text';
    final hit = _map.remove(key);
    if (hit != null) {
      _map[key] = hit; // LRU 触达
      return hit;
    }
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    _map[key] = tp;
    if (_map.length > _capacity) {
      final evictKey = _map.keys.first;
      _map.remove(evictKey)?.dispose();
    }
    return tp;
  }

  void clear() {
    for (final tp in _map.values) {
      tp.dispose();
    }
    _map.clear();
  }
}

/// 常用标点墨迹锚点微调（em 单位，S7 按字体调优）：全角句逗的墨迹
/// 居其 em 框左下象限，上移少许使其贴靠所属字的右下角。
const Map<String, Offset> _punctNudgeEm = {
  '。': Offset(-0.06, -0.10),
  '，': Offset(-0.06, -0.10),
  '、': Offset(-0.06, -0.10),
  '；': Offset(-0.04, -0.06),
  '：': Offset(-0.04, -0.06),
};

/// 单页画师（实施方案 §5/§6，验收 C6/C7/C8）。
/// 只画文字/标点/乌丝栏；纸面背景由主题层提供。
class VerticalPagePainter extends CustomPainter {
  VerticalPagePainter({
    required this.page,
    required this.grid,
    required this.styles,
    required this.glyphs,
    required this.showColumnRules,
    required this.ruleColor,
    required this.ruleStrokeWidth,
  }) {
    glyphs.ensureSignature(styles.signature);
  }

  final VPage page;
  final VerticalGridSpec grid;
  final VerticalPageStyles styles;
  final GlyphCache glyphs;
  final bool showColumnRules;
  final Color ruleColor;
  final double ruleStrokeWidth;

  /// 悬浮标点绘制上限（§10 A5：数据全留，绘制截断）。
  static const int maxPunctGlyphs = 2;

  @override
  void paint(Canvas canvas, Size size) {
    assert(page.imageUrl == null && !page.isNavPage,
        '插图/nav 页由 widget 层呈现，不进画布');
    _paintRules(canvas);
    for (var ci = 0; ci < page.columns.length; ci++) {
      _paintColumn(canvas, ci, page.columns[ci]);
    }
  }

  /// 乌丝栏：仅绘于实有列之间，上下两端与文本区边界齐平（C8）。
  void _paintRules(Canvas canvas) {
    if (!showColumnRules || page.columns.length < 2) return;
    final paint = Paint()
      ..color = ruleColor
      ..strokeWidth = ruleStrokeWidth
      ..strokeCap = ui.StrokeCap.butt;
    for (var i = 1; i < page.columns.length; i++) {
      final x = grid.ruleX(i);
      canvas.drawLine(Offset(x, 0), Offset(x, grid.gridBottom), paint);
    }
  }

  void _paintColumn(Canvas canvas, int ci, VColumn col) {
    final style = styles.forRole(col.role);
    final roleKey = col.role.name;
    final colLeft = grid.colX(ci);
    final verseN = col.verseClauseLen;
    for (var ti = 0; ti < col.tokens.length; ti++) {
      final token = col.tokens[ti];
      // 偈颂句间空一格（D6）：每满一句下移一格。
      final row = col.indent + ti + (verseN == null ? 0 : ti ~/ verseN);
      final tp = glyphs.painterFor(roleKey, token.char, style);
      // 双向居中：矩阵对齐由公式保证，与字体度量无关（C6 核心）。
      final dx = colLeft + (grid.cellW - tp.width) / 2;
      final dy = grid.cellY(row) + (grid.cellH - tp.height) / 2;
      tp.paint(canvas, Offset(dx, dy));

      if (token.trailingPunct.isNotEmpty) {
        _paintPunct(canvas, colLeft, row, token.trailingPunct);
      }
    }
  }

  /// 悬浮句读：所属字右下、列隙悬浮区内（C7——标点零侵占字面框，
  /// em 框不越过乌丝栏）。多枚纵向下堆，最多 2 枚。
  void _paintPunct(Canvas canvas, double colLeft, int row, String puncts) {
    final baseX = colLeft + grid.cellW + grid.gap * 0.06;
    final cellBottom = grid.cellY(row) + grid.cellH;
    var drawn = 0;
    for (final rune in puncts.runes) {
      if (drawn >= maxPunctGlyphs) break;
      final ch = String.fromCharCode(rune);
      final pp = glyphs.painterFor('punct', ch, styles.punct);
      final nudge = _punctNudgeEm[ch] ?? Offset.zero;
      final em = styles.punct.fontSize!;
      final px = baseX + nudge.dx * em;
      var py = cellBottom - pp.height * 0.85 +
          drawn * pp.height * 0.78 +
          nudge.dy * em;
      py = math.min(py, grid.gridBottom - pp.height);
      pp.paint(canvas, Offset(px, py));
      drawn++;
    }
  }

  @override
  bool shouldRepaint(VerticalPagePainter oldDelegate) =>
      !identical(oldDelegate.page, page) ||
      oldDelegate.grid != grid ||
      oldDelegate.styles.signature != styles.signature ||
      oldDelegate.showColumnRules != showColumnRules ||
      oldDelegate.ruleColor != ruleColor;
}
