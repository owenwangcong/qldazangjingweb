/**
 * CW9 交互 E2E(WS3):rtl 方向/点按分区/吸附落点/键盘/滚轮/模式互切/退出交接。
 * 驱动 /dev/vertical 开发路由(主 playwright.config 自动起 dev server)。
 */
import { expect, test, type Page } from '@playwright/test';

test.use({ channel: 'chrome', viewport: { width: 1280, height: 800 } });
test.setTimeout(60_000);

interface ReaderInfo {
  colPitch: number;
  colsPerPage: number;
  padTotal: number;
  pages: number;
}

async function openReader(page: Page, mode: 'verticalPaged' | 'verticalScroll'): Promise<ReaderInfo> {
  await page.goto(`/dev/vertical?book=0998&mode=${mode}`);
  await page.waitForSelector('[data-vstrip]');
  const reader = page.locator('[data-vreader]');
  return {
    colPitch: Number(await reader.getAttribute('data-colpitch')),
    colsPerPage: Number(await reader.getAttribute('data-colsperpage')),
    padTotal: Number(await reader.getAttribute('data-padtotal')),
    pages: Number(await reader.getAttribute('data-pages')),
  };
}

const offset = (page: Page) =>
  page.evaluate(() => {
    const el = document.querySelector('[data-vscroller]') as HTMLElement;
    return -el.scrollLeft;
  });

/** 等待平滑滚动停稳后返回稳定 offset。 */
async function settledOffset(page: Page): Promise<number> {
  let prev = await offset(page);
  await expect
    .poll(
      async () => {
        const cur = await offset(page);
        const stable = Math.abs(cur - prev) < 0.5;
        prev = cur;
        return stable;
      },
      { timeout: 8000, intervals: [120] },
    )
    .toBe(true);
  return prev;
}

test('WB1 rtl 初始:offset=0,卷首(书名列)贴右缘于 padTotal 内缩处', async ({ page }) => {
  const info = await openReader(page, 'verticalPaged');
  expect(info.pages).toBeGreaterThan(3);
  expect(Math.abs(await offset(page))).toBeLessThanOrEqual(1); // abs 兼防 rtl 的 -0

  const firstCol = page.locator('[data-vcol]').first();
  const box = (await firstCol.boundingBox())!;
  // 滚动位置/盒尺寸按整数像素量化,容差 1.5px。
  expect(Math.abs(box.x + box.width - (1280 - info.padTotal))).toBeLessThanOrEqual(1.5);
  // 首列是书名列。
  await expect(firstCol).toHaveAttribute('data-vcol', 'title');
});

test('翻页:左区前进/右区后退,落点恒等于整页跨度,页码联动', async ({ page }) => {
  const info = await openReader(page, 'verticalPaged');
  const pageSpan = info.colsPerPage * info.colPitch;

  await page.mouse.click(1280 * 0.1, 400); // 左 25% = 前进
  await expect(page.locator('[data-vreader]')).toHaveAttribute('data-page', '1');
  expect(Math.abs((await settledOffset(page)) - pageSpan)).toBeLessThanOrEqual(1.5);

  await page.mouse.click(1280 * 0.1, 400);
  await expect(page.locator('[data-vreader]')).toHaveAttribute('data-page', '2');
  expect(Math.abs((await settledOffset(page)) - 2 * pageSpan)).toBeLessThanOrEqual(1.5);

  await page.mouse.click(1280 * 0.9, 400); // 右 25% = 后退
  await expect(page.locator('[data-vreader]')).toHaveAttribute('data-page', '1');
  expect(Math.abs((await settledOffset(page)) - pageSpan)).toBeLessThanOrEqual(1.5);
});

test('翻页:中部点按切换 chrome 显隐(DS3 镜像)', async ({ page }) => {
  await openReader(page, 'verticalPaged');
  await expect(page.locator('[data-vchrome]')).toHaveAttribute('data-vchrome', 'visible');
  await page.mouse.click(640, 400); // 中部
  await expect(page.locator('[data-vchrome]')).toHaveAttribute('data-vchrome', 'hidden');
  await page.mouse.click(640, 400);
  await expect(page.locator('[data-vchrome]')).toHaveAttribute('data-vchrome', 'visible');
});

test('展卷:滚轮向下=前进,静止必落列边缘;任意处点按切 chrome', async ({ page }) => {
  const info = await openReader(page, 'verticalScroll');
  await page.mouse.move(640, 400);
  await page.mouse.wheel(0, 420);
  const off = await settledOffset(page);
  expect(off).toBeGreaterThan(0);
  // 静止对齐:offset ∈ 列边界(卷首区域纯列,边界 = k×colPitch)。
  expect(Math.abs(off / info.colPitch - Math.round(off / info.colPitch))).toBeLessThan(0.02);

  await page.mouse.click(1280 * 0.1, 400); // 展卷无翻页分区:任意处 = chrome
  await expect(page.locator('[data-vchrome]')).toHaveAttribute('data-vchrome', 'hidden');
});

test('展卷:方向键左=前进一列,右=后退一列(视觉语义)', async ({ page }) => {
  const info = await openReader(page, 'verticalScroll');
  await page.keyboard.press('ArrowLeft');
  expect(Math.abs((await settledOffset(page)) - info.colPitch)).toBeLessThanOrEqual(1.5);
  await page.keyboard.press('ArrowLeft');
  expect(Math.abs((await settledOffset(page)) - 2 * info.colPitch)).toBeLessThanOrEqual(1.5);
  await page.keyboard.press('ArrowRight');
  expect(Math.abs((await settledOffset(page)) - info.colPitch)).toBeLessThanOrEqual(1.5);
});

test('模式互切:进度锚往返不漂移(翻页→展卷→翻页回到同页)', async ({ page }) => {
  await openReader(page, 'verticalPaged');
  await page.keyboard.press('PageDown');
  await page.keyboard.press('PageDown');
  await expect(page.locator('[data-vreader]')).toHaveAttribute('data-page', '2');
  await settledOffset(page);

  await page.locator('[data-mode-scroll]').click();
  await expect(page.locator('[data-vreader]')).toHaveAttribute('data-mode', 'verticalScroll');
  await settledOffset(page);

  await page.locator('[data-mode-paged]').click();
  await expect(page.locator('[data-vreader]')).toHaveAttribute('data-mode', 'verticalPaged');
  await expect(page.locator('[data-vreader]')).toHaveAttribute('data-page', '2');
});

test('Esc 退出:交回锚定块;翻页若干页后退出锚点前进', async ({ page }) => {
  await openReader(page, 'verticalPaged');
  await page.keyboard.press('Escape');
  const first = Number(await page.locator('[data-exited]').getAttribute('data-exited'));
  expect(first).toBeGreaterThanOrEqual(0);

  await page.locator('[data-reopen]').click();
  await page.waitForSelector('[data-vstrip]');
  for (let i = 0; i < 4; i++) await page.keyboard.press('PageDown');
  await settledOffset(page);
  await page.keyboard.press('Escape');
  const later = Number(await page.locator('[data-exited]').getAttribute('data-exited'));
  expect(later).toBeGreaterThan(first);
});

test('卷尾:End 直达,nav 条目呈现上一部/下一部跳转(W15)', async ({ page }) => {
  await openReader(page, 'verticalScroll');
  await page.keyboard.press('End');
  await settledOffset(page);
  await expect(page.locator('[data-vnav]')).toBeVisible();
  await expect(page.locator('[data-vnav] a', { hasText: '下一部' })).toBeVisible();
  await expect(page.locator('[data-vnav] a', { hasText: '上一部' })).toBeVisible();
});
