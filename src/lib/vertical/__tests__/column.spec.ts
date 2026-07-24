/**
 * CW6 矩阵对齐 / CW7 标点悬浮 / CW8 乌丝栏 —— DOM 坐标断言 + golden。
 *
 * 渲染真书 0998 的列带切片(引擎产物已被 CW14 指纹锁定,输入稳定),
 * ReactDOMServer 静态渲染 → page.setContent → getBoundingClientRect 断言。
 * 坐标全部由公式推导,断言即公式(与 Flutter C6~C8 同口径)。
 */
import { readFileSync } from 'fs';
import { join } from 'path';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { expect, test, type Page } from '@playwright/test';
import VerticalColumn from '../../../app/components/vertical/VerticalColumn';
import { punctFontSize, RULE_GAP, PUNCT_STACK_STEP } from '../../../app/components/vertical/verticalStyles';
import { parseBookData, type VColumn } from '../models';
import { clearVerticalCache, paginateVertical } from '../paginator';
import type { VerticalGridSpec } from '../gridGeometry';

test.beforeEach(() => clearVerticalCache());

const RULE_W = 1;

function result0998() {
  const book = parseBookData(
    JSON.parse(readFileSync(join(process.cwd(), 'public', 'data', 'books', '0998.json'), 'utf8')),
  );
  return paginateVertical({
    key: {
      bookId: 'ws2-0998',
      contentW: 640,
      contentH: 1257,
      fontFamily: '',
      fontSize: 20,
      linePitch: 1.75,
      charGapEm: 0,
      isSimplified: true,
      baiwen: false,
    },
    book,
    display: (s) => s,
  });
}

/** 列带切片 → 静态页(flex row-reverse:DOM 序 = 阅读序,视觉右→左)。 */
function stripHtml(columns: VColumn[], grid: VerticalGridSpec): string {
  const inner = renderToStaticMarkup(
    React.createElement(
      'div',
      {
        id: 'strip',
        style: {
          display: 'flex',
          flexDirection: 'row-reverse',
          justifyContent: 'flex-start',
          width: columns.length * grid.colPitch,
        },
      },
      columns.map((c, i) =>
        React.createElement(VerticalColumn, {
          key: i,
          column: c,
          grid,
          showRule: i > 0, // 首列(最右)不画(CW8)。
          ruleWidthPx: RULE_W,
        }),
      ),
    ),
  );
  return `<!doctype html><html><head><meta charset="utf-8"><style>
    :root { --foreground: 0 0% 3.9%; --muted-foreground: 0 0% 45.1%; }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background: #f7f3e9; font-family: SimSun, serif; padding: 24px; }
  </style></head><body>${inner}</body></html>`;
}

interface ColMeasure {
  left: number;
  top: number;
  role: string;
  chars: { x: number; y: number; w: number; h: number }[];
  puncts: { x: number; y: number; w: number; h: number; ch: string }[];
  rules: { cx: number; top: number; h: number }[];
  text: string;
}

async function measure(page: Page): Promise<ColMeasure[]> {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('[data-vcol]')).map((col) => {
      const cr = col.getBoundingClientRect();
      return {
        left: cr.left,
        top: cr.top,
        role: (col as HTMLElement).dataset.vcol ?? '',
        chars: Array.from(col.querySelectorAll('.v-char')).map((s) => {
          const r = s.getBoundingClientRect();
          return { x: r.x, y: r.y, w: r.width, h: r.height };
        }),
        puncts: Array.from(col.querySelectorAll('.v-punct')).map((s) => {
          const r = s.getBoundingClientRect();
          return { x: r.x, y: r.y, w: r.width, h: r.height, ch: s.textContent ?? '' };
        }),
        rules: Array.from(col.querySelectorAll('.v-rule')).map((s) => {
          const r = s.getBoundingClientRect();
          return { cx: r.x + r.width / 2, top: r.y, h: r.height };
        }),
        text: (col.textContent ?? '').trim(),
      };
    }),
  );
}

