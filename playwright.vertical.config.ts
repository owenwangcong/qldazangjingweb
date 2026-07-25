import { defineConfig } from '@playwright/test';

/**
 * 竖排引擎纯逻辑单测(web-vertical-reader-plan.md §11 CW1~CW5/CW14)。
 * 与主配置(E2E,需 dev server)分离:此处零浏览器、零 webServer。
 * 运行:npm run test:vertical
 */
export default defineConfig({
  testDir: './src/lib/vertical/__tests__',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  reporter: [['list']],
  use: {
    // 系统 Chrome:免下载浏览器;golden 基线绑定本机 Chrome/Windows(R1 口径)。
    channel: 'chrome',
    viewport: { width: 900, height: 1500 },
    deviceScaleFactor: 1,
    // 关闭 ClearType 亚像素抗锯齿:RGB 边缘条纹会让 golden 又脆又难比对
    // (放大看似"彩虹字",实为 LCD 条纹;实施备忘 WS2)。
    launchOptions: { args: ['--disable-lcd-text'] },
  },
  expect: {
    toHaveScreenshot: { animations: 'disabled' },
  },
});
