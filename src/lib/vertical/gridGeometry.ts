/**
 * 竖排网格几何(web-vertical-reader-plan.md §6,验收 CW1;
 * 移植自 flutter-app/lib/core/vertical/grid_geometry.dart,公式两端一致)。
 *
 * 一切坐标由公式给出、与字体度量无关——「活字版矩阵」的根基。
 * 坐标系:内容区局部坐标(原点 = 内容区左上角)。
 * 列序 i 从右向左(i=0 最右列),格序 j 从上向下。
 */

/** 列距倍率钳制下限:低于 1.35 时列隙容不下悬浮标点与乌丝栏。 */
export const MIN_LINE_PITCH = 1.35;
export const MAX_LINE_PITCH = 3.0;

const EPSILON = 1e-9;

export interface VerticalGridSpec {
  contentW: number;
  contentH: number;
  /** 有效字号(可能被 A1 兜底钳小)。 */
  fontSize: number;
  cellW: number;
  cellH: number;
  /** 列距(相邻两列左缘间距)= cellW + gap。 */
  colPitch: number;
  /** 列间隙:标点悬浮区 + 乌丝栏 + 呼吸区共居于此。 */
  gap: number;
  charsPerCol: number;
  colsPerPage: number;
  /** 网格实宽(末列无尾隙);水平居中后两侧各余 leftInset(= W2 的 padSide)。 */
  gridW: number;
  leftInset: number;
  /** A1 兜底被触发(字号被钳制)。 */
  degraded: boolean;
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.min(Math.max(v, lo), hi);
}

/**
 * 由内容区与排版设置推导全部几何。字号超出可容纳范围时钳制到
 * 恰能容纳 1 格 × 1 列(A1 兜底),并标记 degraded。
 * 非有限输入一律替换为安全默认(NaN 防御,最后防线)。
 */
export function fitGrid(input: {
  contentW: number;
  contentH: number;
  fontSize: number;
  linePitch: number;
  charGapEm: number;
}): VerticalGridSpec {
  const safeFontSize = Number.isFinite(input.fontSize) ? input.fontSize : 20;
  const safeLinePitch = Number.isFinite(input.linePitch) ? input.linePitch : 1.75;
  const safeCharGap = Number.isFinite(input.charGapEm) ? input.charGapEm : 0;
  const safeW = Math.max(Number.isFinite(input.contentW) ? input.contentW : 1, 1);
  const safeH = Math.max(Number.isFinite(input.contentH) ? input.contentH : 1, 1);

  const cellHFactor = 1 + Math.max(0, safeCharGap);
  const pitchFactor = clamp(safeLinePitch, MIN_LINE_PITCH, MAX_LINE_PITCH);

  let fs = Math.max(safeFontSize, 1);
  const maxFs = Math.min(safeH / cellHFactor, safeW);
  const degraded = fs > maxFs;
  if (degraded) fs = maxFs;

  const cellW = fs;
  const cellH = fs * cellHFactor;
  const colPitch = fs * pitchFactor;
  const gap = colPitch - cellW;
  const charsPerCol = Math.max(Math.floor(safeH / cellH + EPSILON), 1);
  const colsPerPage = Math.max(Math.floor((safeW + gap) / colPitch + EPSILON), 1);
  const gridW = colsPerPage * colPitch - gap;

  return {
    contentW: safeW,
    contentH: safeH,
    fontSize: fs,
    cellW,
    cellH,
    colPitch,
    gap,
    charsPerCol,
    colsPerPage,
    gridW,
    leftInset: (safeW - gridW) / 2,
    degraded,
  };
}

/** 第 i 列(i=0 最右)字面框左缘 x(页局部坐标,翻页/golden 用)。 */
export function colX(spec: VerticalGridSpec, i: number): number {
  return spec.leftInset + spec.gridW - spec.colPitch * i - spec.cellW;
}

/** 第 j 格上缘 y。 */
export function cellY(spec: VerticalGridSpec, j: number): number {
  return spec.cellH * j;
}

/** 文本区底缘(乌丝栏下端与此对齐)。 */
export function gridBottom(spec: VerticalGridSpec): number {
  return spec.cellH * spec.charsPerCol;
}

/**
 * 第 i 列与第 i−1 列之间的乌丝栏 x(位于列 i 右缘外 0.62·gap,
 * 为悬浮标点让出 0~0.55·gap 区)。取值域 i ∈ [1, colsPerPage)。
 */
export function ruleX(spec: VerticalGridSpec, i: number): number {
  return colX(spec, i) + spec.cellW + spec.gap * 0.62;
}

/** 列条目局部坐标系下的乌丝栏 x(滚动条目内右隙,§5.1 渲染用)。 */
export function ruleXInColumn(spec: VerticalGridSpec): number {
  return spec.cellW + spec.gap * 0.62;
}
