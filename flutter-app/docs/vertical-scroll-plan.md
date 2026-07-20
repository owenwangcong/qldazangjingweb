# 竖排滚动(展卷)模式 — 实施方案

> 状态:**V1~V9 全部完成**(2026-07-20,提交 900ca776 起)。实测:真书指纹对拍逐位不变;42 组初速落点全在列边缘;真机吸附/跳转/四档互切验证通过;profile 采样 raster jank **0%**(p90 7.87ms,对照翻页 17.28ms/30.9%),build p99 16.46ms 在 60fps 预算内(2 帧超线发生在采样的方向反转瞬间)
> 母文档:`vertical-reader-plan.md`(竖排翻页 S1~S8 + D1~D6 决策全部沿用)
> 分支:`feature/vertical-reader` 续作

---

## 0. 需求末段「现有竖排引擎优化项」盘点 —— 全部已实现,跳过

| 需求项 | 现状 | 出处 |
|--------|------|------|
| 白文开关过滤标点 | ✅ 已有,重排级开关 | `punctuation.dart`/`token_stream.dart`,设置面板「标点:句读/白文」 |
| 悬浮句读(不占字宽) | ✅ 已有,数据层保证(标点是前字附属属性),白文/句读两版主体矩阵逐像素一致已真机实证 | `GridToken.trailingPunct` + painter 悬浮区绘制 |
| 5/7 言偈颂网格对齐 | ✅ 已有,且含按句折列、句间空一格(D6)、按联编码区段归并(2026-07-20 修复) | `verse_detector.dart` + `token_stream.dart` |
| 乌丝栏 + 默认开启开关 | ✅ 已有(反转存储防 isar 回填陷阱),开关只重绘不重排 | `hideColumnRules` + painter |
| 宣纸背景接口 | ✅ 已有,全局 shader 纸纹(InkPaperBackground),竖排页透明浮于其上 | `core/ink/shading/` |
| 传统字体加载接口 | ✅ 已有,异步字体注册完成自动重排 | `font_service.dart`(A8 机制) |

**本方案的全部新工作 = 第 4 种模式「竖排滚动」本体 + 一次两层化重构。**

## 1. 待决策项(已给推荐值,确认设计时可一并裁决)

| # | 决策点 | 推荐 |
|---|--------|------|
| DS1 | 滚动方向语义 | 与 D1 真右开本一致:列带向左延伸,**手指左→右滑 = 前进**(`reverse: true` 水平 ListView),如展开手卷 |
| DS2 | 底部页脚 | 竖排滚动**不显示页码**,仅保留卷轴进度条(与上下滚动模式一致;滚动模式"页"无意义) |
| DS3 | chrome 显隐 | **点按任意处切换**(无翻页点击分区——滚动模式不需要);不用滚动方向驱动(横向滚动语义易误触) |
| DS4 | 跨列反馈默认值 | **默认开启**(HapticFeedback.selectionClick 轻震),设置面板竖排滚动态显示「展卷反馈:开/关」;音效仅留接口不实现 |
| DS5 | 四档模式选择器 UI | 「翻页方式」从行尾 InkToggle 改为**标签下方整行 Wrap**(四档 ~300dp,窄屏手机行尾放不下):`上下滚动 | 左右翻页 | 竖排翻页 | 竖排展卷` |

## 2. 复用与重构方案(DRY 核心)

### 2.1 两层化重构:列带生成 ⇄ 页分组(唯一结构性改动)

现状:`VerticalPagination._paginate` 在 `addColumn` 内嵌页分组(满 colsPerPage 即 flushPage)。拆为:

```
第一层(新增,翻页/滚动共享)
  token 流(含 D5 连排缓冲/偈颂区段缓冲) → List<VStripItem> 列带
  sealed VStripItem = StripColumn(VColumn) | StripImage(url, blockIndex) | StripNav

第二层(现逻辑迁移,仅翻页用)
  列带 → 页分组:StripColumn 满 colsPerPage 成页;StripImage 独占页;StripNav 卷尾页
```

`VerticalPaginationResult` 增持 `strip`(列带)与 `firstColumnOfBlock`(块→列首现索引,与
firstPageOfBlock 同机制逐 token 记录);`pages` 由列带派生。**兼容性保证**:重构后翻页产物
与现产物结构一致,以 property test 锁定(任意样书:新旧管线 pages 的列序列/锚定完全相等——
迁移期临时保留旧实现对拍,通过后删除)。

缓存不变:同一 `VerticalPaginationKey` 下翻页与滚动**共享同一 Result**——竖排翻页 ⇄ 竖排展卷
互切零重排、零成本(LRU 容量 2 不动)。