const stripColumns = (r: ReturnType<typeof result0998>) =>
  r.strip.flatMap((it) => (it.kind === 'column' ? [it.column] : []));

test('CW6 矩阵对齐:字面框公式定位、列距/格距严格等差(0998 首页)', async ({ page }) => {
  const r = result0998();
  const grid = r.grid;
  const cols = stripColumns(r).slice(0, grid.colsPerPage);
  await page.setContent(stripHtml(cols, grid));
  const m = await measure(page);
  expect(m).toHaveLength(grid.colsPerPage);

  for (const [i, col] of m.entries()) {
    // 列左缘严格等差(row-reverse:DOM 序右→左,公差 −colPitch)。
    if (i > 0) expect(m[i - 1].left - col.left).toBeCloseTo(grid.colPitch, 3);
    for (const [j, ch] of col.chars.entries()) {
      expect(ch.x).toBeCloseTo(col.left, 3); // 字面框贴列左缘
      expect(ch.w).toBeCloseTo(grid.cellW, 3);
      expect(ch.h).toBeCloseTo(grid.cellH, 3);
      // 散文/标题列:相邻字格 y 恒差 cellH(标点零侵占,CW7 前提)。
      if (j > 0 && cols[i].verseClauseLen === undefined) {
        expect(ch.y - col.chars[j - 1].y).toBeCloseTo(grid.cellH, 3);
      }
    }
  }
  // 结构抽查:首列书名、次列作者下沉(indent 生效)。
  expect(m[0].role).toBe('title');
  expect(m[1].role).toBe('author');
  expect(m[1].chars[0].y - m[1].top).toBeCloseTo(cols[1].indent * grid.cellH, 3);
});

test('CW6 偈颂:句间空一格的行号模式 + 跨列句首对齐', async ({ page }) => {
  const r = result0998();
  const grid = r.grid;
  const all = stripColumns(r);
  const vi = all.findIndex((c) => c.verseClauseLen !== undefined);
  expect(vi).toBeGreaterThan(-1);
  const verseCols = all.slice(vi, vi + 6).filter((c) => c.verseClauseLen !== undefined);
  expect(verseCols.length).toBeGreaterThanOrEqual(2);
  await page.setContent(stripHtml(verseCols, grid));
  const m = await measure(page);

  const n = verseCols[0].verseClauseLen!;
  for (const [i, col] of m.entries()) {
    for (let j = 1; j < col.chars.length; j++) {
      // 句内相邻差 cellH;跨句差 2·cellH(句间空一格,D6)。
      const gap = j % n === 0 ? 2 * grid.cellH : grid.cellH;
      expect(col.chars[j].y - col.chars[j - 1].y).toBeCloseTo(gap, 3);
    }
    // 跨列句首对齐:所有偈颂列同构 → 第 j 字 y 与首列逐一相等。
    for (let j = 0; j < col.chars.length; j++) {
      expect(col.chars[j].y - col.top).toBeCloseTo(m[0].chars[j].y - m[0].top, 3);
    }
  }
});

test('CW7 标点悬浮:落于列隙悬浮区、不触乌丝栏、堆叠步进正确', async ({ page }) => {
  const r = result0998();
  const grid = r.grid;
  const all = stripColumns(r);
  // 选标点最密集的一列 + 含双枚堆叠(如「。」)的列。
  const dense = [...all]
    .filter((c) => c.role === 'body')
    .sort(
      (a, b) =>
        b.tokens.filter((t) => t.trailingPunct !== '').length -
        a.tokens.filter((t) => t.trailingPunct !== '').length,
    )[0];
  const stacked = all.find((c) =>
    c.tokens.some((t) => Array.from(t.trailingPunct).length >= 2),
  );
  expect(stacked).toBeTruthy();
  const cols = [dense, stacked!];
  await page.setContent(stripHtml(cols, grid));
  const m = await measure(page);

  const pfs = punctFontSize(grid);
  for (const col of m) {
    expect(col.puncts.length).toBeGreaterThan(0);
    const ruleLeft = col.left + grid.cellW + grid.gap * RULE_GAP - RULE_W / 2;
    for (const p of col.puncts) {
      expect(p.x).toBeGreaterThanOrEqual(col.left + grid.cellW - 0.001); // 零侵占字面框
      expect(p.x + p.w).toBeLessThan(ruleLeft); // em 框不触乌丝栏
      expect(p.h).toBeCloseTo(pfs, 1); // Chrome LayoutUnit 按 1/64px 量化,7.8 不可精确表示

    }
  }
});

