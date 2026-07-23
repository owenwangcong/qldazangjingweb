/**
 * CW4 分页完整性(token 守恒 property)+ CW5 进度锚定 +
 * web 增量(pageStarts/spacers/SnapMetrics/LRU)。
 */
import { expect, test } from '@playwright/test';
import { buildTokenStream } from '../tokenStream';
import {
  clearVerticalCache,
  cachedResult,
  paginateVertical,
  type VerticalPaginationResult,
} from '../paginator';
import type { BookData, PaginationKey } from '../models';

test.beforeEach(() => clearVerticalCache());

/** 小网格:fs10/lp1.75 → colPitch 17.5、gap 7.5;H100 → 10 格/列;W45 → 3 列/页。 */
const smallKey = (bookId: string, over: Partial<PaginationKey> = {}): PaginationKey => ({
  bookId,
  contentW: 45,
  contentH: 100,
  fontFamily: '',
  fontSize: 10,
  linePitch: 1.75,
  charGapEm: 0,
  isSimplified: false,
  baiwen: false,
  ...over,
});

const bookOf = (
  blocks: BookData['blocks'],
  meta: Partial<BookData['meta']> = {},
): BookData => ({
  meta: { id: 't', bu: '', title: '测试经', author: '某某译', ...meta },
  blocks,
});

const proseBook = bookOf([
  { id: 'j1', type: 'bt', paragraphs: ['测试经卷上'] },
  { id: 'b1', type: 'bm', paragraphs: ['序品第一'] },
  {
    id: 'p0',
    type: 'p',
    paragraphs: [
      '如是我闻:一时,佛在舍卫国祇树给孤独园,与大比丘众千二百五十人俱。',
      '尔时世尊食时,着衣持钵,入舍卫大城乞食。',
    ],
  },
  { id: 'p1', type: 'p', paragraphs: ['于其城中次第乞已,还至本处。'] },
]);

const verseBook = bookOf([
  {
    id: 'p0',
    type: 'p',
    paragraphs: [
      '一切有为法,如梦幻泡影,如露亦如电,应作如是观。',
      '此后散文对照段落,连排验证之用也。',
    ],
  },
]);

const imageBook = bookOf(
  [
    { id: 'p0', type: 'p', paragraphs: ['前段文字甚长,足以铺陈若干列而不止一页之数也。'] },
    { id: 'p1', type: 'p', paragraphs: ['中有插图<img src="/images/fo.png">图后继文。'] },
  ],
  { nextBuId: '0999' },
);

const stripChars = (r: VerticalPaginationResult): string =>
  r.strip
    .flatMap((it) => (it.kind === 'column' ? it.column.tokens : []))
    .map((t) => t.char)
    .join('');

const streamChars = (book: BookData, baiwen = false): string =>
  buildTokenStream({ book, display: (s) => s, baiwen })
    .flatMap((p) => p.tokens)
    .map((t) => t.char)
    .join('');

test('CW4 token 守恒:列带 tokens == 题署 + 字符流(无丢字无重字)', () => {
  for (const [i, book] of [proseBook, verseBook, imageBook].entries()) {
    const r = paginateVertical({ key: smallKey(`c4-${i}`), book, display: (s) => s });
    const title = [...book.meta.title].join('') + [...book.meta.author].join('');
    expect(stripChars(r)).toBe(title.replace(/\s/gu, '') + streamChars(book));
  }
});

test('CW4 边界:空书/单字书产出兜底页,不崩溃', () => {
  const empty = paginateVertical({
    key: smallKey('c4-empty'),
    book: bookOf([], { title: '', author: '' }),
    display: (s) => s,
  });
  expect(empty.pages).toHaveLength(1);
  expect(empty.strip).toHaveLength(0);
  expect(empty.pageForBlock(0)).toBe(0);
  expect(empty.metricsScroll.totalWidth).toBe(0);

  const single = paginateVertical({
    key: smallKey('c4-single'),
    book: bookOf([{ id: 'p0', type: 'p', paragraphs: ['佛'] }], { title: '', author: '' }),
    display: (s) => s,
  });
  expect(stripChars(single)).toBe('佛');
});

test('结构规则:题署两列(作者下沉)→ bt 顶格 → bm 低一格 → 散文连排(W17)', () => {
  const r = paginateVertical({ key: smallKey('struct'), book: proseBook, display: (s) => s });
  const cols = r.strip.flatMap((it) => (it.kind === 'column' ? [it.column] : []));
  expect(cols[0].role).toBe('title');
  expect(cols[0].indent).toBe(0);
  expect(cols[1].role).toBe('author');
  expect(cols[1].indent).toBe(10 - 3); // 某某译 3 字,下沉至列底。
  expect(cols[2].role).toBe('bt');
  expect(cols[3].role).toBe('bm');
  expect(cols[3].indent).toBe(1);
  // 散文连排:p0 两段 + p1 合并为连续 body 列;跨段处不断列 →
  // body 列中存在同列跨 blockIndex/paragraphIndex 的列。
  const bodyCols = cols.filter((c) => c.role === 'body');
  const crossed = bodyCols.some(
    (c) => new Set(c.tokens.map((t) => `${t.blockIndex}/${t.paragraphIndex}`)).size > 1,
  );
  expect(crossed).toBe(true);
});

test('偈颂按句折列 + 句间空一格:容量10/n5 → 每列 1 句(k=(10+1)÷6=1)', () => {
  const r = paginateVertical({ key: smallKey('verse'), book: verseBook, display: (s) => s });
  const verseCols = r.strip.flatMap((it) =>
    it.kind === 'column' && it.column.verseClauseLen !== undefined ? [it.column] : [],
  );
  expect(verseCols).toHaveLength(4);
  for (const c of verseCols) {
    expect(c.verseClauseLen).toBe(5);
    expect(c.tokens.length % 5).toBe(0);
  }
});

