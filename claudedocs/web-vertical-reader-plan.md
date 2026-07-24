# 网页版古籍竖排阅读 — 详细设计与开发跟踪文档

> **状态:WS3 完成(两模式交互 E2E 全绿)| 当前步骤:WS4 进行中 | 详设定稿:2026-07-23**
> 母文档:`flutter-app/docs/vertical-reader-plan.md`(S1~S8/D1~D6)、`flutter-app/docs/vertical-scroll-plan.md`(V1~V9/DS1~DS5)——排版规则与验收口径沿用,本文只记录 web 侧设计与差异
> 技术栈:Next.js 14 + React 18 + Tailwind;测试 `@playwright/test`(单测+E2E+截图 golden 一套框架)

---

## 0. 文档用法(开发跟踪约定)

本文档是 web 竖排功能的**唯一开发依据与进度台账**:

1. **进度标记**:§12 实施步骤的任务 checkbox 完成即勾 `[x]`,并在该步「完成记录」行填日期+提交号;§11 验收清单同步勾记。
2. **顶部状态行**:每步完成后更新「状态/当前步骤」。
3. **偏离先改文档**:实现与设计冲突时,先在 §2 追加 W 编号决策(注明日期与理由)再改代码;禁止无记录偏离。
4. **踩坑记录**:实施中发现的陷阱写入 §13 风险表下方「实施备忘」小节。
5. 需要用户裁决的新问题:标注 `⚠️待裁决` 并暂停该项。

## 1. 背景与核心认识

Flutter 端已完成四种阅读模式中的两种竖排(翻页 S1~S8、展卷 V1~V9)。web 端复刻这两种竖排,核心认识:

**两种竖排在 web 上是同一个渲染基底**——一条连续列带(横向滚动容器,阅读序右→左),两种模式只是吸附与交互预设不同:

```
列带(共享 DOM,一次排版)
├─ 展卷模式 = 每列都是吸附点(scroll-snap 逐列)
└─ 翻页模式 = 每 colsPerPage 列一个吸附点(mandatory)+ 断列补白 + 翻页点按分区
```

Flutter 因视图层限制用了 PageView/ListView 两套 widget;web 的 scroll-snap 把视图层也统一了。模式互切零重排、零 DOM 重建(只改 snap 标注与交互层)。

## 2. 决策记录(W 系列,全部已裁决)

| # | 决策点 | 结论 | 日期 |
|---|--------|------|------|
| W1 | 渲染路线 | **移植 TS 算术分页器 + 绝对定位 span**。不用 CSS writing-mode(悬浮句读做不到、网格受字体度量摆布);不用 Canvas(白丢文本选择/复制)。DOM 序=阅读序,复制天然可用 | 07-22 |
| W2 | 网格水平定位 | **对称余量内边距** `padSide=(contentW−gridW)/2`(数学上等价于 Flutter 每页居中,因居中偏移对所有页恒定);翻页预设在**每处断列**(插图/卷尾/末页)前插补白,残页只显示自己的列 | 07-22 |
| W3 | 响应式(硬性) | 几何=容器尺寸的纯函数;尺寸进分页键,ResizeObserver 重排(防抖 250ms),blockIndex 锚定还原;触摸/滚轮/键盘三模态。详见 §8 | 07-22 |
| W4 | 滚动方向实现(**07-23 修订**) | **`direction:rtl` 滚动容器 + 子项 `direction:ltr`**。rtl 容器天然从右缘开始、向左溢出可滚,无初始跳转;scrollLeft 负值语义各主流浏览器早已按规范统一,以 `readOffset()/setOffset()` 归一化封装(offset=已展开距离≥0)。原 LTR+手动布点方案否决:flex row-reverse 向 inline-start 溢出不可滚(规范行为),绝对定位布点作 WS3 备胎 | 07-23 |
| W5 | 滚动物理 | 接受浏览器原生惯性+snap 落点,不用 JS 接管复刻 Flutter 手感调参;左缘渐隐用 CSS mask 复刻 | 07-22 |
| W6 | 跨列反馈通道 | Android=`navigator.vibrate(8)`+音效;iOS 无振动 API→**Web Audio 合成短嗒补位**(Flutter 端已有默认音效实现,对齐);40ms 节流 | 07-22 |
| W7 | 竖排独立字号 | 横排字号是 Tailwind 档位类,竖排需数值 px→独立设置,**默认 26**(对齐 Flutter 07-22 决策);字间/行间同样独立(D6) | 07-22 |
| W8 | 划注/搜索高亮 | 竖排下 recogito 划注与 DOM 注入高亮**不可用**(镜像 D3 纯阅读);带高亮/划注参数进入书页时以横排呈现 | 07-22 |
| W9 | SSR/SEO | 竖排是客户端可选模式,SSR 恒输出现有横排 DOM;竖排以全屏覆盖层(overlay)形式在客户端挂载,不改服务端渲染树 | 07-22 |
| W10 | 测试框架 | 纯逻辑单测、DOM 坐标断言、golden 截图、E2E 全部用 `@playwright/test`,不新增框架 | 07-22 |
| W11 | 交付范围(用户) | **两种竖排一起交付**(共享基底,WS3 同时点亮) | 07-22 |
| W12 | 切换入口(用户) | **书页内工具条**:横排书页加悬浮入口按钮进竖排;竖排 chrome 内置模式三档快切与竖排设置组 | 07-22 |
| W13 | 沉浸态(用户) | **隐藏 Header**:竖排为全屏覆盖层,点按中部切换 chrome 显隐;退出回横排原位 | 07-22 |
| W14 | 展卷反馈默认(用户) | **与 Flutter 对齐默认开**:Android=振动+音效,iOS=仅音效;设置一键关 | 07-22 |
| W15 | 卷尾条目(**WS1 修正**) | 原判断"无上下卷数据"有误——书 JSON `meta.last_bu/next_bu` 齐全(0998 核实),仅横排页面未渲染。卷尾 nav 条目提供**上一部/下一部跳转 + 返回目录 + 退出竖排**,WS3 实装;引擎 hasNav 判定与 Flutter 同源(lastBuId/nextBuId 非空) | 07-23 |
| W16 | 白文/乌丝栏存储 | web 用 localStorage,无 isar 回填陷阱→**正向命名**:`showColumnRules` 默认 true、`baiwen` 默认 false(与 Flutter 的反转存储决策不同,勿照搬) | 07-23 |
| W17 | 散文连排(用户重申) | **D5 在 web 端为硬性要求**:小段落(散文)之间不断列、连续填列求紧凑,句读即天然分隔;断列仅发生在 bt/bm 大章节(如"第一/第二"品名)、偈颂区段、插图。实施与验收(CW4/CW6)必须按此口径,严禁按段落断列 | 07-23 |

