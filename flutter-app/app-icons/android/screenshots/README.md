# Play Store Screenshots — 乾隆大藏经

Real screenshots of the running app (captured on a physical Samsung
SM-P613 tablet, package `com.aeonlectron.dazangjing`), per the
[Play Store graphic asset specs](https://support.google.com/googleplay/android-developer/answer/9866151):

- **24-bit PNG, no alpha**, between 320 px and 3840 px per side, aspect
  ratio ≤ 2:1. Verified for every file.
- System status bar and navigation/taskbar hidden (immersive mode), so each
  image is full-bleed app content — no device chrome or other apps' icons.
- Light **月映清辉** theme (cool-grey rice paper) to match the app icon and
  feature graphic.

## Sets (5 screenshots each)

| Folder            | Resolution | Form factor / layout                  |
|-------------------|------------|---------------------------------------|
| `phone/`          | 1080×1920  | Phone (single-column)                 |
| `tablet_7inch/`   | 1200×1920  | 7-inch tablet (≈sw600dp, 3-column)    |
| `tablet_10inch/`  | 1200×2000  | 10-inch tablet (≈sw800dp, 4-column)   |

Each form factor shows the same five screens, ordered for the listing
(first = most prominent):

1. `01_reader`  — the reading view: a sutra rendered on rice paper with
   calligraphic typography, chapter dividers, translator attribution and a
   page indicator (the core experience).
2. `02_library` — 乾隆大藏经 catalog: 常用经典 quick picks + the full
   部类目录 of 1809 scriptures.
3. `03_history` — 我的研习 → 历史: reading history / bookmarks / notes.
4. `04_search`  — offline full-text search across 1669 sutras.
5. `05_themes`  — the six ink-wash themes (莲池禅韵 / 竹林幽径 / 月映清辉 /
   琥珀长光 / 古刹夜色 / 法鼓梵音).

All three form factors are genuine responsive layouts of the real UI, not
upscaled copies — captured by reconfiguring the display (`wm size` /
`wm density`) so Flutter relaid out for each device class.

## Theme showcase — `theme_variants/`

The home page rendered in all **6 ink-wash themes** (phone, 1080×1920),
for showcasing the theme variety on the listing:

`home_1_lianchichanyun` 莲池禅韵 · `home_2_zhulinyoujing` 竹林幽径 ·
`home_3_yueyingqinghui` 月映清辉 · `home_4_hupochangguang` 琥珀长光 ·
`home_5_guchayese` 古刹夜色 (dark) · `home_6_fagufanyin` 法鼓梵音 (dark).

(`home_3_yueyingqinghui` is the same theme as the main set's `02_library`.)

## Notes

- The same five screens were captured per form factor; Play accepts 2–8
  screenshots per type, so you can upload all five or a subset (the reader,
  library and themes shots are the strongest).
- To regenerate or capture different screens, run the app on a device, set
  the light theme, hide system bars
  (`settings put global policy_control immersive.full=<pkg>`), and
  `adb exec-out screencap -p`.
