/**
 * rtl 滚动坐标归一化(W4/WB1):滚动坐标的唯一出入口。
 *
 * rtl 容器的 scrollLeft ∈ [−max, 0](现代浏览器已按规范统一):
 * 0 = 卷首(最右),向左展开为负。对外统一为 offset = 已展开距离 ≥ 0。
 */

/** 当前展开距离(≥0,0 = 卷首)。 */
export function readOffset(el: HTMLElement): number {
  return -el.scrollLeft;
}

/** 滚动到展开距离 x。 */
export function setOffset(el: HTMLElement, x: number, behavior: ScrollBehavior = 'auto'): void {
  el.scrollTo({ left: -x, behavior });
}

/** 最大展开距离(卷尾)。 */
export function maxOffset(el: HTMLElement): number {
  return el.scrollWidth - el.clientWidth;
}
