/**
 * CW11 响应式 E2E(WS4):viewport 缩放/旋转 → 防抖重排 + 锚定还原;
 * 三断点几何自适应;超宽被「页面宽度」设置封顶(§8.1)。
 */
import { expect, test, type Page } from '@playwright/test';

test.use({ channel: 'chrome' });
test.setTimeout(60_000);

async function openReader(page: Page, mode: 'verticalPaged' | 'verticalScroll') {
  await page.goto(`/dev/vertical?book=0998&mode=${mode}`);
  await page.waitForSelector('[data-vstrip]');
}

const attr = async (page: Page, name: string) =>
  Number(await page.locator('[data-vreader]').getAttribute(name));

const offset = (page: Page) =>
  page.evaluate(() => {
    const el = document.querySelector('[data-vscroller]') as HTMLElement;
    return -el.scrollLeft;
  });

async function settledOffset(page: Page): Promise<number> {
  // 连续两次稳定采样(跨度 >360ms):覆盖 W18 的 160ms 停驻吸附窗口,
  // 避免在吸附动画启动前误判"已停稳"。
  let prev = await offset(page);
  let stableCount = 0;
  await expect
    .poll(
      async () => {
        const cur = await offset(page);
        stableCount = Math.abs(cur - prev) < 0.5 ? stableCount + 1 : 0;
        prev = cur;
        return stableCount >= 2;
      },
      { timeout: 8000, intervals: [180] },
    )
    .toBe(true);
  return prev;
}

test('重排锚定:viewport 缩放触发防抖重排,阅读块还原不漂移', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await openReader(page, 'verticalPaged');
  const colsBefore = await attr(page, 'data-colsperpage');

  for (let i = 0; i < 3; i++) await page.keyboard.press('PageDown');
  await settledOffset(page);
  const blockBefore = await attr(page, 'data-block');
  expect(blockBefore).toBeGreaterThan(0);

  await page.setViewportSize({ width: 800, height: 1000 });
  await expect
    .poll(() => attr(page, 'data-colsperpage'), { timeout: 5000 })
    .not.toBe(colsBefore);
  await settledOffset(page);

  const blockAfter = await attr(page, 'data-block');
  // 还原按块首现页对齐:页首块 ≤ 锚块,粒度差不超过数块(R6 口径)。
  expect(blockAfter).toBeLessThanOrEqual(blockBefore);
  expect(blockBefore - blockAfter).toBeLessThanOrEqual(3);
});

test('三断点:列数随宽度自适应递增,初始皆于卷首吸附位', async ({ page }) => {
  const cols: number[] = [];
  for (const vp of [
    { width: 375, height: 667 },
    { width: 768, height: 1024 },
    { width: 1280, height: 800 },
  ]) {
    await page.setViewportSize(vp);
    await openReader(page, 'verticalScroll');
    expect(Math.abs(await offset(page))).toBeLessThanOrEqual(1);
    const c = await attr(page, 'data-colsperpage');
    expect(c).toBeGreaterThanOrEqual(1);
    cols.push(c);
  }
  expect(cols[0]).toBeLessThan(cols[1]);
  expect(cols[1]).toBeLessThan(cols[2]);
});

test('超宽封顶:2000px 视口被「页面宽度」默认档(max-w-4xl=896)封顶,页窗居中', async ({ page }) => {
  await page.setViewportSize({ width: 2000, height: 900 });
  await openReader(page, 'verticalPaged');
  // fs26/lp1.75:contentW = 896−32 = 864 → colsPerPage = ⌊(864+19.5)/45.5⌋ = 19。
  expect(await attr(page, 'data-colsperpage')).toBe(19);
  // 页窗收窄(07-24):滚动容器 = 封顶宽居中,邻页列被容器裁剪(翻半页修复)。
  const rect = await page.evaluate(() => {
    const r = document.querySelector('[data-vscroller]')!.getBoundingClientRect();
    return { w: r.width, left: r.left };
  });
  expect(rect.w).toBeCloseTo(896, 0);
  expect(rect.left).toBeCloseTo((2000 - 896) / 2, 0);
});

test('旋转(宽高互换):重排后展卷静止仍在列边界', async ({ page }) => {
  await page.setViewportSize({ width: 800, height: 1100 });
  await openReader(page, 'verticalScroll');
  const pitchBefore = await attr(page, 'data-colpitch');
  await page.keyboard.press('ArrowLeft');
  await page.keyboard.press('ArrowLeft');
  await settledOffset(page);
  const blockBefore = await attr(page, 'data-block');

  await page.setViewportSize({ width: 1100, height: 800 });
  await expect
    .poll(async () => (await attr(page, 'data-pages')) > 0 && (await offset(page)) >= 0, {
      timeout: 5000,
    })
    .toBe(true);
  await page.waitForTimeout(400); // 防抖 250ms + 还原
  const off = await settledOffset(page);
  const pitch = await attr(page, 'data-colpitch');
  expect(pitch).toBe(pitchBefore); // 字号未变,列距不变
  const mod = Math.abs(off / pitch - Math.round(off / pitch)) * pitch;
  expect(mod).toBeLessThanOrEqual(1.5); // 静止必对齐列边界
  expect(await attr(page, 'data-block')).toBeLessThanOrEqual(blockBefore);
});
