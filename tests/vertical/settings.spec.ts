/**
 * WS5 E2E:书页入口与横竖交接(W12/§5.2)、设置联动(CW10)、
 * 持久化(§9)、SSR 不回归(CW13/W9)。
 */
import { readFileSync } from 'fs';
import { join } from 'path';
import { expect, test, type Page } from '@playwright/test';

test.use({ channel: 'chrome', viewport: { width: 1280, height: 800 } });
test.setTimeout(60_000);

const juans: { id: string }[] = JSON.parse(
  readFileSync(join(process.cwd(), 'public', 'data', 'books', '0998.json'), 'utf8'),
).juans;

const attr = async (page: Page, name: string) =>
  Number(await page.locator('[data-vreader]').getAttribute(name));

/** 确保 chrome 可见(点按切换与 3s 自动隐藏存在竞态,读态重试)。 */
async function openChrome(page: Page) {
  const chrome = page.locator('[data-vchrome]');
  for (let i = 0; i < 4; i++) {
    if ((await chrome.getAttribute('data-vchrome')) === 'visible') return;
    await page.mouse.click(640, 400);
    try {
      await expect(chrome).toHaveAttribute('data-vchrome', 'visible', { timeout: 800 });
      return;
    } catch {
      /* 点击恰逢 visible→被切隐,重试 */
    }
  }
  await expect(chrome).toHaveAttribute('data-vchrome', 'visible');
}

test('入口与交接:横排可见位置→竖排锚定;退出→横排滚回块锚(§5.2)', async ({ page }) => {
  await page.goto('/books/0998');
  await page.waitForSelector('[data-ventry]');
  // 横排滚到第 10 块(juan 元素锚)。
  await page.evaluate((id) => document.getElementById(id)?.scrollIntoView(), juans[10].id);
  await page.waitForTimeout(200);

  await page.locator('[data-ventry]').click();
  await page.waitForSelector('[data-vstrip]');
  const enterBlock = await attr(page, 'data-block');
  expect(Math.abs(enterBlock - 10)).toBeLessThanOrEqual(1); // 横→竖锚定

  await page.keyboard.press('PageDown');
  await page.keyboard.press('PageDown');
  await page.waitForTimeout(400);
  const exitBlock = await attr(page, 'data-block');
  await page.keyboard.press('Escape');
  await page.waitForSelector('[data-ventry]'); // overlay 已卸载,入口回归

  // 竖→横交接:退出块的锚元素应在视口顶部附近。
  const top = await page.evaluate(
    (id) => document.getElementById(id)?.getBoundingClientRect().top ?? 9999,
    juans[exitBlock].id,
  );
  expect(top).toBeGreaterThan(-100);
  expect(top).toBeLessThan(300);
});

test('CW10 设置联动:字号→重排;白文→重排;乌丝栏→仅重绘', async ({ page }) => {
  await page.goto('/dev/vertical?book=0998&mode=verticalPaged');
  await page.waitForSelector('[data-vstrip]');
  await openChrome(page);
  await page.locator('[data-vgear]').click();
  await page.waitForSelector('[data-vsettings]');

  // 字号 26→32:colPitch = 32 × 1.75 = 56(进键重排)。
  await page.locator('[data-set-fontsize]').fill('32');
  await expect.poll(() => attr(page, 'data-colpitch'), { timeout: 5000 }).toBe(56);

  // 白文:剥标点流变短 → 页数变化(进键重排)。
  const pagesBefore = await attr(page, 'data-pages');
  await page.locator('[data-set-baiwen]').click();
  await expect.poll(() => attr(page, 'data-pages'), { timeout: 5000 }).not.toBe(pagesBefore);

  // 乌丝栏:关→ rule 消失,页数/列数不变(零重排,CW8/CW10)。
  const pages = await attr(page, 'data-pages');
  const cols = await attr(page, 'data-colsperpage');
  await page.locator('[data-set-rules]').click();
  await expect.poll(() => page.locator('.v-rule').count(), { timeout: 3000 }).toBe(0);
  expect(await attr(page, 'data-pages')).toBe(pages);
  expect(await attr(page, 'data-colsperpage')).toBe(cols);

  // 版面宽度(W20):50%→100%,页窗铺满视口、列数增加(进键重排)。
  await page.locator('[data-set-widthpct]').fill('100');
  await expect.poll(() => attr(page, 'data-colsperpage'), { timeout: 5000 }).toBeGreaterThan(cols);
  const w = await page.evaluate(
    () => document.querySelector('[data-vscroller]')!.getBoundingClientRect().width,
  );
  expect(w).toBeCloseTo(1280, 0);
});

test('持久化:字号跨加载保留;竖排模式记忆(§9)', async ({ page }) => {
  await page.goto('/dev/vertical?book=0998&mode=verticalPaged');
  await page.waitForSelector('[data-vstrip]');
  await openChrome(page);
  await page.locator('[data-vgear]').click();
  await page.locator('[data-set-fontsize]').fill('32');
  await expect.poll(() => attr(page, 'data-colpitch')).toBe(56);

  await page.reload();
  await page.waitForSelector('[data-vstrip]');
  expect(await attr(page, 'data-colpitch')).toBe(56); // localStorage 还原

  // 模式记忆:书页入口 → 切展卷 → 退出 → 再入口应为展卷。
  await page.goto('/books/0998');
  await page.waitForSelector('[data-ventry]');
  await page.locator('[data-ventry]').click();
  await page.waitForSelector('[data-vstrip]');
  await openChrome(page);
  await page.locator('[data-mode-scroll]').click();
  await expect(page.locator('[data-vreader]')).toHaveAttribute('data-mode', 'verticalScroll');
  await page.keyboard.press('Escape');
  await page.waitForSelector('[data-ventry]');
  await page.locator('[data-ventry]').click();
  await page.waitForSelector('[data-vstrip]');
  await expect(page.locator('[data-vreader]')).toHaveAttribute('data-mode', 'verticalScroll');
});

test('W19 刷新保持竖排:reload 后自动恢复模式与进度;退出后刷新回横排', async ({ page }) => {
  await page.goto('/books/0998');
  await page.waitForSelector('[data-ventry]');
  await page.locator('[data-ventry]').click();
  await page.waitForSelector('[data-vstrip]');
  await page.keyboard.press('PageDown');
  await page.keyboard.press('PageDown');
  await page.waitForTimeout(500); // 停驻落进度

  await page.reload();
  await page.waitForSelector('[data-vstrip]'); // 刷新自动恢复竖排
  await expect(page.locator('[data-vreader]')).toHaveAttribute('data-mode', 'verticalPaged');
  expect(await attr(page, 'data-block')).toBeGreaterThan(0); // 进度还原

  await page.keyboard.press('Escape'); // 退出 → 写回横排
  await page.waitForSelector('[data-ventry]');
  await page.reload();
  await page.waitForSelector('[data-ventry]');
  await expect(page.locator('[data-vreader]')).toHaveCount(0); // 不再自动进竖排
});

test('CW13 SSR 不回归:书页服务端输出不含竖排 overlay/入口,元数据完整(W9)', async ({ page }) => {
  const res = await page.request.get('/books/0998');
  expect(res.status()).toBe(200);
  const html = await res.text();
  expect(html).toContain('地藏菩萨本愿经');
  // overlay 零痕迹;入口「竖」按钮已并入 Header 栈(W12 修订),
  // 与藏/签/存一样随栈 SSR,属预期。
  expect(html).not.toContain('data-vreader');
});
