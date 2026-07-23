/**
 * 竖排算术分页器(web-vertical-reader-plan.md §5.4,验收 CW1/CW4/CW5/CW14;
 * 移植自 flutter-app/lib/core/vertical/vertical_paginator.dart)。
 *
 * 严格网格下布局是纯算术——无文本测量,一遍同步完成(万字级 <10ms)。
 * 结构规则:卷首题署两列 → bt 独占列(顶格)→ bm 独占列(低一格)→
 * 正文散文连排(D5/W17)、偈颂按句折列 → 插图独占条目 → 卷尾 nav 条目。
 *
 * 第一层(列带)与第二层(页分组)与 Flutter 端逐位一致(CW14 指纹对拍);
 * web 增量:pageStarts / spacers(W2 断列补白)/ SnapMetrics(两预设度量)。
 */
import { fitGrid, type VerticalGridSpec } from './gridGeometry';
import { buildTokenStream, tokenizeText } from './tokenStream';
import {
  serializeKey,
  type BookData,
  type GridToken,
  type PaginationKey,
  type StripItem,
  type VColumn,
  type VColumnRole,
  type VPage,
} from './models';

const dev = process.env.NODE_ENV !== 'production';

function devAssert(cond: boolean, msg: string): void {
  if (dev && !cond) throw new Error(`vertical assert: ${msg}`);
}

function clampInt(v: number, lo: number, hi: number): number {
  return Math.min(Math.max(v, lo), hi);
}

// ---- 条目度量(SnapMetrics,吸附/跳转/反馈/页码的唯一度量真源) --------------

export type SnapPreset = 'scroll' | 'paged';

export class SnapMetrics {
  /** prefix[i] = 条目 i 的起始 offset(阅读向,0 = 卷首);长度 = 条目数 + 1。 */
  private readonly prefix: number[];
  /** columnCount[i] = 条目 [0, i) 中 column 类条目的数量。 */
  private readonly columnCount: number[];

  constructor(
    items: readonly StripItem[],
    grid: VerticalGridSpec,
    spacers: ReadonlyMap<number, number>,
    preset: SnapPreset,
  ) {
    const prefix: number[] = [0];
    const columnCount: number[] = [0];
    let offset = 0;
    for (let i = 0; i < items.length; i++) {
      if (preset === 'paged') offset += spacers.get(i) ?? 0;
      prefix[i] = offset;
      offset += items[i].kind === 'column' ? grid.colPitch : grid.contentW;
      prefix[i + 1] = offset;
      columnCount[i + 1] = columnCount[i] + (items[i].kind === 'column' ? 1 : 0);
    }
    if (preset === 'paged') {
      // 卷尾残页补白(键 = items.length)计入总宽。
      prefix[items.length] = offset + (spacers.get(items.length) ?? 0);
    }
    this.prefix = prefix;
    this.columnCount = columnCount;
  }

  get totalWidth(): number {
    return this.prefix[this.prefix.length - 1];
  }

  offsetOfItem(i: number): number {
    return this.prefix[clampInt(i, 0, this.prefix.length - 1)];
  }

  /** offset 所在条目索引(最后一个起点 ≤ offset 的条目)。 */
  itemAtOffset(offset: number): number {
    const n = this.prefix.length - 1;
    if (n <= 0) return 0;
    let lo = 0;
    let hi = n - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (this.prefix[mid] <= offset) lo = mid;
      else hi = mid - 1;
    }
    return lo;
  }

  /**
   * 已完全越过卷首缘的列数(跨列反馈计数用):
   * 纯列书退化为 floor(offset / colPitch),含图书按前缀表折算(B3 跨图只计 1 次
   * 由「只数 column 类条目」天然保证)。
   */
  columnsAdvanced(offset: number): number {
    const n = this.prefix.length - 1;
    if (n <= 0 || offset <= 0) return 0;
    // 最大的 i 使 prefix[i+1] <= offset(条目 i 已完全越过)。
    let lo = -1;
    let hi = n - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (this.prefix[mid + 1] <= offset) lo = mid;
      else hi = mid - 1;
    }
    return lo < 0 ? 0 : this.columnCount[lo + 1];
  }
}

// ---- 分页产物 ----------------------------------------------------------------