## 3. 与现有代码的对接点(已核实)

| 对接点 | 现状(文件) | 竖排如何用 |
|--------|-------------|-----------|
| 书数据 | `book.juans[]`:`{id, type:'bt'|'bm'|'p', content:string[]}`,正文含内联 `<img …>`,弯引号渲染期剥除;`book.meta.title/Arthur`(BookDetailPage.tsx §render) | token 流输入;meta 供卷首书名/作者列 |
| 段落锚点 | bt/bm 有 `id={juan.id}`;正文段有 `id=part-${juan.id}-${index}` | blockIndex ↔ DOM 锚点双向映射(§5.2),横竖互切定位 |
| 简繁转换 | `LanguageContext.convertText`(opencc-js cn⇄tw),`isSimplified` | 引擎在 token 化**之前**整段转换;isSimplified 进分页键 |
| 字体/排版设置 | `FontContext`:selectedFont(CSS 变量名)、fontSize(Tailwind 类)、lineHeight(数值)、letterSpacing(CSS 串)、selectedWidth(max-w-*)、localStorage 逐键存 | 竖排复用 selectedFont/selectedWidth;字号/字间/行间独立(W7),新 hook 同款 localStorage 模式 |
| 划注/高亮 | recogito 挂 `#recogito-container`;搜索高亮 DOM 注入 | 竖排 overlay 不进该容器,互不干扰(W8) |
| 站点框架 | `Header` 组件,书页 `<main>` 常规文档流 | 竖排 overlay `position:fixed inset-0` 盖住,body 滚动锁定(W13) |

## 4. 架构与文件清单

```
src/
├─ lib/vertical/                     ← 纯 TS 引擎,零 React/DOM 依赖,全部可单测
│  ├─ models.ts                      ← 类型定义(§5.1)
│  ├─ punctuation.ts                 ← 标点三分类表(悬浮/剥除/占格),从 Dart 逐表移植
│  ├─ tokenStream.ts                 ← juans → 块扁平化 → 显示态 token 流(§5.2/5.3)
│  ├─ verseDetector.ts               ← 4/5/6/7 言检测 + 相邻同 n 区段归并(含 07-20 修复)
│  ├─ gridGeometry.ts                ← 几何公式全集(§6)
│  ├─ paginator.ts                   ← token 流 → 列带 + 页首索引 + 补白表 + SnapMetrics(§5.4)
│  └─ __tests__/                     ← CW1~CW5 单测 + 对拍 fixture
│
├─ app/components/vertical/
│  ├─ VerticalReaderOverlay.tsx      ← 全屏覆盖层:滚动容器、吸附预设、输入模态、chrome、ResizeObserver
│  ├─ VerticalColumn.tsx             ← 单列条目:字 span 网格+悬浮标点+乌丝栏(§7)
│  ├─ VerticalChrome.tsx             ← 顶栏(退出/书名)+底栏(进度、模式三档、设置弹层)
│  ├─ verticalSettings.ts            ← useVerticalSettings hook + localStorage schema(§9)
│  └─ feedback.ts                    ← 跨列反馈:节流、vibrate、Web Audio 短嗒(§7.5)
│
└─ app/books/[id]/BookDetailPage.tsx ← 改造:悬浮入口按钮 + 挂载 overlay(SSR 输出零改动)
```