### 2.2 绘制复用:提取共享绘列核心

`VerticalPagePainter._paintColumn`(字形网格 + 悬浮标点 + 偈颂行号 i+i÷n)提取为顶层函数:

```dart
void paintColumnGlyphs(Canvas canvas, VerticalGridSpec grid,
    VerticalPageStyles styles, GlyphCache glyphs, VColumn col, double originX);
```

- 翻页画师:按 `grid.colX(ci)` 逐列调用(行为不变,golden 不变);
- 新增 `VerticalColumnPainter`(滚动条目画师):单列调用 `originX = 0`,并在条目内右侧
  间隙画乌丝栏(见 §3.2)。`GlyphCache`/`VerticalPageStyles` 原样共享(跨模式同一份缓存)。

### 2.3 直接复用清单(零改动)

grid_geometry(全部公式)、token_stream、verse_detector、GlyphCache、VerticalPageStyles、
标点校准表、BlockJumpController、blockIndex 进度锚定协议、reader_page 回调协议、
InkBloomReveal 转场命中修复、NaN 防御。

## 3. 「竖排滚动」本体设计

### 3.1 视图结构(高性能路线)

```
VerticalScrollReader (ConsumerStatefulWidget,镜像 VerticalReader 骨架)
└─ ListView.builder(
     scrollDirection: horizontal, reverse: true,   // DS1:列带向左延伸
     physics: ColumnSnapPhysics(metrics),           // §3.3
     itemExtentBuilder,                             // 列=colPitch;图片=视口宽;nav=视口宽
     itemBuilder: StripColumn → CustomPaint(VerticalColumnPainter)
                  StripImage  → 现有 CachedNetworkImage 页
                  StripNav    → PrevNextNav)
```

- 惰性构建 O(视口):任意长卷内存恒定;单条目绘制 ≤62 个缓存字形,远轻于翻页模式的整页;
  ListView 默认逐条 RepaintBoundary,滚动 = 合成平移 + 增量建条,Impeller 上优于翻页转场。
- 条目局部坐标(列条目宽 = colPitch):字面框 `[0, cellW]`,右侧间隙 `[cellW, colPitch]`
  自含悬浮标点区与乌丝栏——**标点与界线绘制完全落在自身条目内,无跨条目依赖**。

### 3.2 乌丝栏(滚动形态)

每个列条目在自身右间隙 `x = cellW + 0.62·gap` 画一条(与 §6 分区公式同源);
**列带首列(index 0,最右)不画**——两端界线语义与翻页一致;开关沿用 `showColumnRules`,
仅重绘不重排。

### 3.3 列级吸附物理:`ColumnSnapPhysics`

```dart
class ColumnSnapPhysics extends ScrollPhysics {
  final SnapMetrics metrics;  // 条目起点偏移前缀表(全列均宽时退化为 O(1) 取模)
  createBallisticSimulation(position, velocity):
    1. 越界 → super(交还边界回弹/钳制);
    2. FrictionSimulation(拖拽系数同 ClampingScrollSimulation 手感).finalX → 自然停点;
    3. metrics.nearestBoundary(自然停点) → 目标列边缘(钳制到 [min, max]);
    4. 距离极小或零速 → ScrollSpringSimulation 微调归位;
       否则 FrictionSimulation.through(当前, 目标, v0, v≈0) —— 摩擦手感、精确停在列边缘。
}
```

- 边界表:`SnapMetrics` 由列带条目宽前缀和构建(纯列书 = 均匀 colPitch,O(1);含插图书 =
  二分最近边界);重排(key 变化)时随 Result 重建。
- 静止必对齐:`maxScrollExtent` 本身按条目宽求和,天然是列边缘;`nearestBoundary` 结果
  恒 ∈ 边界表 → 屏幕左右缘不可能停出半列。
- 断言:A-VS1 `nearestBoundary(x) ∈ boundaries`;A-VS2 均匀路径与二分路径同输入同输出。

### 3.4 跨列触觉/听觉反馈

- 监听 `ScrollController.offset`:前进沿列计数 `lead = (offset / colPitch).floor()`
  (含图片项时经 SnapMetrics 折算);`lead` 变化即一次「展现新列」。
- 触发:`HapticFeedback.selectionClick()`,**40ms 节流**(快速惯性滑动跨数十列时不
  机枪式连震);同一节流点调用音效接口。
- 音效接口(预留不实现):`typedef ScrollFeedbackSound = void Function();`
  经 `VerticalScrollReader(soundHook: ...)` 注入,默认 null。
