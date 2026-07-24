/**
 * 竖排渲染样式常量(web-vertical-reader-plan.md §7.2,验收 CW6/CW7;
 * 移植自 flutter-app/lib/presentation/widgets/vertical_page_painter.dart
 * 的 VerticalPageStyles + 标点校准表,数值两端一致)。
 */
import type { VerticalGridSpec } from '@/lib/vertical/gridGeometry';
import type { VColumnRole } from '@/lib/vertical/models';

/** 悬浮标点绘制上限(A5:数据全留,绘制截断)。 */
export const MAX_PUNCT_GLYPHS = 2;

/**
 * 标点字号几何自适应(Flutter S5 坐标推演结论):0.45×fs 在默认行距下
 * 会超出悬浮区触碰乌丝栏,故以 gap×0.52 约束;0.28×fs 为可读性保底——
 * 行距 <1.6 时保底生效,em 框可略过界但墨迹(居框左下象限)仍在界内。
 */
export function punctFontSize(grid: VerticalGridSpec): number {
  const v = grid.gap * 0.52;
  const lo = grid.fontSize * 0.28;
  const hi = grid.fontSize * 0.45;
  return Math.min(Math.max(v, lo), hi);
}

/**
 * 常用标点墨迹锚点微调(em 单位):全角句逗的墨迹居其 em 框左下象限,
 * 上移少许使其贴靠所属字的右下角。web 字体下的复标定在 WS2 golden
 * 锁定时进行,初值取 Flutter 校准表。
 */
export const PUNCT_NUDGE_EM: Readonly<Record<string, { dx: number; dy: number }>> = {
  '。': { dx: -0.06, dy: -0.1 },
  '，': { dx: -0.06, dy: -0.1 },
  '、': { dx: -0.06, dy: -0.1 },
  '；': { dx: -0.04, dy: -0.06 },
  '：': { dx: -0.04, dy: -0.06 },
};

/** 悬浮标点堆叠:锚点系数(首枚上提 0.85·punctH,次枚下移 0.78·punctH)。 */
export const PUNCT_ANCHOR_LIFT = 0.85;
export const PUNCT_STACK_STEP = 0.78;

/** 标点悬浮区起点(所属字右缘外 0.06·gap)与乌丝栏位(0.62·gap),同 §6。 */
export const PUNCT_BASE_GAP = 0.06;
export const RULE_GAP = 0.62;

export interface RoleCss {
  /** 相对正文字号的缩放(author 0.8,其余 1)。 */
  fontScale: number;
  fontWeight: 400 | 600 | 700;
  color: string;
}

/** 角色样式(镜像 VerticalPageStyles:title/bt w700、bm w600、author 0.8×muted)。 */
export function roleCss(role: VColumnRole): RoleCss {
  switch (role) {
    case 'title':
    case 'bt':
      return { fontScale: 1, fontWeight: 700, color: 'hsl(var(--foreground))' };
    case 'bm':
      return { fontScale: 1, fontWeight: 600, color: 'hsl(var(--foreground))' };
    case 'author':
      return { fontScale: 0.8, fontWeight: 400, color: 'hsl(var(--muted-foreground))' };
    case 'body':
      return { fontScale: 1, fontWeight: 400, color: 'hsl(var(--foreground))' };
  }
}

/** 悬浮句读颜色(前景 85%,镜像 Flutter punct 样式)。 */
export const PUNCT_COLOR = 'hsl(var(--foreground) / 0.85)';

/** 乌丝栏默认颜色(淡墨;WS2 golden 视觉校准的调参位)。 */
export const RULE_COLOR = 'hsl(var(--foreground) / 0.28)';