依赖方向:`components/vertical → lib/vertical`;引擎文件禁止 import React/DOM API(ESLint 约束或 review 把关)。

## 5. 引擎详细设计

### 5.1 类型定义(models.ts,实现即照抄)

```ts
export type ColumnRole = 'title' | 'author' | 'bt' | 'bm' | 'body';

export interface GridToken {
  char: string;           // 单字,Array.from 按码点切分(代理对安全)
  trailingPunct: string;  // 悬浮句读 ''|≤2 枚(如"。」"),绘制纵向下堆,>2 截断
  blockIndex: number;     // 进度锚定(§5.2 扁平化定义)
  paragraphIndex: number;
}

export interface VColumn {
  role: ColumnRole;
  tokens: GridToken[];
  indent: number;         // 顶部空格数(bm=1、author 下沉)
  verseLen: number;       // 偈颂句长 n;非偈颂列 = 0。绘制行号 rowOf(i)=i+floor(i/n)
}

export type StripItem =
  | { kind: 'column'; column: VColumn }
  | { kind: 'image'; src: string; blockIndex: number }   // 独占视口宽
  | { kind: 'nav' };                                      // 卷尾,独占视口宽(W15)

export interface PaginationKey {   // 任一分量变 → 重排;乌丝栏/反馈不在键内
  bookId: string; contentW: number; contentH: number;
  fontFamily: string; fontSize: number;
  linePitch: number; charGapEm: number;
  isSimplified: boolean; baiwen: boolean;
}

export interface StripResult {
  key: PaginationKey;
  items: StripItem[];
  pageStarts: number[];        // 翻页预设:页首 item 索引(升序)
  spacers: Map<number, number>; // 翻页预设:item 索引 → 其前插补白 px(断列残页,W2)
  firstItemOfBlock: number[];  // blockIndex → 首现 item 索引(逐 token 记录,单调不减)
  blockOfItem: number[];       // item 索引 → firstBlockIndex
  metrics: SnapMetrics;        // 条目宽前缀和(§5.4)
}
```

### 5.2 blockIndex 定义与 DOM 锚点映射(横竖互通的基石)

扁平化 `book.juans`,顺序编号:

```
for juan of book.juans:
  type bt/bm → 1 个块 { text: content[0], anchor: juan.id }
  type p     → content[i] 逐段成块 { text: content[i], anchor: `part-${juan.id}-${i}` }
```

- `blockIndex` = 该扁平列表下标。**与横排 DOM 锚点一一对应**:横→竖用「视口内第一个可见锚点元素」求 blockIndex;竖→横用 `anchors[blockIndex]` `scrollIntoView`。
- 进度存储、TOC/搜索跳转、模式互切全部以 blockIndex 为锚(C5 口径)。

### 5.3 token 流构建规则(tokenStream.ts)

处理次序(每块):**弯引号剥除 → 简繁转换(convertText)→ `<img>` 切分 → 码点切分 → 标点归属/白文剥除**。

| 规则 | 内容(全部沿用母文档 §7,web 差异加粗) |
|------|------|
| 卷首 | 第 1 列=书名(title 角色,顶格,**取 book.meta.title**);第 2 列=作者(author,0.8×字号,indent 下沉至列下半部,**取 book.meta.Arthur**) |
| bt/bm | 独占列;bt 加粗顶格,bm 加粗 indent=1;超长折入下一列 |
| 正文 | D5 连排:相邻散文段合并连续填列,仅偈颂/bt/bm/插图断列;块/段锚点逐 token 保留 |
| 偈颂 | 检测命中→按句折列+句间空一格(D6):k=(容量+1)÷(n+1) 整句/列;区段归并(相邻同 n 段合并,总句数≥4 才标注) |
| 标点 | 悬浮类 `。,、;:!?」』》)〕】…—` 归前字 trailingPunct;前置符并入前一字堆,无前字舍弃 |
| 白文 | `\p{P}u` 正则+全角补充表全剥;流变短→独立分页(baiwen 进 key) |
| 插图 | `<img>` 正则切分(现渲染同款),src 提取→StripImage,断列 |
| 拉丁/数字 | 占一格直立居中,不旋转 |

断言(A 系列沿用):A2 空书兜底最小列带;A3 禁 codeUnit 索引;A4 token 守恒(∑列 tokens == 输入流);A5 悬浮堆绘制截 2;A6 偈颂列 `tokens.length % n === 0`。

### 5.4 分页器与 SnapMetrics(paginator.ts)

