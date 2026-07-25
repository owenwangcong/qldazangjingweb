/**
 * CW14 跨端对拍:真书翻页产物指纹必须与 Flutter 端**逐位一致**。
 *
 * 基线取自 flutter-app/test/vertical_strip_refactor_test.dart(2026-07-20,
 * 硬编码于 Flutter 测试并全绿),digest 算法逐行移植;两端输入 JSON 已验证
 * 逐字节相同(public/data/books ≡ flutter-app/assets/books 解压)。
 * 参数:640×1257 / fs20 / lp1.75 / cg0 / display 恒等 / 句读模式。
 */
import { readFileSync } from 'fs';
import { join } from 'path';
import { expect, test } from '@playwright/test';
import { parseBookData } from '../models';
import { buildTokenStream } from '../tokenStream';
import { clearVerticalCache, paginateVertical } from '../paginator';

test.beforeEach(() => clearVerticalCache());

const loadBook = (bookId: string) =>
  parseBookData(
    JSON.parse(
      readFileSync(join(process.cwd(), 'public', 'data', 'books', `${bookId}.json`), 'utf8'),
    ),
  );

function digest(bookId: string) {
  const book = loadBook(bookId);
  const result = paginateVertical({
    key: {
      bookId: `digest-${bookId}`,
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
  let cols = 0;
  let colHash = 17;
  let anchorHash = 17;
  for (const p of result.pages) {
    cols += p.columns.length;
    colHash = (colHash * 31 + p.columns.length) & 0x3fffffff;
    anchorHash = (anchorHash * 31 + p.firstBlockIndex) & 0x3fffffff;
    for (const c of p.columns) {
      colHash = (colHash * 7 + c.tokens.length + c.indent * 131) & 0x3fffffff;
    }
  }
  const samples: number[] = [];
  for (let b = 0; b < book.blocks.length; b += 7) {
    samples.push(result.pageForBlock(b));
  }
  return { pages: result.pages.length, cols, colHash, anchorHash, samples };
}

test('0085-01(普贤行愿品)指纹与 Flutter 基线逐位一致', () => {
  const d = digest('0085-01');
  expect(d.pages).toBe(63);
  expect(d.cols).toBe(1099);
  expect(d.colHash).toBe(747057561);
  expect(d.anchorHash).toBe(957985439);
  expect(d.samples).toEqual([0, 11, 24, 43, 54]);
});

test('0998(地藏经)指纹与 Flutter 基线逐位一致', () => {
  const d = digest('0998');
  expect(d.pages).toBe(18);
  expect(d.cols).toBe(303);
  expect(d.colHash).toBe(297985313);
  expect(d.anchorHash).toBe(622377286);
  expect(d.samples).toEqual([0, 3, 6, 9, 12, 15]);
});

test('0998 按联编码偈颂区段归并(漏检修复回归,对齐 Flutter 实测 40 段)', () => {
  const paras = buildTokenStream({ book: loadBook('0998'), display: (s) => s, baiwen: false });
  const target = paras.filter(
    (p) =>
      p.tokens.length > 0 &&
      p.tokens.map((t) => t.char).join('').startsWith('吾观地藏威神力'),
  );
  expect(target.length).toBeGreaterThan(0);
  expect(target[0].verseClauseLen).toBe(7);
  const verseParas = paras.filter((p) => p.verseClauseLen !== undefined).length;
  expect(verseParas).toBe(40);
});

test('0998 白文流:零标点残留且独立分页(键含 baiwen)', () => {
  const book = loadBook('0998');
  const punctRegex = /[\p{P}\p{S}]/u;
  const paras = buildTokenStream({ book, display: (s) => s, baiwen: true });
  for (const p of paras) {
    expect(p.tokens.every((t) => t.trailingPunct === '' && !punctRegex.test(t.char))).toBe(true);
  }
});
