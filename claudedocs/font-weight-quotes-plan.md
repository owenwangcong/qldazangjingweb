# 字重三档 + 竖排直角引号——两端方案台账

> 分支 `feature/font-weight-vquotes`。跟踪约定同 web-vertical-reader-plan.md §0:
> checkbox 勾记 + 完成记录,实施偏离先改本文档。2026-07-30 立项。

## 0. 需求与已确认决策(用户拍板,勿再询问)

两个功能(用户 2026-07-30 提出):

1. **字重三档**:web 与 App 上,所有 8 款字体给三档粗度选择。
2. **竖排直角引号**:竖排时把单弯引号 `‘’` 换成适合古籍竖排的直角引号。

| # | 决策 | 内容 |
|---|------|------|
| FQ1 | 字重三档定义 | **标准/中粗/加粗**。全部 8 款字体(两端)实测均为静态单字重 Regular 400、无可变轴,多数商业字体不存在多字重版本,真字重路线不可行。以描边合成粗化:web `-webkit-text-stroke-width`、Flutter 字形描边叠绘;档位宽度 **0 / 0.02em / 0.04em** 两端一致。"细"档因无法真正变细(只能淡墨模拟)被否决。 |
| FQ2 | 引号映射 | **仅 `‘`(U+2018)→`﹁`(U+FE41)、`’`(U+2019)→`﹂`(U+FE42)**,竖排管线独占;双弯引号 `“”` 维持既有剥除决策不变。`﹁﹂` 作**独立占格 token**(不在悬浮表内,走 tokenize 默认分支),直立居中,符合竖排排版惯例;白文模式下随 `\p{P}` 一并剥除。横排不受影响,保持弯引号原样。 |
| FQ3 | 字重作用范围 | **仅经文正文**(横排滚动/翻页 + 竖排翻页/展卷),横竖排**共用同一设置**(与字体选择的既定共用模式一致,见 web-vertical-reader-plan.md §9)。站点/App 界面文字不受影响。 |

## 1. 关键事实(2026-07-30 实测)

- **字重**:`flutter-app/assets/fonts/` 8 个 TTF 的 OS/2 `usWeightClass` 全部 400,无 `fvar`。
  web 站点字体 @font-face 声明 `weight: 100 900`(变区间伪装)→ 设 `font-weight`
  浏览器不会合成加粗;书级子集字体硬写 `font-weight: normal`。
  **描边不改变字形 advance 度量** → 横排翻页分页测量不受影响
  (对照 `reader_text_utils.dart:13-19` 的 fontWeight 改宽度警告,描边方案天然规避)。
- **引号字形覆盖**(fontTools 实测 cmap):
  - Flutter 8 个全量 TTF:`﹁﹂﹃﹄「」『』‘’` **全部齐备**,可直接绘制;
  - web 书级子集字体(8×1809):有 `‘’` 无 `﹁﹂`;站点 woff:全无。
  → web 需**补充字体**:从 flutter TTF 子集出仅含 U+FE41-FE44 的微型 woff
  (每族 1 个,约 1-2KB),以同名 @font-face + `unicode-range` 叠加在书级字体之后
  (后声明的 range 面优先;浏览器按需下载,书内无引号则零流量)。
- **数据分布**:`0085-01` 无任何弯引号(指纹不变);`0998` 有 `‘×45 ’×45 “×145 ”×79`
  → **0998 分页指纹必须两端重标定且逐位一致**(CW14 对拍约定)。
- **既有 bug 顺修**:web 横排剥双引号 `BookDetailPage.tsx:1002` 用字符串参数
  `replace("“","")` 只剥每段第一处 → 改 `/“/g`、`/”/g`。

## 2. 设计要点

### 2.1 引号映射(两端逐位一致)

- 函数 `mapVerticalQuotes(text)`:`‘→﹁`、`’→﹂`,仅此两条。
- 插入点:**竖排 token 管线内**,`cleanParagraph → splitParagraphSegments →`
  **`mapVerticalQuotes`**` → display(简繁转换) → tokenizeText`。
  按文本段应用(`<img>` 标签属性绝不被触碰);在 display 之前(OpenCC 不碰这些码点,
  但前置最稳)。web 落 `src/lib/vertical/tokenStream.ts`,Flutter 落
  `lib/core/vertical/token_stream.dart`,共享准源 `paragraph_text.dart` **不动**
  (横排不映射)。
- `punctuation.ts/.dart` 头注释同步:「弯引号已上游剥除」的表述改为
  「双弯引号上游剥除;单弯引号映射为 ﹁﹂ 占格」。

### 2.2 字重(两端同参数)

| 档 | 存储值 | 描边宽 |
|----|--------|--------|
| 标准 | `normal` | 0(现状,默认) |
| 中粗 | `medium` | 0.02em |
| 加粗 | `bold` | 0.04em |

- **web**:`FontContext` 新增 `fontWeightGear`,localStorage key `fontWeightGear`
  (正向命名,W16 惯例);Header「阅读设置」字体区后加三档 RadioGroup;
  应用点=横排正文容器 + 竖排列带容器(**不含** chrome/设置面板),
  `WebkitTextStrokeWidth`(颜色默认 currentColor,随主题)。em 单位 → 悬浮句读
  (0.45×fs)自动按比例变细,无需单独处理。