- 单遍算术:token 流+断列信号 → `items[]`;同遍记录 `firstItemOfBlock/blockOfItem`。
- **页分组仅是标注**:再一遍扫 items 产出 `pageStarts`(column 计数满 colsPerPage、或遇 image/nav 强制断页)与 `spacers`(断页处残页補白 `(colsPerPage−r)×colPitch`,r=残页列数;含卷尾末页)。
- `SnapMetrics`:条目宽前缀和(column=colPitch,image/nav=视口宽,含 spacers 按预设分列两套或参数化);提供 `offsetOfItem(i)`、`itemAtOffset(x)`(纯列 O(1) 取模,含图二分)、`columnsAdvanced(offset)`(反馈计数用)。
- 缓存:LRU 容量 2,键=PaginationKey 序列化;翻页⇄展卷共享同一 StripResult。
- 性能预算:3 万字单遍 <10ms(与 Flutter 同量级,纯算术)。

## 6. 网格几何规范(gridGeometry.ts,公式即断言)

```
fs        = verticalFontSize                     // px,默认 26(W7)
cellW     = fs
cellH     = fs × (1 + clamp(charGapEm, 0, 0.4))  // 字间默认 0 紧排
colPitch  = fs × clamp(linePitch, 1.35, 3.0)     // 行间默认 1.75
gap       = colPitch − cellW
contentW  = min(viewportW, maxW(selectedWidth)) − 2×basePad   // basePad=16px;maxW 复用「页面宽度」设置映射(max-w-4xl→896 等)
contentH  = viewportH(dvh) − chromeH              // 沉浸态 chromeH=0(W13)
charsPerCol = floor(contentH / cellH)             // assert ≥1,否则 A1 钳字号
colsPerPage = floor((contentW + gap) / colPitch)  // assert ≥1
gridW     = colsPerPage × colPitch − gap
padSide   = (contentW − gridW) / 2                // W2:容器 scroll-padding-inline
cellY(row)= (indent + row) × cellH                // 列内纵坐标
rowOf(i)  = i + floor(i / n)                      // 偈颂绘制行号(D6)
```

列间隙分区(母文档 §6 沿用):标点悬浮区 `0~0.55·gap`(锚 `px=cellW+0.06·gap, py=cellBottom−0.85·punctH`,字号 0.45·fs,**偏移校准表按 web 字体在 WS2 重标定**,golden 锁 Chromium+默认字体);乌丝栏 `x=cellW+0.62·gap`,宽 `max(0.5, 1/devicePixelRatio)px`,列带首列(最右)不画。

物理像素对齐:所有绝对坐标经 `Math.round(v×dpr)/dpr` 取整防模糊。

## 7. 渲染与交互详细设计

### 7.1 滚动容器(W4 修订版)

```html
<div class="v-scroll" style="direction:rtl; overflow-x:auto; overscroll-behavior-x:contain;
     scroll-snap-type:x mandatory; scroll-padding-inline:{padSide}px">
  <!-- 子项 DOM 序 = 阅读序;rtl 使首项落于右缘、向左延伸 -->
  <div class="v-item" style="direction:ltr">…</div>
</div>
```

- `readOffset() = −el.scrollLeft`(rtl 下 scrollLeft∈[−max,0]),`setOffset(x) => el.scrollLeft = −x`;二者是滚动坐标唯一出入口,单测锁定。
- 滚动条隐藏(沉浸态),进度由 chrome 底栏进度条呈现。
- **WS3 决策门**:若 rtl+snap 在目标浏览器出现怪癖,备胎=LTR 容器+绝对定位布点+初始 setOffset(max)(风险表 R5)。

### 7.2 列条目 DOM(VerticalColumn)

```html
<div class="v-item v-col" style="width:{colPitch}px; content-visibility:auto;
     contain-intrinsic-size:{colPitch}px auto; scroll-snap-align:start">
  <span class="v-char" style="left:0; top:{cellY}px; width:{cellW}px; height:{cellH}px;
        line-height:{cellH}px; font-size:{fs}px">字</span>
  <span class="v-punct" style="left:{cellW+0.06gap}px; top:{…}px; font-size:{0.45fs}px">。</span>
  <div class="v-rule" style="left:{cellW+0.62gap}px"></div>
</div>
```

- 字 span:定宽 cellW、`text-align:center`、行高=cellH——矩阵对齐由公式而非字体保证(方案 E 同理);单列节点 ≤ charsPerCol+标点数 ≈ 20~40,无需字形缓存。
- 样式角色:title/bt 加粗、author 0.8×fs;色彩沿用现有主题变量(ThemeContext 明暗自适应)。
- `content-visibility:auto` 惰性渲染(WB3:不支持则全量渲染,仅性能降级)。
- image 条目:视口宽,内嵌 `<img>`(现渲染同款提取);nav 条目:视口宽,返回目录+退出按钮(W15)。
- spacer 条目:仅翻页预设按 `spacers` 表条件渲染,无 snap 标注。

### 7.3 两模式=吸附预设(全部差异集中于此表)