export class VerticalPaginationResult {
  constructor(
    readonly key: PaginationKey,
    readonly grid: VerticalGridSpec,
    /** 列带(阅读序:index 0 = 最右/卷首)。排版真源,两预设共享。 */
    readonly strip: readonly StripItem[],
    /** 页(翻页预设消费;与列带零拷贝共享列对象,CW14 对拍口径)。 */
    readonly pages: readonly VPage[],
    /** 翻页预设:页 p 的首条目索引(pages 与 pageStarts 等长)。 */
    readonly pageStarts: readonly number[],
    /** 翻页预设:条目索引 → 其前插补白 px(W2;键 strip.length = 卷尾)。 */
    readonly spacers: ReadonlyMap<number, number>,
    private readonly firstPageOfBlock: readonly number[],
    private readonly firstStripItemOfBlock: readonly number[],
    private readonly stripAnchors: readonly number[],
  ) {
    this.metricsScroll = new SnapMetrics(strip, grid, spacers, 'scroll');
    this.metricsPaged = new SnapMetrics(strip, grid, spacers, 'paged');
  }

  readonly metricsScroll: SnapMetrics;
  readonly metricsPaged: SnapMetrics;

  metricsFor(preset: SnapPreset): SnapMetrics {
    return preset === 'scroll' ? this.metricsScroll : this.metricsPaged;
  }

  pageForBlock(blockIndex: number): number {
    if (this.pages.length === 0 || this.firstPageOfBlock.length === 0) return 0;
    const v = this.firstPageOfBlock[
      clampInt(blockIndex, 0, this.firstPageOfBlock.length - 1)
    ];
    return clampInt(v, 0, this.pages.length - 1);
  }

  blockForPage(page: number): number {
    return this.pages.length === 0
      ? 0
      : this.pages[clampInt(page, 0, this.pages.length - 1)].firstBlockIndex;
  }

  stripItemForBlock(blockIndex: number): number {
    if (this.strip.length === 0 || this.firstStripItemOfBlock.length === 0) return 0;
    const v = this.firstStripItemOfBlock[
      clampInt(blockIndex, 0, this.firstStripItemOfBlock.length - 1)
    ];
    return clampInt(v, 0, this.strip.length - 1);
  }

  blockForStripItem(index: number): number {
    return this.stripAnchors.length === 0
      ? 0
      : this.stripAnchors[clampInt(index, 0, this.stripAnchors.length - 1)];
  }
}

// ---- 结果缓存(LRU 容量 2,镜像 Flutter/横排分页器) --------------------------

const cache = new Map<string, VerticalPaginationResult>();
const CACHE_CAPACITY = 2;

export function cachedResult(key: PaginationKey): VerticalPaginationResult | undefined {
  const k = serializeKey(key);
  const hit = cache.get(k);
  if (hit !== undefined) {
    cache.delete(k);
    cache.set(k, hit);
  }
  return hit;
}

export function clearVerticalCache(): void {
  cache.clear();
}

/** 取缓存或同步分页整卷。 */
export function paginateVertical(opts: {
  key: PaginationKey;
  book: BookData;
  display: (s: string) => string;
}): VerticalPaginationResult {
  const hit = cachedResult(opts.key);
  if (hit !== undefined) return hit;
  const result = paginate(opts.key, opts.book, opts.display);
  const k = serializeKey(opts.key);
  cache.delete(k);
  cache.set(k, result);
  while (cache.size > CACHE_CAPACITY) {
    cache.delete(cache.keys().next().value as string);
  }
  return result;
}

// ---- 分页主体 ----------------------------------------------------------------

