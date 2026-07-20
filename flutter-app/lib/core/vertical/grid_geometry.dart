import 'dart:math' as math;
import 'dart:ui';

/// 竖排网格几何（实施方案 §6，验收 C1）。
///
/// 一切坐标由公式给出、与字体度量无关——这是「活字版矩阵」的根基。
/// 坐标系：内容区局部坐标（原点 = 内容区左上角，已去除页边距/SafeArea）。
/// 列序 i 从右向左（i=0 最右列），格序 j 从上向下。
class VerticalGridSpec {
  VerticalGridSpec._({
    required this.contentSize,
    required this.fontSize,
    required this.cellW,
    required this.cellH,
    required this.colPitch,
    required this.gap,
    required this.charsPerCol,
    required this.colsPerPage,
    required this.gridW,
    required this.leftInset,
    required this.degraded,
  });

  /// 由内容区与排版设置推导全部几何。字号超出可容纳范围时钳制到
  /// 恰能容纳 1 格 × 1 列（§10 A1 兜底），并标记 [degraded]。
  ///
  /// [fontSize] 应为**有效字号**（用户字号 × textScaleFactor），
  /// 系统缩放的语义折叠在调用侧完成。
  factory VerticalGridSpec.fit({
    required Size contentSize,
    required double fontSize,
    required double lineHeight,
    required double letterSpacingEm,
  }) {
    // 非有限输入防御（2026-07-20 真机白屏事故：isar 旧行 double 回填
    // NaN，经 math.max 传染到 floor 崩溃）——上游应传 effective 值，
    // 此处为最后防线：坏值替换为安全默认，绝不让 NaN 进网格。
    assert(fontSize.isFinite && lineHeight.isFinite && letterSpacingEm.isFinite,
        '几何输入含非有限值: fs=$fontSize lh=$lineHeight ls=$letterSpacingEm');
    final safeFontSize = fontSize.isFinite ? fontSize : 20.0;
    final safeLineHeight = lineHeight.isFinite ? lineHeight : 1.75;
    final safeLetterSpacing = letterSpacingEm.isFinite ? letterSpacingEm : 0.0;

    final safeW = math.max(
        contentSize.width.isFinite ? contentSize.width : 1.0, 1.0);
    final safeH = math.max(
        contentSize.height.isFinite ? contentSize.height : 1.0, 1.0);
    final cellHFactor = 1 + math.max(0.0, safeLetterSpacing);
    final pitchFactor = safeLineHeight.clamp(minLineHeight, maxLineHeight);

    var fs = math.max(safeFontSize, 1.0);
    final maxFs = math.min(safeH / cellHFactor, safeW);
    final degraded = fs > maxFs;
    if (degraded) fs = maxFs;

    final cellW = fs;
    final cellH = fs * cellHFactor;
    final colPitch = fs * pitchFactor;
    final gap = colPitch - cellW;
    final charsPerCol = (safeH / cellH + _epsilon).floor();
    final colsPerPage = ((safeW + gap) / colPitch + _epsilon).floor();
    assert(charsPerCol >= 1 && colsPerPage >= 1,
        '几何兜底失效: $charsPerCol×$colsPerPage');
    final gridW = colsPerPage * colPitch - gap;

    return VerticalGridSpec._(
      contentSize: Size(safeW, safeH),
      fontSize: fs,
      cellW: cellW,
      cellH: cellH,
      colPitch: colPitch,
      gap: gap,
      charsPerCol: math.max(charsPerCol, 1),
      colsPerPage: math.max(colsPerPage, 1),
      gridW: gridW,
      leftInset: (safeW - gridW) / 2,
      degraded: degraded,
    );
  }

  /// 列距倍率钳制下限：低于 1.35 时列隙容不下悬浮标点与乌丝栏（§6）。
  static const double minLineHeight = 1.35;
  static const double maxLineHeight = 3.0;
  static const double _epsilon = 1e-9;

  final Size contentSize;

  /// 有效字号（可能被 A1 兜底钳小）。
  final double fontSize;
  final double cellW;
  final double cellH;

  /// 列距（相邻两列左缘间距）= cellW + gap。
  final double colPitch;

  /// 列间隙：标点悬浮区 + 乌丝栏 + 呼吸区共居于此。
  final double gap;

  final int charsPerCol;
  final int colsPerPage;

  /// 网格实宽（末列无尾隙）；水平居中后两侧各余 [leftInset]。
  final double gridW;
  final double leftInset;

  /// A1 兜底被触发（字号被钳制）。
  final bool degraded;

  /// 第 i 列（i=0 最右）字面框左缘 x。
  double colX(int i) {
    assert(i >= 0 && i < colsPerPage);
    return leftInset + gridW - colPitch * i - cellW;
  }

  /// 第 j 格上缘 y。
  double cellY(int j) => cellH * j;

  /// 文本区底缘（乌丝栏下端与此对齐）。
  double get gridBottom => cellH * charsPerCol;

  /// 第 i 列与第 i−1 列之间的乌丝栏 x（位于列 i 右缘外 0.62·gap，
  /// 为悬浮标点让出 0~0.55·gap 区，§6）。取值域 i ∈ [1, colsPerPage)。
  double ruleX(int i) {
    assert(i >= 1 && i < colsPerPage);
    return colX(i) + cellW + gap * 0.62;
  }
}