| 维度 | 竖排翻页 | 竖排展卷 |
|------|----------|----------|
| snap 标注 | 仅 `pageStarts` 项 `scroll-snap-align:start` | 每个 column 项 `scroll-snap-align:start`(image/nav 两模式都有) |
| spacer | 按 `spacers` 渲染 | 不渲染 |
| 点按 | 左 25%=下一页(前进),右 25%=上一页,中 50%=chrome 显隐(与横排镜像,D1) | 任意处=chrome 显隐(DS3) |
| 页脚 | 页码 `当前页/总页`(当前页=readOffset 二分 pageStarts) | 仅进度条(DS2) |
| 跨列反馈 | 关 | 开(W14,§7.5) |
| 翻页 API | `setOffset(offsetOfItem(pageStarts[p±1]), smooth)` | —— |

模式互切:同一 StripResult,改预设属性即可,DOM 不重建、不重排。

### 7.4 沉浸态与 chrome(W13)

- 入口:横排书页右下悬浮按钮(书卷图标,`bottom-right`,移动端避让安全区)→ 打开 overlay(`fixed inset-0 z-50`,`document.body` 滚动锁定);Header 被覆盖。
- chrome:顶栏(退出 ✕、书名)+底栏(进度条、模式三档 `横排|竖排翻页|竖排展卷`、设置齿轮→弹层)。默认显示 3s 后自动隐去;点按中部切换。
- 退出:恢复 body 滚动,按当前 blockIndex `scrollIntoView` 横排锚点(§5.2)。
- 键盘 Esc=退出;进入/退出均不改 URL(W9)。

### 7.5 跨列反馈(feedback.ts,W6/W14)

- 监听 scroll 事件:`lead = metrics.columnsAdvanced(readOffset())`;lead 单调**前进**且距上次触发 ≥40ms → 触发一次。
- 触发体:`navigator.vibrate?.(8)`(能力检测);Web Audio 短嗒——OscillatorNode 方波 ~1800Hz、10ms 指数衰减包络,音量 0.1;AudioContext 在 overlay 首次 pointerdown 时 `resume()`(自动播放策略)。
- 跨图只计 1 次(B3);`scrollFeedback=false` 时监听器直接不挂(B5,零开销)。

## 8. 响应式规范(W3,硬性要求)

### 8.1 重排管线

```
尺寸/设置源 ──任一变化──▶ PaginationKey ──防抖250ms──▶ 引擎重排(<10ms)
  ResizeObserver(overlay 根元素)                        │
  旋转/分屏/窗口缩放/dvh 变化                            ▼
  字号/字体/简繁/白文/字间/行间               记录变化前视口首块 b
                                             → setOffset(offsetOfItem(firstItemOfBlock[b]))
```

- overlay 高 `100dvh`:竖排为**横向**滚动,不触发移动端地址栏伸缩,会话内高度稳定;真变化(旋转/分屏)走管线。
- 断点行为(自动,无需媒体查询):手机竖屏≈4~6 列,平板≈10~15 列,桌面被「页面宽度」设置封顶(不出 30 列巨页);极小尺寸 A1 钳制字号并提示。
- 吸附点是派生数据,随重排自动重标注。

### 8.2 输入模态

| 模态 | 行为 |
|------|------|
| 触摸 | 原生横滚+snap;点按按 §7.3 分区 |
| 滚轮 | `wheel`:deltaY→`setOffset(readOffset()+deltaY)`(向下滚=前进);翻页预设改为整页步进(节流至动画完成) |
| 触控板 | 横向双指原生(rtl 下方向天然正确);纵向按滚轮映射 |
| 键盘 | ←→=前进/后退(展卷一列/翻页一页;注意视觉左=前进);PageUp/Down=整页;Home/End=卷首/卷尾;Esc=退出 |

### 8.3 可访问性

- overlay `role="document"`;列内真实文本节点,读屏按 DOM 序(=阅读序)朗读;入口/退出按钮 aria-label。
- 浏览器整页缩放天然生效(CSS px);字号可访问性由竖排字号设置承担。

## 9. 设置与持久化(verticalSettings.ts)

localStorage 键(FontContext 同款逐键模式;W16 正向命名):

| 键 | 类型/默认 | 生效方式 |
|----|-----------|----------|
| `readingMode` | `'horizontal'`(默认)/`'verticalPaged'`/`'verticalScroll'` | 模式切换;记忆上次模式,进书页不自动打开 overlay(横排是 SSR 默认,竖排由入口按钮进入后按此键选预设) |
| `verticalFontSize` | number,默认 `26`(范围 18~40) | 进 key 重排 |
| `verticalCharGapEm` | number,默认 `0`(0~0.4) | 进 key 重排 |
| `verticalLinePitch` | number,默认 `1.75`(1.35~3.0) | 进 key 重排 |
| `verticalShowRules` | bool,默认 `true` | 仅重绘(CSS 类切换) |
| `verticalBaiwen` | bool,默认 `false` | 进 key 重排 |
| `verticalScrollFeedback` | bool,默认 `true` | 仅挂/卸监听 |
| `verticalProgress:{bookId}` | number(blockIndex),滚动节流 1s 写 | 进入还原/退出交接 |