function paginate(
  key: PaginationKey,
  book: BookData,
  display: (s: string) => string,
): VerticalPaginationResult {
  const grid = fitGrid({
    contentW: key.contentW,
    contentH: key.contentH,
    fontSize: key.fontSize,
    linePitch: key.linePitch,
    charGapEm: key.charGapEm,
  });

  // ═══ 第一层:列带生成(两预设共享,与 Flutter V1 逐位一致) ═══

  const strip: StripItem[] = [];
  const stripAnchors: number[] = [];
  const blockCount = Math.max(book.blocks.length, 1);
  const firstStripItemOfBlock: (number | null)[] = new Array(blockCount).fill(null);
  let stripLastBlock = 0;

  const addColumn = (column: VColumn): void => {
    // 逐 token 记录块首现条目(散文连排 D5 下块可始于列中段)。
    const context = stripLastBlock;
    let anchor = -1;
    for (const t of column.tokens) {
      const b = t.blockIndex;
      if (b >= 0 && b < blockCount) {
        if (firstStripItemOfBlock[b] === null) firstStripItemOfBlock[b] = strip.length;
        stripLastBlock = b;
        if (anchor < 0) anchor = b;
      }
    }
    strip.push({ kind: 'column', column });
    stripAnchors.push(anchor >= 0 ? anchor : context);
  };

  /**
   * 把一段 token 装成若干列。偈颂(verseN)按句折列:每列只装整数个句子
   * 且句间空一格(D6);句长超出列容量的退化场景回退散文连排。
   */
  const addChunked = (
    tokens: GridToken[],
    role: VColumnRole,
    opts: { indent?: number; verseN?: number } = {},
  ): void => {
    if (tokens.length === 0) return;
    const safeIndent = clampInt(opts.indent ?? 0, 0, grid.charsPerCol - 1);
    const capacity = grid.charsPerCol - safeIndent;
    let perCol = capacity;
    const verseN = opts.verseN;
    const verseFits = verseN !== undefined && verseN <= capacity;
    if (verseFits) {
      // 句间空一格(D6):k 句占 k×n + (k−1) 格 → k = (容量+1) ÷ (n+1)。
      const k = Math.max(1, Math.floor((capacity + 1) / (verseN + 1)));
      perCol = k * verseN;
    }
    devAssert(perCol >= 1, 'perCol 必须 ≥1');
    for (let start = 0; start < tokens.length; start += perCol) {
      const chunk = tokens.slice(start, Math.min(start + perCol, tokens.length));
      addColumn({
        role,
        tokens: chunk,
        indent: safeIndent,
        verseClauseLen: verseFits ? verseN : undefined,
      });
      // A6 不变式:偈颂列内 token 数恒为句长整数倍,且含句间空格后不超列容量。
      devAssert(!verseFits || chunk.length % verseN! === 0, 'A6 偈颂列整除');
      devAssert(
        !verseFits || chunk.length + Math.floor(chunk.length / verseN!) - 1 <= capacity,
        'A6 偈颂列不超容量',
      );
    }
  };

  // ---- 卷首题署:书名列(顶格)+ 作者列(下沉,仿卷端题署) -------------------

  const titleTokens = (raw: string): GridToken[] =>
    tokenizeText(display(raw), {
      blockIndex: -1,
      paragraphIndex: -1,
      baiwen: key.baiwen,
    });

  addChunked(titleTokens(book.meta.title), 'title');
  const author = titleTokens(book.meta.author);
  if (author.length > 0) {
    // 单列放得下 → 底部对齐(indent 下沉);放不下 → 顶格连排。
    const sink = author.length <= grid.charsPerCol ? grid.charsPerCol - author.length : 0;
    addChunked(author, 'author', { indent: sink });
  }

  // ---- 正文流:散文连排缓冲(D5/W17)与偈颂区段缓冲 ---------------------------

  const proseRun: GridToken[] = [];
  const flushProse = (): void => {
    if (proseRun.length === 0) return;
    addChunked([...proseRun], 'body');
    proseRun.length = 0;
  };

  const verseRun: GridToken[] = [];
  let verseRunN: number | undefined;
  const flushVerse = (): void => {
    if (verseRun.length === 0) return;
    addChunked([...verseRun], 'body', { verseN: verseRunN });
    verseRun.length = 0;
    verseRunN = undefined;
  };

  const stream = buildTokenStream({ book, display, baiwen: key.baiwen });
  for (const para of stream) {
    if (para.imageUrl !== undefined) {
      flushProse();
      flushVerse();
      const b = para.blockIndex;
      if (b >= 0 && b < blockCount && firstStripItemOfBlock[b] === null) {
        firstStripItemOfBlock[b] = strip.length;
      }
      strip.push({ kind: 'image', imageUrl: para.imageUrl, blockIndex: b });
      stripAnchors.push(b >= 0 ? b : stripLastBlock);
      if (b >= 0 && b < blockCount) stripLastBlock = b;
      continue;
    }
    switch (para.blockType) {
      case 'bt':
        flushProse();
        flushVerse();
        addChunked(para.tokens, 'bt');
        break;
      case 'bm':
        flushProse();
        flushVerse();
        addChunked(para.tokens, 'bm', { indent: 1 });
        break;
      case 'p':
        if (para.verseClauseLen !== undefined) {
          // 偈颂断列、按句折列;相邻同 n 段并入同一区段。
          flushProse();
          if (verseRunN !== undefined && verseRunN !== para.verseClauseLen) {
            flushVerse();
          }
          verseRunN = para.verseClauseLen;
          verseRun.push(...para.tokens);
        } else {
          flushVerse();
          proseRun.push(...para.tokens);
        }
        break;
    }
  }
  flushProse();
  flushVerse();

  const hasNav =
    (book.meta.lastBuId !== undefined && book.meta.lastBuId.length > 0) ||
    (book.meta.nextBuId !== undefined && book.meta.nextBuId.length > 0);
  if (hasNav) {
    strip.push({ kind: 'nav' });
    stripAnchors.push(stripLastBlock);
  }

  // ═══ 第二层:页分组(翻页预设;分组语义与 Flutter 逐位一致,CW14 锁定)═══
  // web 增量:pageStarts(页首条目索引)与 spacers(断列残页补白,W2)。

  const pages: VPage[] = [];
  const pageStarts: number[] = [];
  const spacers = new Map<number, number>();
  const firstPageOfBlock: (number | null)[] = new Array(blockCount).fill(null);
  const cols: VColumn[] = [];
  let colsStartItem = -1;
  let pageStartBlock = 0;
  let lastBlockPlaced = 0;

  const flushPage = (): void => {
    if (cols.length === 0) return;
    let first = -1;
    for (const c of cols) {
      const b = c.tokens.length === 0 ? -1 : c.tokens[0].blockIndex;
      if (b >= 0) {
        first = b;
        break;
      }
    }
    pages.push({
      columns: [...cols],
      firstBlockIndex: first >= 0 ? first : pageStartBlock,
    });
    pageStarts.push(colsStartItem);
    cols.length = 0;
    colsStartItem = -1;
    pageStartBlock = lastBlockPlaced;
  };

  /** 断列(插图/卷尾/带尾)处收残页:残页列数 r ∈ (0, colsPerPage) 时补白。 */
  const flushPartial = (breakItemIndex: number): void => {
    const r = cols.length;
    flushPage();
    if (r > 0 && r < grid.colsPerPage) {
      spacers.set(breakItemIndex, (grid.colsPerPage - r) * grid.colPitch);
    }
  };

  for (let idx = 0; idx < strip.length; idx++) {
    const item = strip[idx];
    switch (item.kind) {
      case 'column': {
        for (const t of item.column.tokens) {
          const b = t.blockIndex;
          if (b >= 0 && b < blockCount) {
            if (firstPageOfBlock[b] === null) firstPageOfBlock[b] = pages.length;
            lastBlockPlaced = b;
          }
        }
        if (cols.length === 0) colsStartItem = idx;
        cols.push(item.column);
        if (cols.length >= grid.colsPerPage) flushPage();
        break;
      }
      case 'image': {
        flushPartial(idx);
        const b = item.blockIndex;
        if (b >= 0 && b < blockCount) {
          if (firstPageOfBlock[b] === null) firstPageOfBlock[b] = pages.length;
          lastBlockPlaced = b;
        }
        pages.push({
          columns: [],
          firstBlockIndex: b >= 0 ? b : pageStartBlock,
          imageUrl: item.imageUrl,
        });
        pageStarts.push(idx);
        pageStartBlock = lastBlockPlaced;
        break;
      }
      case 'nav': {
        flushPartial(idx);
        pages.push({ columns: [], firstBlockIndex: lastBlockPlaced, isNavPage: true });
        pageStarts.push(idx);
        break;
      }
    }
  }
  flushPartial(strip.length);

  // 空书兜底:至少一页。
  if (pages.length === 0) {
    pages.push({ columns: [], firstBlockIndex: 0 });
    pageStarts.push(0);
  }
  devAssert(pages.length === pageStarts.length, 'pages 与 pageStarts 等长');
  devAssert(stripAnchors.length === strip.length, 'stripAnchors 与 strip 等长');

  // ---- 块 → 页/条目映射前向填充 ---------------------------------------------

  const forwardFill = (src: (number | null)[], maxIndex: number): number[] => {
    const filled = new Array<number>(src.length).fill(0);
    let carry = 0;
    for (let b = 0; b < src.length; b++) {
      const v = src[b];
      if (v !== null) carry = Math.min(v, maxIndex);
      filled[b] = carry;
    }
    return filled;
  };

  return new VerticalPaginationResult(
    key,
    grid,
    strip,
    pages,
    pageStarts,
    spacers,
    forwardFill(firstPageOfBlock, pages.length - 1),
    forwardFill(firstStripItemOfBlock, Math.max(strip.length - 1, 0)),
    stripAnchors,
  );
}
