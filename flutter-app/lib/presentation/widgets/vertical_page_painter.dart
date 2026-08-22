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
    this.strokeWidthEm = 0,
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

  /// 字重描边宽（em，×各角色字号得像素；font-weight-quotes-plan.md FQ1）。
  /// 0 = 标准档。描边不改变字形 advance 度量，网格几何/分页键不感知。
  final double strokeWidthEm;

  final _strokeCache = <String, TextStyle?>{};

  TextStyle forRole(VColumnRole role) => switch (role) {
        VColumnRole.title => title,
        VColumnRole.author => author,
        VColumnRole.bt => bt,
        VColumnRole.bm => bm,
        VColumnRole.body => body,
      };

  /// 角色的描边变体（标准档返回 null，不叠绘）。按 key 缓存——
  /// 逐字绘制路径上不得每字新建 TextStyle/Paint。
  TextStyle? strokeFor(String key, TextStyle base) {
    if (strokeWidthEm <= 0) return null;
    return _strokeCache.putIfAbsent(
      key,
      () => TextStyle(
        fontFamily: base.fontFamily,
        fontSize: base.fontSize,
        height: base.height,
        fontWeight: base.fontWeight,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = base.fontSize! * strokeWidthEm
          ..color = base.color!,
      ),
    );
  }

  /// 缓存失效签名：任一分量变化都必须重建字形缓存。
  String get signature => [
        body.fontFamily,
        body.fontSize,
        punct.fontSize,
        body.color?.toARGB32(),
        author.color?.toARGB32(),
        strokeWidthEm,
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

/// 悬浮标点绘制上限（§10 A5：数据全留，绘制截断）。
const int _maxPunctGlyphs = 2;

/// 共享绘列核心（V2,vertical-scroll-plan.md §2.2）：在 [originX] 起点
/// 绘一列——字面框双向居中、偈颂行号 i+i÷n（D6 句间空格）、悬浮句读
/// 落于右侧间隙。翻页画师按 colX(ci) 调用;滚动条目画师按 0 调用。
void paintColumnGlyphs(
  Canvas canvas,
  VerticalGridSpec grid,
  VerticalPageStyles styles,
  GlyphCache glyphs,
  VColumn col,
  double originX,
) {
  final style = styles.forRole(col.role);
  final roleKey = col.role.name;
  // 字重描边层（FQ1）：同色 stroke 叠于填充之上使笔画增粗；
  // 仅非标准档存在，每字形 +1 次绘制（raster 预算见台账验收 CW）。
  final strokeStyle = styles.strokeFor(roleKey, style);
  final verseN = col.verseClauseLen;
  for (var ti = 0; ti < col.tokens.length; ti++) {
    final token = col.tokens[ti];
    // 偈颂句间空一格（D6）：每满一句下移一格。
    final row = col.indent + ti + (verseN == null ? 0 : ti ~/ verseN);
    final tp = glyphs.painterFor(roleKey, token.char, style);
    // 双向居中：矩阵对齐由公式保证，与字体度量无关（C6 核心）。
    final dx = originX + (grid.cellW - tp.width) / 2;
    final dy = grid.cellY(row) + (grid.cellH - tp.height) / 2;
    tp.paint(canvas, Offset(dx, dy));
    if (strokeStyle != null) {
      glyphs
          .painterFor('S:$roleKey', token.char, strokeStyle)
          .paint(canvas, Offset(dx, dy));
    }

    if (token.trailingPunct.isNotEmpty) {
      _paintPunctAt(canvas, grid, styles, glyphs, originX, row,
          token.trailingPunct);
    }
  }
}

/// 悬浮句读：所属字右下、列隙悬浮区内（C7——标点零侵占字面框，
/// em 框不越过乌丝栏）。多枚纵向下堆，最多 2 枚。
void _paintPunctAt(
  Canvas canvas,
  VerticalGridSpec grid,
  VerticalPageStyles styles,
  GlyphCache glyphs,
  double originX,
  int row,
  String puncts,
) {
  final baseX = originX + grid.cellW + grid.gap * 0.06;
  final cellBottom = grid.cellY(row) + grid.cellH;
  final strokeStyle = styles.strokeFor('punct', styles.punct);
  var drawn = 0;
  for (final rune in puncts.runes) {
    if (drawn >= _maxPunctGlyphs) break;
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
    if (strokeStyle != null) {
      glyphs.painterFor('S:punct', ch, strokeStyle).paint(canvas, Offset(px, py));
    }
    drawn++;
  }
}

/// 滚动条目画师（V2）：单列条目,字面框在条目左侧 [0, cellW],右侧间隙
/// [cellW, colPitch] 自含悬浮标点与乌丝栏——绘制无跨条目依赖。
/// [showRule] 画在 x = cellW + 0.62·gap（与翻页 ruleX 公式同源）;
/// 列带首列（最右）不画,保持两端界线语义与翻页一致。
class VerticalColumnPainter extends CustomPainter {
  VerticalColumnPainter({
    required this.column,
    required this.grid,
    required this.styles,
    required this.glyphs,
    required this.showRule,
    required this.ruleColor,
    required this.ruleStrokeWidth,
  }) {
    glyphs.ensureSignature(styles.signature);
  }

  final VColumn column;
  final VerticalGridSpec grid;
  final VerticalPageStyles styles;
  final GlyphCache glyphs;
  final bool showRule;
  final Color ruleColor;
  final double ruleStrokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (showRule) {
      final x = grid.cellW + grid.gap * 0.62;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, grid.gridBottom),
        Paint()
          ..color = ruleColor
          ..strokeWidth = ruleStrokeWidth
          ..strokeCap = ui.StrokeCap.butt,
      );
    }
    paintColumnGlyphs(canvas, grid, styles, glyphs, column, 0);
  }

  @override
  bool shouldRepaint(VerticalColumnPainter oldDelegate) =>
      !identical(oldDelegate.column, column) ||
      oldDelegate.grid != grid ||
      oldDelegate.styles.signature != styles.signature ||
      oldDelegate.showRule != showRule ||
      oldDelegate.ruleColor != ruleColor;
}

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

  @override
  void paint(Canvas canvas, Size size) {
    assert(page.imageUrl == null && !page.isNavPage,
        '插图/nav 页由 widget 层呈现，不进画布');
    _paintRules(canvas);
    for (var ci = 0; ci < page.columns.length; ci++) {
      paintColumnGlyphs(
          canvas, grid, styles, glyphs, page.columns[ci], grid.colX(ci));
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

  @override
  bool shouldRepaint(VerticalPagePainter oldDelegate) =>
      !identical(oldDelegate.page, page) ||
      oldDelegate.grid != grid ||
      oldDelegate.styles.signature != styles.signature ||
      oldDelegate.showColumnRules != showColumnRules ||
      oldDelegate.ruleColor != ruleColor;
}
