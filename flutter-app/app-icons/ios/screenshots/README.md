# App Store Screenshots — 乾隆大藏经 (iOS / iPadOS)

Real screenshots of the running app, captured at Apple's required pixel
sizes for App Store Connect (the same five screens as the Android set, light
**月映清辉** theme, full-bleed with system bars hidden).

| Folder         | Resolution  | App Store slot                          |
|----------------|-------------|-----------------------------------------|
| `iphone_6.5/`  | 1284 × 2778 | iPhone **6.5" Display** (portrait)      |
| `ipad_13/`     | 2048 × 2732 | iPad **13" Display** (portrait)         |

These are the sizes shown in the upload dialog:
- iPhone 6.5": accepts 1242×2688, 2688×1242, **1284×2778**, 2778×1284 — used **1284×2778**.
- iPad 13": accepts 2064×2752, 2752×2064, **2048×2732**, 2732×2048 — used **2048×2732**.

App Store Connect reuses one device's screenshots for the other display
sizes, so this 6.5"/13" pair covers the iPhone and iPad listings.

## Screens (5 each, ordered for the listing)

1. `01_reader`  — reading view: a sutra on rice paper with calligraphic
   typography, chapter dividers, translator line and page indicator.
2. `02_home`    — home page (乾隆大藏经 catalog): 常用经典 quick picks + the
   full 部类目录 of 1809 scriptures.
3. `03_history` — 我的研习 → 历史: reading history / favorites / bookmarks / notes.
4. `04_search`  — offline full-text search across 1669 sutras.
5. `05_themes`  — the six ink-wash themes.

## Theme showcase — `theme_variants/`

The home page rendered in all **6 ink-wash themes** (iPhone 6.5", 1284×2778),
for showcasing the theme variety on the listing:

`home_1_lianchichanyun` 莲池禅韵 · `home_2_zhulinyoujing` 竹林幽径 ·
`home_3_yueyingqinghui` 月映清辉 · `home_4_hupochangguang` 琥珀长光 ·
`home_5_guchayese` 古刹夜色 (dark) · `home_6_fagufanyin` 法鼓梵音 (dark).

(`home_3_yueyingqinghui` is the same theme as the main set's `02_home`.)

## Format / compliance

- **24-bit PNG, no alpha**, exact required pixel dimensions (verified).
- Apple uses only the first 3 screenshots on app installation sheets, so the
  reader / home / history order leads with the strongest screens.

## How they were made

Captured from the real Flutter app on a physical Android tablet by setting
the display to each iOS resolution (`wm size` / `wm density`) so Flutter
relaid out at the correct aspect ratio — genuine UI at native iOS sizes, not
upscaled or letterboxed:

- iPhone 6.5": `wm size 1284x2778` + `wm density 480` (→ 428 pt wide, Pro-Max class)
- iPad 13":   `wm size 2048x2732` + `wm density 320` (→ 1024 pt wide, 12.9" class)

> Note: rendered via Flutter's identical cross-platform UI. If you later want
> screenshots from an actual iOS device/simulator (e.g. for status-bar
> differences or App Previews), recapture on a Mac with the iOS Simulator.