- 设置:`AppSettings.muteScrollFeedback = false`(**默认开启反馈**;bool 旧行回填 false
  恰为默认开——正向命名反转语义,同 hideColumnRules 模式);面板竖排滚动态显示
  「展卷反馈 开/关」行。

### 3.5 状态管理与模式接入

- `readingMode` 第 4 值 `'verticalScroll'`;getter `isVerticalScroll`(空串回填规则沿用:
  只做 == 比对);`isVertical` 语义不变(仅翻页),新增 `usesVerticalEngine = isVertical || isVerticalScroll`。
- 竖排专属设置行(乌丝栏/标点/字间/行间)显示条件从 `isVertical` 改为 `usesVerticalEngine`;
  展卷反馈行仅 `isVerticalScroll` 显示;四档选择器按 DS5 改 Wrap。
- shell(reader_page)第 4 分支:复用 `_pagedController`(BlockJumpController)、
  `_onPagedBlockChanged`、进度回调;TOC/书签/进度恢复的「块跳转模式」判定并入
  `usesVerticalEngine || isPaged`。页脚按 DS2 不显示页码。
- 跳转:`jumpToBlock(b)` → `firstColumnOfBlock[b]` → `SnapMetrics.offsetOf(column)` →
  `animateTo`(落点即列边缘,天然对齐);旋转/字号变化 → 同现有 key 机制重排后按锚块还原。

## 4. 边界与断言

| # | 场景 | 处理 |
|---|------|------|
| B1 | 空书/单列书 | 列带兜底 ≥1 条目;maxExtent < 视口时物理直接钳 0(不吸附) |
| B2 | 视口宽非 colPitch 整数倍 | 吸附以**内容右缘**(阅读起点侧)为基准线,左缘允许出现部分列(展卷语义:左侧是"尚未展开"的卷) |
| B3 | 插图条目(视口宽) | 边界表含其两缘;跨图反馈只计 1 次 |
| B4 | 极端字号(A1 兜底钳制) | grid 已保证 colPitch 有限非零;物理层 assert(colPitch > 0) |
| B5 | 反馈开关热切换 | 仅影响监听回调,零重绘零重排 |
| B6 | isar 新字段回填 | muteScrollFeedback(bool→false=默认开 ✓);无新增 double 字段,NaN 陷阱不适用 |

## 5. Checklist(实施任务清单,逐项交付+汇报)

- [x] **V1 两层化重构**:VStripItem 列带层 + 页分组层;新旧管线对拍 property test 全绿后删旧实现;翻页 golden/全量测试零变化
- [x] **V2 绘列核心提取**:paintColumnGlyphs 共享;VerticalColumnPainter(单列+右隙乌丝栏);列条目 golden
- [x] **V3 SnapMetrics + ColumnSnapPhysics**:均匀/含图两路;ballistic 落点∈边界表的模拟单测(多组初速)
- [x] **V4 VerticalScrollReader 视图**:ListView(reverse)+itemExtentBuilder+条目分派;jumpToBlock/进度回调;chrome 点按
- [x] **V5 跨列反馈**:lead 列计数+40ms 节流+haptic+音效接口;muteScrollFeedback 设置行
- [x] **V6 状态接入**:readingMode 第 4 值、getter、四档 Wrap 选择器、shell 分支、竖排设置行条件放宽
- [x] **V7 测试补全**:物理吸附单测、反馈计数单测、widget 冒烟(方向/吸附/跳转/回调)、设置联动、四模式互切进度不漂移
- [x] **V8 真机验证**:滚动手感/吸附/震动、含偈颂页视觉推演截屏、profile timeline 采样(tool/perf.ps1 管线,fling 连滚)
- [x] **V9 文档与收尾**:方案勾记、母文档交叉引用、提交推送

**每步交付物**:代码 + 对应测试绿 + (V2/V4/V8)坐标/视觉推演;性能红线沿用 §6.1 瞬时事件口径。

## 6. 风险

| 风险 | 缓解 |
|------|------|
| 重构破坏翻页现状 | V1 对拍测试先行,golden+217 项存量测试作回归网 |
| itemExtentBuilder 与自定义 physics 协作的滚动度量偏差 | SnapMetrics 为唯一度量真源,物理与条目宽同表驱动;widget 测试断言静止 offset ∈ 边界表 |
| 快速 fling 跨列反馈过频 | 40ms 节流 + 只在 lead 单调前进时触发 |
| Impeller 长列表首滚建条尖峰 | cacheExtent 适度(2 屏);条目绘制本身 ≤62 字形,建条成本低;V8 timeline 验证 |