设置弹层(chrome 底栏齿轮):模式三档、竖排字号/字间/行间滑杆、乌丝栏/白文/展卷反馈(仅展卷显示)开关。横排的字体与页面宽度设置对竖排同样生效(selectedFont/selectedWidth),不重复提供。

## 10. 边界与断言清单

| # | 场景 | 处理 |
|---|------|------|
| WB1 | rtl scrollLeft 归一化 | `readOffset/setOffset` 唯一出入口,单测:offset≥0、往返一致、maxOffset=∑宽−视口 |
| WB2 | 空书/单列/全标点白文后为空 | 最小列带(卷首+nav),不崩溃(A2) |
| WB3 | content-visibility 不支持 | 全量渲染降级,正确性不变 |
| WB4 | 字体异步加载(FOUT) | `document.fonts.ready` 后强制一次重绘;网格几何与字体无关,**不重排** |
| WB5 | 带高亮/划注参数进书页 | 不自动进竖排,横排呈现(W8) |
| WB6 | 极端字号/极小视口 | A1:钳字号至 charsPerCol≥1 且 colsPerPage≥1 |
| WB7 | 代理对/扩展 B 区字 | Array.from 码点切分;assert 单 token 单字(A3) |
| WB8 | token 守恒 | assert ∑items 列 tokens == 输入流(A4),CW4 property test |
| WB9 | 图片加载失败 | image 条目占位灰块+alt,不影响分页(宽度是视口宽,与加载无关) |
| WB10 | 多标签页设置漂移 | `storage` 事件同步竖排设置(同 FontContext 现状容忍度,低优先) |

## 11. 验收清单(CW 系列;测试文件落 `src/lib/vertical/__tests__/` 与 `tests/vertical/`)

- [x] **CW1 网格几何**:公式单测——给定(尺寸,字号,行间,字间)断言 charsPerCol/colsPerPage/padSide/spacer 精确值;A1 兜底(2026-07-23,gridGeometry.spec 6 项)
- [x] **CW2 字符流**:码点切分;标点归属;白文 `\p{P}` 零残留;`<img>` 切分;弯引号剥除;简繁在归属之前(2026-07-23,tokenStream.spec 9 项)
- [x] **CW3 偈颂检测**:散文不误判;偈颂样本命中且 n 正确;按联编码区段归并命中(0998 实测 40 段,与 Flutter 吻合)(2026-07-23,verseDetector.spec 8 项 + realbook)
- [x] **CW4 分页完整性**(property):任意输入 token 守恒;空书/单字/插图/偈颂边界(2026-07-23,paginator.spec)
- [ ] **CW5 进度锚定**:引擎层已绿(单调不减/往返一致,paginator.spec);blockIndex↔DOM 锚点双向映射随 WS5 复验后勾记
- [x] **CW6 矩阵对齐**:DOM 坐标断言(列 x 严格等差公差 colPitch、字 y 等差公差 cellH、偈颂跨列句首对齐)+ golden(0998 首页+四言偈段)(2026-07-23,column.spec)
- [x] **CW7 标点悬浮**:密集标点列字格距恒 cellH(零侵占);标点 em 框 ⊂ 悬浮区不触乌丝栏;堆叠坐标公式断言+A5 绘制截 2(2026-07-23,column.spec)
- [x] **CW8 乌丝栏**:位置 0.62·gap/数量 N−1/首列不画/上下沿与文本区齐平(2026-07-23,column.spec;开关零重排属引擎既证——rule 不在 PaginationKey)
- [x] **CW9 交互 E2E**:rtl 方向(首列贴右缘);翻页点按落点=整页跨度且页码联动;展卷静止 offset∈列边界;键盘/滚轮;模式互切往返零漂移;Esc 退出回锚点;卷尾 nav(2026-07-23,tests/vertical/reader.spec 8 项)
- [ ] **CW10 设置联动**:key 分量变化→重排+锚定还原;乌丝栏/反馈→零重排;localStorage 持久化与还原
- [ ] **CW11 响应式**:viewport 缩放/旋转 E2E→重排+还原;375/768/1280 三断点 golden;超宽被页面宽度封顶
- [ ] **CW12 性能**:3 万字卷 fling 连滚采样(CPU 4× throttle)无长帧;分页 <10ms;Lighthouse 书页分数不回归
- [ ] **CW13 SSR/SEO**:禁 JS 加载书页输出与现状一致;overlay 不进 SSR 树
- [x] **CW14 跨端对拍**:0085-01 与 0998 翻页产物指纹(页数/总列数/colHash/anchorHash/pageForBlock 采样)与 Flutter 端硬编码基线**逐位一致**;两端输入 JSON 验证逐字节相同(2026-07-23,realbook.spec)

## 12. 实施步骤(增量交付;完成即勾记并填「完成记录」)