test('CW5 锚定:pageForBlock/stripItemForBlock 单调不减,往返一致', () => {
  const r = paginateVertical({ key: smallKey('anchor'), book: proseBook, display: (s) => s });
  let prevPage = 0;
  let prevItem = 0;
  for (let b = 0; b < proseBook.blocks.length; b++) {
    const page = r.pageForBlock(b);
    const item = r.stripItemForBlock(b);
    expect(page).toBeGreaterThanOrEqual(prevPage);
    expect(item).toBeGreaterThanOrEqual(prevItem);
    // 往返:块 b 首现页的锚块 ≤ b;条目锚同理。
    expect(r.blockForPage(page)).toBeLessThanOrEqual(b);
    expect(r.blockForStripItem(item)).toBeLessThanOrEqual(b);
    prevPage = page;
    prevItem = item;
  }
  // 越界钳制不崩溃。
  expect(r.pageForBlock(-5)).toBe(r.pageForBlock(0));
  expect(r.pageForBlock(999)).toBeLessThanOrEqual(r.pages.length - 1);
});

test('插图与卷尾:独立条目/独占页;nav 依 meta 存在', () => {
  const r = paginateVertical({ key: smallKey('img'), book: imageBook, display: (s) => s });
  const kinds = r.strip.map((it) => it.kind);
  expect(kinds).toContain('image');
  expect(kinds[kinds.length - 1]).toBe('nav');
  const imgPage = r.pages.find((p) => p.imageUrl !== undefined);
  expect(imgPage?.columns).toHaveLength(0);
  expect(r.pages[r.pages.length - 1].isNavPage).toBe(true);

  const noNav = paginateVertical({ key: smallKey('nonav'), book: proseBook, display: (s) => s });
  expect(noNav.strip.every((it) => it.kind !== 'nav')).toBe(true);
});

test('W2 断列补白:翻页度量下每页跨度 ∈ {整页列宽, 视口宽}', () => {
  const r = paginateVertical({ key: smallKey('spacer'), book: imageBook, display: (s) => s });
  const pageSpan = r.grid.colsPerPage * r.grid.colPitch; // 3 × 17.5 = 52.5
  const m = r.metricsPaged;
  const starts = r.pageStarts.map((i) => m.offsetOfItem(i));
  const spans: number[] = [];
  for (let p = 0; p < starts.length; p++) {
    const end = p + 1 < starts.length ? starts[p + 1] : m.totalWidth;
    spans.push(end - starts[p]);
  }
  for (const [p, span] of spans.entries()) {
    const isFullItem = r.pages[p].imageUrl !== undefined || r.pages[p].isNavPage === true;
    expect(span).toBeCloseTo(isFullItem ? r.grid.contentW : pageSpan, 6);
  }
  // 补白值恒为 (colsPerPage − r) × colPitch 的正倍数格。
  for (const px of r.spacers.values()) {
    expect(px).toBeGreaterThan(0);
    expect((px / r.grid.colPitch) % 1).toBeCloseTo(0, 9);
    expect(px / r.grid.colPitch).toBeLessThan(r.grid.colsPerPage);
  }
});

test('SnapMetrics:offset/itemAt 往返、columnsAdvanced 纯列退化为取模', () => {
  const r = paginateVertical({ key: smallKey('metrics'), book: proseBook, display: (s) => s });
  const m = r.metricsScroll;
  for (let i = 0; i < r.strip.length; i++) {
    expect(m.itemAtOffset(m.offsetOfItem(i))).toBe(i);
    expect(m.offsetOfItem(i)).toBeCloseTo(i * r.grid.colPitch, 6); // 纯列书
  }
  expect(m.columnsAdvanced(0)).toBe(0);
  expect(m.columnsAdvanced(r.grid.colPitch - 0.01)).toBe(0);
  expect(m.columnsAdvanced(r.grid.colPitch)).toBe(1);
  expect(m.columnsAdvanced(r.grid.colPitch * 4.5)).toBe(4);
  expect(m.columnsAdvanced(m.totalWidth)).toBe(r.strip.length);
});

test('LRU 缓存:同键复用同一结果对象,容量 2 逐出最旧', () => {
  const k1 = smallKey('lru-1');
  const r1 = paginateVertical({ key: k1, book: proseBook, display: (s) => s });
  const r1again = paginateVertical({ key: k1, book: proseBook, display: (s) => s });
  expect(r1again).toBe(r1);

  paginateVertical({ key: smallKey('lru-2'), book: proseBook, display: (s) => s });
  expect(cachedResult(k1)).toBe(r1); // 命中刷新热度。
  paginateVertical({ key: smallKey('lru-3'), book: proseBook, display: (s) => s });
  // 此刻缓存 = {lru-1(刚刷新), lru-3},lru-2 被逐出。
  expect(cachedResult(smallKey('lru-2'))).toBeUndefined();
  expect(cachedResult(k1)).toBe(r1);
});

test('页与列带零拷贝共享列对象(派生一致性)', () => {
  const r = paginateVertical({ key: smallKey('derive'), book: proseBook, display: (s) => s });
  const fromPages = r.pages.flatMap((p) => p.columns);
  const fromStrip = r.strip.flatMap((it) => (it.kind === 'column' ? [it.column] : []));
  expect(fromPages).toHaveLength(fromStrip.length);
  for (let i = 0; i < fromPages.length; i++) {
    expect(fromPages[i]).toBe(fromStrip[i]);
  }
});
