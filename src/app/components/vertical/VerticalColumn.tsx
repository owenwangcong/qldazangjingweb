'use client';

/**
 * 竖排列条目(web-vertical-reader-plan.md §7.2,验收 CW6/CW7/CW8;
 * 行为对齐 flutter vertical_page_painter.dart 的 paintColumnGlyphs +
 * VerticalColumnPainter)。
 *
 * 条目局部坐标:字面框 [0, cellW],右侧间隙 [cellW, colPitch] 自含
 * 悬浮标点区与乌丝栏——绘制完全落在自身条目内,无跨条目依赖。
 * 矩阵对齐由公式保证(绝对定位 + 定宽格 + line-height=cellH 的半行距
 * 居中),与字体度量无关(CW6 核心)。
 *
 * 注意:本文件刻意用 React.createElement 而非 JSX——Playwright 的转译器
 * 会把被测试导入的 .tsx 中的 JSX 编成 __pw_type 标记对象,导致
 * renderToStaticMarkup 崩溃(实施备忘 WS2);WS2.4 坐标断言依赖在测试内
 * SSR 本组件,故保持无 JSX。
 */
import React, { type CSSProperties, type ReactNode } from 'react';
import { cellY, gridBottom, type VerticalGridSpec } from '@/lib/vertical/gridGeometry';
import type { VColumn } from '@/lib/vertical/models';
import {
  MAX_PUNCT_GLYPHS,
  PUNCT_ANCHOR_LIFT,
  PUNCT_BASE_GAP,
  PUNCT_COLOR,
  PUNCT_NUDGE_EM,
  PUNCT_STACK_STEP,
  punctFontSize,
  roleCss,
  RULE_COLOR,
  RULE_GAP,
} from './verticalStyles';

const h = React.createElement;

export interface VerticalColumnProps {
  column: VColumn;
  grid: VerticalGridSpec;
  /** 列带首列(最右)不画界线,两端语义与翻页一致(CW8)。 */
  showRule: boolean;
  /** 乌丝栏线宽 px(容器按 1/devicePixelRatio 计算后传入;默认 1)。 */
  ruleWidthPx?: number;
  /** 容器附加类(WS3 吸附预设用:页首列/每列 scroll-snap-align)。 */
  className?: string;
}

/**
 * 单列渲染。DOM 序 = 阅读序(先字后其悬浮标点),复制文本天然可用(W1)。
 */
export default function VerticalColumn({
  column,
  grid,
  showRule,
  ruleWidthPx = 1,
  className,
}: VerticalColumnProps) {
  const rcss = roleCss(column.role);
  const verseN = column.verseClauseLen;
  const pfs = punctFontSize(grid);
  const bottom = gridBottom(grid);
  const charFs = grid.fontSize * rcss.fontScale;
  const ruleX = grid.cellW + grid.gap * RULE_GAP;

  const children: ReactNode[] = [];
  for (let ti = 0; ti < column.tokens.length; ti++) {
    const token = column.tokens[ti];
    // 偈颂句间空一格(D6):每满一句下移一格,行号 = indent + i + ⌊i/n⌋。
    const row = column.indent + ti + (verseN === undefined ? 0 : Math.floor(ti / verseN));
    const top = cellY(grid, row);
    children.push(
      h(
        'span',
        {
          key: `c${ti}`,
          className: 'v-char',
          style: {
            position: 'absolute',
            left: 0,
            top,
            width: grid.cellW,
            height: grid.cellH,
            lineHeight: `${grid.cellH}px`,
            fontSize: charFs,
            fontWeight: rcss.fontWeight,
            color: rcss.color,
            textAlign: 'center',
          } satisfies CSSProperties,
        },
        token.char,
      ),
    );

    if (token.trailingPunct !== '') {
      // 悬浮句读:所属字右下、列隙悬浮区内;多枚纵向下堆,最多 2 枚(A5)。
      const cellBottom = top + grid.cellH;
      let drawn = 0;
      for (const ch of token.trailingPunct) {
        if (drawn >= MAX_PUNCT_GLYPHS) break;
        const nudge = PUNCT_NUDGE_EM[ch] ?? { dx: 0, dy: 0 };
        const px = grid.cellW + grid.gap * PUNCT_BASE_GAP + nudge.dx * pfs;
        const py = Math.min(
          cellBottom - pfs * PUNCT_ANCHOR_LIFT + drawn * pfs * PUNCT_STACK_STEP + nudge.dy * pfs,
          bottom - pfs,
        );
        children.push(
          h(
            'span',
            {
              key: `p${ti}-${drawn}`,
              className: 'v-punct',
              'aria-hidden': 'true',
              style: {
                position: 'absolute',
                left: px,
                top: py,
                height: pfs,
                lineHeight: `${pfs}px`,
                fontSize: pfs,
                color: PUNCT_COLOR,
              } satisfies CSSProperties,
            },
            ch,
          ),
        );
        drawn++;
      }
    }
  }

  if (showRule) {
    children.push(
      h('div', {
        key: 'rule',
        className: 'v-rule',
        'aria-hidden': 'true',
        style: {
          position: 'absolute',
          left: ruleX - ruleWidthPx / 2,
          top: 0,
          width: ruleWidthPx,
          height: bottom,
          background: RULE_COLOR,
        } satisfies CSSProperties,
      }),
    );
  }

  return h(
    'div',
    {
      'data-vcol': column.role,
      className,
      style: {
        position: 'relative',
        flex: '0 0 auto',
        width: grid.colPitch,
        height: bottom,
        contentVisibility: 'auto',
        containIntrinsicSize: `${grid.colPitch}px ${bottom}px`,
      } as CSSProperties,
    },
    children,
  );
}