### WS1 引擎移植(纯 TS,零 UI)
- [x] WS1.1 `models.ts` + `gridGeometry.ts`(公式全集+spacer)→ CW1
- [x] WS1.2 `punctuation.ts` 三分类表移植
- [x] WS1.3 `tokenStream.ts`(扁平化 blockIndex、码点切分、标点归属、img 切分、白文、简繁前置)→ CW2
- [x] WS1.4 `verseDetector.ts`(段级候选+区段归并)→ CW3
- [x] WS1.5 `paginator.ts`(列带+pages+pageStarts+spacers+SnapMetrics+LRU)→ CW4/CW5(引擎层)
- [x] WS1.6 跨端对拍——**无需跑 Dart**:Flutter 测试(vertical_strip_refactor_test.dart)已把两卷真书指纹硬编码为基线,TS 移植 digest 算法直接对拍,逐位一致 → CW14
- 完成记录:**2026-07-23,提交 `ea1888cf`,37 项单测全绿(npm run test:vertical),tsc 零错误**
### WS2 列条目渲染
- [x] WS2.1 `VerticalColumn`(span 网格+content-visibility+样式角色)
- [x] WS2.2 悬浮标点+校准表(初值取 Flutter 表,SimSun/Chromium golden 下目检无侵占;LXGW 等站点字体的复标定并入 WS6 视觉收尾)
- [x] WS2.3 乌丝栏+偈颂空格行号(rowOf)
- [x] WS2.4 DOM 坐标断言+golden → CW6/CW7/CW8(坐标断言即公式推演;golden 两张目检通过:题署下沉/品名低格/四言偈跨列对齐/句读悬浮)
- 完成记录:**2026-07-23,提交 `ffafe3d3`,全套 44 项绿**
### WS3 滚动容器与两模式(W11:同时点亮)
- [x] WS3.1 rtl 容器+`readOffset/setOffset` 归一化(决策门通过:rtl+snap 实测无怪癖——instant 越界回拉、smooth 落点、trusted 键盘均精确落列,备胎弃用)
- [x] WS3.2 展卷预设(逐列 snap)
- [x] WS3.3 翻页预设(pageStarts snap+spacers+页码)
- [x] WS3.4 点按分区+chrome+沉浸 overlay+退出交接(+/dev/vertical 开发路由,生产 404)
- [x] WS3.5 E2E 8 项全绿 → CW9
- 完成记录:**2026-07-23,提交 `7c7ba2df`;实机截图目检通过(满屏网格/沉浸态/chrome 自动隐)**
### WS4 响应式管线
- [ ] WS4.1 ResizeObserver→key→重排→锚定还原(防抖 250ms)
- [ ] WS4.2 滚轮/键盘/触控板映射
- [ ] WS4.3 三断点+旋转/缩放 E2E → CW11
- 完成记录:____
### WS5 设置/进度/入口
- [ ] WS5.1 `verticalSettings.ts`(schema §9)
- [ ] WS5.2 书页悬浮入口按钮+chrome 设置弹层(W12)
- [ ] WS5.3 进度记忆+横竖互切锚点交接
- [ ] WS5.4 SSR 不回归验证 → CW10/CW13
- 完成记录:____
### WS6 反馈与收尾
- [ ] WS6.1 跨列反馈(vibrate+Web Audio 短嗒+40ms 节流+AudioContext 解锁)
- [ ] WS6.2 左缘渐隐 mask(展卷)
- [ ] WS6.3 性能采样+Lighthouse → CW12
- [ ] WS6.4 文档勾记、风险复盘、收尾
- 完成记录:____

每步交付:代码+对应 CW 测试绿;WS2/WS3 另交坐标推演或截图证据(母文档 §12 口径)。

## 13. 风险

| # | 风险 | 等级 | 缓解 |
|---|------|------|------|
| R1 | 标点校准跨浏览器/跨字体漂移 | 中 | 校准表按 family 分组;golden 锁 Chromium+默认字体;其余浏览器容忍(悬浮区有 0.55·gap 余量) |
| R2 | 低端机全量 DOM 内存/首渲压力 | 中 | content-visibility 优先;WS6 实测不达标再上 windowing(列宽均匀 O(1) 窗口) |
| R3 | scroll-snap mandatory 长列表 fling 浏览器差异 | 低 | 落点由 snap 保证;体感差异属 W5 已接受口径 |
| R4 | iOS Safari 音效受静音拨片抑制 | 低 | 已接受:静音状态无反馈属系统预期行为 |
| R5 | rtl 容器+snap 组合怪癖 | 低 | WS3.1 决策门+绝对定位备胎(W4 注) |
| R6 | 横竖互切锚点粒度差(横排段落级/竖排 token 级) | 低 | 统一 blockIndex=段落级,竖排内更细定位由 offset 承担 |

### 实施备忘(踩坑随手记,实施期填写)