test('CW7/A5 绘制截断:悬浮堆 >2 枚只渲染 2 枚;DOM 文本序 = 阅读序(W1)', async ({ page }) => {
  const r = result0998();
  const grid = r.grid;
  const synthetic: VColumn = {
    role: 'body',
    tokens: [
      { char: '字', trailingPunct: '。。。。', blockIndex: 0, paragraphIndex: 0 },
      { char: '文', trailingPunct: '。」', blockIndex: 0, paragraphIndex: 0 },
    ],
    indent: 0,
  };
  await page.setContent(stripHtml([synthetic], grid));
  const m = await measure(page);
  expect(m[0].puncts).toHaveLength(4); // 2 + 2(截断后)
  expect(m[0].text).toBe('字。。文。」');

  // 堆叠坐标精确断言(公式推演,'文' 的「。」对,token 行号 1):
  // px = cellW + 0.06·gap + nudge.dx·pfs;
  // py = cellBottom − 0.85·pfs + drawn·0.78·pfs + nudge.dy·pfs。
  const pfs = punctFontSize(grid);
  const cellBottom = 2 * grid.cellH;
  const pair = m[0].puncts.slice(2); // DOM 序:token0 两枚在前
  expect(pair.map((p) => p.ch)).toEqual(['。', '」']);
  const base = grid.cellW + grid.gap * 0.06;
  expect(pair[0].x - m[0].left).toBeCloseTo(base - 0.06 * pfs, 1);
  expect(pair[0].y - m[0].top).toBeCloseTo(cellBottom - 0.85 * pfs - 0.1 * pfs, 1);
  expect(pair[1].x - m[0].left).toBeCloseTo(base, 1);
  expect(pair[1].y - m[0].top).toBeCloseTo(cellBottom - 0.85 * pfs + PUNCT_STACK_STEP * pfs, 1);
});

test('CW8 乌丝栏:数量 N−1、位置 0.62·gap、上下沿与文本区齐平、首列不画', async ({ page }) => {
  const r = result0998();
  const grid = r.grid;
  const cols = stripColumns(r).slice(0, 8);
  await page.setContent(stripHtml(cols, grid));
  const m = await measure(page);

  expect(m[0].rules).toHaveLength(0); // 首列(最右)无界线
  const others = m.slice(1);
  expect(others.every((c) => c.rules.length === 1)).toBe(true);
  for (const col of others) {
    const rule = col.rules[0];
    expect(rule.cx).toBeCloseTo(col.left + grid.cellW + grid.gap * RULE_GAP, 2);
    expect(rule.top).toBeCloseTo(col.top, 3);
    expect(rule.h).toBeCloseTo(grid.cellH * grid.charsPerCol, 3);
  }
});

test('golden:0998 首页(题署+品名+散文)', async ({ page }) => {
  const r = result0998();
  const cols = stripColumns(r).slice(0, r.grid.colsPerPage);
  await page.setContent(stripHtml(cols, r.grid));
  await expect(page.locator('#strip')).toHaveScreenshot('0998-page1.png');
});

test('golden:0998 偈颂段(按句折列+句间空格+乌丝栏)', async ({ page }) => {
  const r = result0998();
  const all = stripColumns(r);
  const vi = all.findIndex((c) => c.verseClauseLen !== undefined);
  const cols = all.slice(Math.max(vi - 1, 0), vi + r.grid.colsPerPage - 1);
  await page.setContent(stripHtml(cols, r.grid));
  await expect(page.locator('#strip')).toHaveScreenshot('0998-verse.png');
});
