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
});