- **tsconfig target 陷阱**(WS1):仓库原 target 默认 ES5,拒绝 `/u` 正则(白文 `\p{P}` 必需,无 ES5 替代)→ 提到 ES2017(Next 用 SWC 编译,target 只影响类型检查不改产物)。注意 **`tsconfig.tsbuildinfo` 增量缓存会吞掉配置变更**——改完 tsconfig 后 tsc 仍报旧错,删缓存文件再验才生效。
- **浏览器兼容**(WS1):src 运行时代码禁用 `String.replaceAll`/`matchAll`(Next 默认 browserslist 含 Safari 12,无这两个 API 且不在 Next 自动 polyfill 清单);用 `replace(/…/g)` 与 `exec` 循环。`/g` 正则的 `lastIndex` 有状态,exec 循环用局部实例。测试文件跑在 Node,不受限。
- **对拍哈希的 JS 位运算**(WS1):Dart 是 64 位整数,JS `&` 先 ToInt32——因中间值 <2^53 精确且掩码 0x3fffffff 只取低 30 位,两端结果仍逐位一致(取模低位不受截断影响)。
- **Playwright 的 JSX 陷阱**(WS2):被测试文件 import 的 `.tsx` 中的 JSX 会被 Playwright 转译成 `__pw_type` 标记对象(组件测试机制),`renderToStaticMarkup` 直接崩。凡需要在测试内 SSR 的组件一律写 `React.createElement`,不用 JSX 语法(VerticalColumn 已注明)。
- **ClearType 彩虹字**(WS2):Windows 下 golden 截图放大看每字带红蓝绿彩边——是 LCD 亚像素抗锯齿条纹,不是渲染 bug(computed color 全黑已实证)。测试浏览器加 `--disable-lcd-text` 换灰度抗锯齿,golden 干净且更可移植。
- **Chrome 布局量化**(WS2):getBoundingClientRect 按 1/64px 量化(LayoutUnit),非 1/64 整数倍的期望值(如标点字号 7.8)断言容差要 ≥1/128px,不能用 precision 3。另:**滚动位置按整数 CSS 像素量化**(dpr=1),分数列距(45.5)落点差 0.5px 属正常,E2E 容差 ±1.5px。
- **主配置 html reporter 会挂起 agent**(WS3):失败后自动起报告服务器(:9323)并永久阻塞——命令行/CI/agent 跑 E2E 一律 `--reporter=list`。
- **Playwright 强制 prefers-reduced-motion**(WS3):`behavior:'smooth'` 全部瞬时完成,测试不得假设有动画过程;真浏览器有动画,连按类交互必须用 pending 目标基准而非读实时状态(stepPage 吃步事故)。
- **rtl 的 -0**(WS3):`-el.scrollLeft` 在卷首返回 `-0`,`toBe(0)`(Object.is)判不等——断言用 `Math.abs()`。
- **初始锚陷阱**(WS3):块 0 首现于 bt 列,题署两列在其前——初始块 0 必须解释为"卷首不跳转",否则展卷模式开卷即滚过书名/作者列。
- **模式互切锚粒度**(WS3):块锚在 D5 连排下会跨页漂移(块可始于前页列中段),互切改用**条目级锚**;块锚仅用于进入/退出/重排还原。

## 14. 更新日志

| 日期 | 内容 |
|------|------|
| 2026-07-22 | 初版方案(W1~W10) |
| 2026-07-23 | 详设定稿:W11~W14 用户裁决(一起交付/书页入口/沉浸式/反馈默认开);W4 修订为 rtl 容器方案;新增 W15/W16;补 §0 跟踪约定、§5~§9 详设、CW/WS 清单展开 |
| 2026-07-23 | W17:用户重申散文连排为 web 硬性要求(小段不断列,仅 bt/bm 大章节/偈颂/插图断列),D5 从继承项升格为正式决策 |
| 2026-07-23 | **WS1 完成**(提交 `ea1888cf`):引擎六文件移植,37 项单测全绿;CW1~CW4/CW14 勾记(CW5 引擎层绿,DOM 映射留 WS5);W15 修正(last_bu/next_bu 数据存在,nav 条目将做上下部跳转);tsconfig target ES5→ES2017 |
| 2026-07-23 | **WS2 完成**(提交 `ffafe3d3`):VerticalColumn+verticalStyles,DOM 坐标断言+golden 两张(灰度抗锯齿基线),CW6/CW7/CW8 勾记;备忘新增 __pw_type/ClearType/LayoutUnit 三坑;标点校准表 web 字体复标定并入 WS6 |
| 2026-07-23 | **WS3 完成**(提交 `7c7ba2df`):覆盖层+两模式吸附预设+chrome+dev 路由,CW9 E2E 8 项全绿;W4 决策门通过(rtl+snap 无怪癖,备胎弃用);修初始锚/连翻吃步/互切漂移三缺陷;备忘新增 html reporter 挂起、reduced-motion、-0、锚粒度等六坑 |
