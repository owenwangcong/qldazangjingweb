/**
 * CW12(引擎侧):算术分页性能护栏——纯算术单遍,真书冷分页必须远离
 * 交互预算(Flutter 端 debug 63ms/release <15ms 参照;Node 无 JIT 预热
 * 劣势,护栏放 120ms,实测预期 <30ms)。
 */
import { readFileSync } from 'fs';
import { join } from 'path';
import { expect, test } from '@playwright/test';
import { parseBookData } from '../models';
import { clearVerticalCache, paginateVertical } from '../paginator';

const load = (id: string) =>
  parseBookData(
    JSON.parse(readFileSync(join(process.cwd(), 'public', 'data', 'books', `${id}.json`), 'utf8')),
  );

for (const bookId of ['0998', '0085-01']) {
  test(`冷分页护栏:${bookId}`, () => {
    const book = load(bookId);
    clearVerticalCache();
    const t0 = performance.now();
    const result = paginateVertical({
      key: {
        bookId: `perf-${bookId}`,
        contentW: 864,
        contentH: 1200,
        fontFamily: '',
        fontSize: 26,
        linePitch: 1.75,
        charGapEm: 0,
        isSimplified: true,
        baiwen: false,
      },
      book,
      display: (s) => s,
    });
    const cold = performance.now() - t0;

    const t1 = performance.now();
    paginateVertical({
      key: {
        bookId: `perf-${bookId}`,
        contentW: 864,
        contentH: 1200,
        fontFamily: '',
        fontSize: 26,
        linePitch: 1.75,
        charGapEm: 0,
        isSimplified: true,
        baiwen: false,
      },
      book,
      display: (s) => s,
    });
    const warm = performance.now() - t1;

    // eslint-disable-next-line no-console
    console.log(
      `[perf ${bookId}] cold=${cold.toFixed(1)}ms warm=${warm.toFixed(3)}ms ` +
        `items=${result.strip.length} pages=${result.pages.length}`,
    );
    expect(cold).toBeLessThan(120);
    expect(warm).toBeLessThan(2); // LRU 命中零成本
  });
}