- **Flutter**:`AppSettings` 新增 `String fontWeightGear = 'normal'`
  (isar 旧行回填空串 → `effectiveFontWeightGear` 兜底 `'normal'`;
  **必须加进 `_copy()`**);`setFontWeightGear` + reader_settings_sheet 三档
  (所有阅读模式可见);
  - 竖排:`VerticalPageStyles` 加 `strokeWidthEm`,**`signature` 必须纳入**
    (否则 GlyphCache 不失效);GlyphCache 增描边画笔缓存
    (`TextStyle(foreground: Paint..style=stroke..strokeWidth=em×fontSize)`),
    `paintColumnGlyphs`/`_paintPunctAt` 在填充层上叠画描边层(仅非标准档,
    每字形 +1 次绘制;翻页模式 raster 预算已紧,真机复测记入验收)。
  - 横排滚动/翻页:正文 RichText 外套 Stack,底层描边克隆
    (递归克隆 TextSpan,`color→foreground` 互换;`IgnorePointer+ExcludeSemantics`,
    选区/语义只在填充层)。描边不改度量 → `SutraPaginator` 测量与
    `PaginationKey` 均无需感知字重。
  - 字重**不进** `VerticalPaginationKey`(不影响网格几何),只进样式签名。

### 2.3 指纹重标定流程 → 实测无需重标定(2026-07-30)

预判 0998(`‘×45`)指纹会变,实测两端基线**全部原值通过**。原因:
`‘’` 在旧管线本就是独立占格 token(不在悬浮表、未被剥除),映射为 `﹁﹂`
后仍是占格 token——1:1 字符替换,token 数/列切分/页分组结构逐位不变,
而 digest 只散列结构不含字符。基线 `0085-01 63/1099/747057561/957985439`、
`0998 18/303/297985313/622377286` 均保持;若日后指纹测试失败,本功能
不是嫌疑(它被证明结构中性)。

## 3. 任务清单

- [x] T1 方案台账(本文档)
- [x] T2 web 引号映射 + 补充字体脚本/资产 + 横排双引号 bug 顺修
- [x] T3 flutter 引号映射 + 单测
- [x] T4 0998 指纹对拍 → 实测结构中性,基线原值保持(§2.3)
- [x] T5 web 字重(context/UI/应用)
- [x] T6 flutter 字重(字段/UI/竖排描边/横排描边层)
- [x] T7 两端全量回归 + golden 重录目检 + 增量提交

⚠️ **部署注意**:整个 `/public` 在 .gitignore(数据资产带外部署)。
`public/data/quote_fonts/*_vquotes.woff`(8 个,每个 1~5KB)不入库,
部署时须与 book_fonts 同渠道同步,或在部署机跑
`python scripts/generate-vquote-fonts.py`(依赖 fonttools,
从 flutter-app/assets/fonts/ 全量 TTF 子集生成)。

## 4. 验收

- CQ1 竖排含 `‘’` 书(如 0998、1274)显示 ﹁﹂ 直角引号、独立占格、白文剥除;
  横排仍显示 `‘’`。
- CQ2 web 8 款字体下 ﹁﹂ 与正文同族渲染(补充字体命中,不落系统字体);
  无引号书籍不下载补充字体。
- CQ3 0998 指纹两端逐位一致;0085-01 指纹不变。
- CW 字重:三档在两端 8 款字体 × 横竖排全部生效;默认档与现状零视觉差;
  档位刷新/重启后保持;横排翻页无溢出(描边不改度量);
  Flutter 竖排翻页真机 raster 复测(瞬时口径红线 33.3ms)留待用户设备验证。

## 5. 完成记录

- 2026-07-30 立项,FQ1~FQ3 用户拍板;字形覆盖/字重实测完成(§1)。
- 2026-07-30 T1~T7 全部完成。回归:flutter test 236 项全绿(analyze 0 issue);
  web 单元层 48 项全绿;E2E reader/settings/responsive 17 项全绿
  (「模式互切」首跑一次超时失败为 chrome 自动隐藏时序偶发,单跑即绿,
  与本次改动无关;perf.spec 按台账只认生产构建未跑)。
  golden 仅 0998-verse 变化(90px,恰为 4 处引号),目检通过后重录;
  0998 首页/LXGW 复标定 golden 未变。验收 CQ1/CQ3/CW 设置持久化与
  分页不溢出(描边不改度量)均由上述测试覆盖。
- 2026-07-30 **CQ2 实机浏览器验证通过**(chrome-devtools,dev server):
  0998 竖排下 8 款字体逐一切换,补充面 FontFace(`custom-font-*`,
  `U+FE41-FE44`)全部 status=loaded 且网络层实抓对应
  `{family}_vquotes.woff` 200;列带含 ﹁﹂ 无残留 ‘’;aaKaiTi 截图目检
  直角引号与正文同族同风格、独立占格直立。反向:0085-01(无引号)
  竖排渲染完成后补充面保持 unloaded、零 vquotes 请求(unicode-range
  按需加载语义成立)。**遗留待验仅剩** Flutter 竖排翻页真机 raster 复测。
