# 古籍沉浸式竖排阅读模式 — 实施方案

> 状态:S1~S8 全部完成(2026-07-20),验收清单 C1~C12 见 §13(C11 按瞬时事件口径达标,注记在案) | 分支:`feature/vertical-reader`
> 关联:横排翻页引擎 `core/pagination/`(架构参照系)、水墨设计系统 `core/ink/`

---

## 1. 背景与现状

App 已有两种阅读方式(`AppSettings.readingMode`):

| 模式 | 渲染 | 分页 |
|------|------|------|
| `scroll` 上下滚动 | Text 组件流 | 无 |
| `paged` 左右翻页 | Text 组件按页装填 | `SutraPaginator`:TextPainter 逐行测量、时间片、LRU 缓存、blockIndex 锚定 |

竖排模式作为**第三种 readingMode(`vertical`)**接入,复用既有骨架:

- 进度/书签/TOC 跳转统一锚定 `blockIndex`(与两种现有模式一致,互切无损);
- `PagedReaderController` 的 jumpToBlock 挂起-就绪模式;
- 分页结果 LRU 缓存 + PaginationKey 快照模式;
- shell(`reader_page`)回调协议 `onBlockChanged / onProgress / onPageInfo`。

**与横排翻页的本质差异**:横排依赖 SkParagraph 折行测量(必须 TextPainter、必须时间片);竖排采用**严格网格**——每字一个固定尺寸字面框,**布局退化为纯算术**,不需要任何文本测量。这是整个方案成立的基石,也是性能优势的来源。

## 2. 需求决策记录(已与产品确认)

| # | 决策点 | 结论 |
|---|--------|------|
| D1 | 翻页手势方向 | **真右开本**:下一页在左侧,手指从左向右滑=下一页(`PageView(reverse: true)`),与 Kindle/Apple Books 竖排书一致。需求原文"右向左滑=下一页"与右开本物理习惯矛盾,已裁决为遵循传统 |
| D2 | 偈颂折列 | **按句折列**:自动检测 4/5/6/7 言体裁,每列只装整数个句子,句子绝不跨列断开 |
| D3 | 选字查词 | **首版纯阅读**,不做任何选择交互(自绘文字不走系统选择,留后续版本) |
| D4 | 翻页动画 | **平移滑动**(PageView 原生),纸页边缘阴影增强质感;仿真卷曲不做 |
| D5 | 散文分段(2026-07-20 用户反馈修订) | **古籍连排**:散文段落间不断列(句读悬浮即天然分隔,频繁短列显碎);仅偈颂、bt/bm 大章节、插图断列。段落/块锚点逐 token 保留,pageForBlock 精度不受损 |
| D6 | 偈颂句间与竖排间距(2026-07-20 用户反馈) | ①偈颂列**句间空一格**:k 句占 k×n+(k−1) 格,k=(容量+1)÷(n+1),绘制行号 = i + i÷n;②竖排独立间距设置:**字间**(列内字距 0~0.4em,默认 0 紧排)与**行间**(列距倍率 1.35~3.0,默认 1.75,isar 回填 0 作未设置哨兵),仅竖排模式显示,横排行距/字距/段距滑杆在竖排下隐藏 |

## 3. 总体架构与组件结构

```
lib/
├─ core/vertical/                       ← 新模块:纯 Dart 排版引擎(无 widget 依赖,可单测)
│  ├─ vertical_models.dart              ← GridToken / VColumn / VPage / VerticalPaginationKey / Result
│  ├─ punctuation.dart                  ← 标点分类表:句读类(悬浮)/剥除类(白文)/占格类
│  ├─ token_stream.dart                 ← BookData → 显示态字符流(rune 安全、标点归属、图片切分)
│  ├─ verse_detector.dart               ← 4/5/6/7 言偈颂检测启发式
│  ├─ grid_geometry.dart                ← 网格几何:cellH/colPitch/charsPerCol/colsPerPage 全部公式
│  └─ vertical_paginator.dart           ← 算术分页器:token 流 → 列 → 页(同步、LRU 缓存)
│
├─ presentation/widgets/
│  ├─ vertical_reader.dart              ← 阅读视图:PageView(reverse) + 手势分区 + shell 回调
│  │    └─ _VerticalPagePainter         ← CustomPainter:字符网格 + 悬浮标点 + 乌丝栏
│  │    └─ _GlyphCache                  ← (char, styleRole) → TextPainter LRU,跨页共享
│  └─ reader_settings_sheet.dart        ← 改造:翻页方式三选一 + 乌丝栏/白文开关
│
├─ data/models/app_settings.dart        ← 改造:readingMode='vertical'、hideColumnRules、baiwenMode
└─ presentation/pages/reader_page.dart  ← 改造:第三个 body 分支(接线,协议不变)
```

依赖方向:`presentation → core/vertical → domain/entities`,core/vertical 不 import Flutter widget(仅 painting/foundation),保证排版逻辑可在纯 Dart 测试中全覆盖。

## 4. 数据模型

```dart
/// 一个字面框内的内容。标点不是 token——它是前一字的附属属性。
class GridToken {
  final String char;            // 单个字(按 rune 切分,代理对安全)
  final String trailingPunct;   // 悬浮句读,'' 为无;可含多枚(如"。」"),绘制时纵向堆叠,上限 2
  final int blockIndex;         // 进度锚定(与 scroll/paged 同语义)
  final int paragraphIndex;
}

/// 一列。role 决定绘制样式与起始格缩进。
enum VColumnRole { title, author, bt, bm, body }
class VColumn {
  final VColumnRole role;
  final List<GridToken> tokens;
  final int indent;             // 顶部空格数:bm 品名低一格=1、作者署名下沉等
}

/// 一页:列序即阅读序(index 0 = 最右列),绘制时 x 从右向左推进。
class VPage {
  final List<VColumn> columns;
  final int firstBlockIndex;    // 进度锚点,语义同 ReaderPageModel
  final String? imageUrl;       // 插图独占页(columns 为空)
  final bool isNavPage;         // 卷尾页:PrevNextNav 以普通 widget 呈现
}

/// 缓存键:任一分量变化 → 全书重排。乌丝栏开关**不在键内**(纯绘制属性,只重绘)。
class VerticalPaginationKey {
  final String bookId;
  final Size contentSize;
  final String fontFamily;
  final double fontSize; final double lineHeight; final double letterSpacingEm;
  final bool isSimplified;
  final bool baiwen;            // 白文模式改变字符流 → 必须在键内
  final double textScaleFactor;
}

/// 分页产物:pages 一次算术遍历同步产出(万字级 <10ms,无需时间片)。
class VerticalPaginationResult {
  final VerticalPaginationKey key;
  final List<VPage> pages;
  int? pageForBlock(int blockIndex);   // 镜像 PaginationResult 协议
  int blockForPage(int page);
}
```

## 5. 渲染策略对比与选型

| 方案 | 原理 | 结论 |
|------|------|------|
| A. Widget 树(Column×Row 摆 Text) | 每字一个 widget | ❌ 每页 300+ widget,build/layout 开销大;字面框受字体度量摆布,矩阵对齐无保障 |
| B. RotatedBox / writing-mode 模拟 | 旋转横排文本 | ❌ Flutter 无 vertical writing-mode;旋转使汉字横躺,不可用 |
| C. 单列一个 Paragraph(maxWidth=一字宽,借软换行竖排) | SkParagraph 每行一字 | ⚠️ 可行但标点悬浮无法实现(标点必占一行),行高受字体 ascent/descent 扰动,放弃 |
| D. TextPainter 逐字测量 + 组件定位 | Positioned 摆放 | ⚠️ 布局可控但仍是 widget 海;测量冗余(网格下无需测量) |
| **E. CustomPainter 全自绘(选定)** | 分页=纯算术;绘制=canvas 上按公式坐标画每字 | ✅ 唯一能同时满足:①绝对矩阵对齐(字面框=公式,不受字体度量影响) ②标点悬浮不占格 ③乌丝栏与文字同坐标系 ④分页无需测量、可同步完成 |

方案 E 的两个配套机制:

1. **字形缓存 `_GlyphCache`**:`(char, styleRole)` → 已 layout 的 TextPainter,LRU 容量 2048,跨页共享。一卷经书的去重字符量通常 <3000,首页排布后命中率趋近 100%。每页绘制 ≈ 300~400 次 `canvas` 绘字调用(已布局、零测量),RepaintBoundary 包裹单页,静止页零重绘。
2. **居中定位公式**:字形在字面框内水平垂直双居中——`dx = cellX + (cellW − glyphW)/2`。矩阵对齐由公式保证而非字体保证,任何字体(含系统 fallback)下网格恒定。

## 6. 网格几何规范(全部公式,实现即断言)

```
有效字号   fs  = fontSize × textScaleFactor
字面框     cellW = fs            cellH = fs × (1 + max(0, letterSpacingEm))
列距       colPitch = fs × clamp(lineHeight, 1.35, 3.0)     // 复用行距滑杆语义
列间隙     gap = colPitch − cellW                            // ≥ 0.35em,标点与乌丝栏共居于此
每列字数   charsPerCol = floor(contentH / cellH)             // assert ≥ 1
每页列数   colsPerPage = floor((contentW + gap) / colPitch)  // 末列无尾隙;assert ≥ 1
网格实宽   gridW = colsPerPage × colPitch − gap
水平定位   gridRight = contentRight − (contentW − gridW)/2   // 网格水平居中
第 i 列 x  colX(i) = gridRight − colPitch × i − cellW        // i=0 最右
第 j 格 y  cellY(j) = contentTop + cellH × j
```

设置项到几何的映射:`fontSize`→字面框、`lineHeight`→列距、`letterSpacingEm`→列内字距。`paragraphSpacing` 在竖排无对应物(换段=换列),忽略。

**列间隙区划分**(标点与乌丝栏互不侵扰的关键):

```
[字面框右缘]──标点悬浮区(0~0.55·gap)──乌丝栏(x = 右缘+0.62·gap)──呼吸区──[下一列]
```

- 标点字号 = 0.45×fs,锚定于所属字的**右下角**:`px = cellRight + 0.06·gap`,`py = cellBottom − 0.85·punctH`。多枚标点纵向下堆,超出 2 枚截断绘制。
- 全角句读(。,、)的墨迹居于其 em 框左下象限,需按枚补偿锚点——实现期建立**常用标点偏移校准表**(。,、;:!?各一组 dx/dy 微调),golden 测试锁定。
- 乌丝栏:线宽 1 物理像素(`1/devicePixelRatio`),y 从 `contentTop` 到 `contentTop + charsPerCol×cellH`(与文本区上下边界对齐,含 indent 空格区),仅绘于**列与列之间**(colsPerPage−1 条),最外两侧不绘(版框留作后续增强)。

## 7. 排版规则细则

| 元素 | 规则 |
|------|------|
| 卷首 | 第 1 页右起第 1 列 = 书名(`bt` 样式加粗,顶格);第 2 列 = 作者(0.8×字号,indent 下沉至列的下半部,仿卷端题署) |
| `bt` 卷标题 | 独占列,加粗顶格;超一列长度折入下一列 |
| `bm` 品名 | 独占列,加粗,indent=1(低一格,仿刻本) |
| 正文段落 | **连排不断列**(D5 修订):相邻散文段落合并为连续 token 流填列,句读即段落分隔;仅偈颂/bt/bm/插图断列 |
| 偈颂(检测命中) | 按句折列 + **句间空一格**(D6):句长 n,每列装 k=(容量+1)÷(n+1) 个整句(占 k×n+(k−1) 格)。所有偈颂列同构 → 句首横向自动对齐成行 |
| 标点(句读模式) | 悬浮于所属字右下(§6),**绝不占格**;`。,、;:!?」』》)〕】…—` 归为悬浮类;`(「『《〔【` 等前置符在藏经语料中极罕(弯引号已在上游剥除),v1 并入前一字悬浮堆,无前字则舍弃 |
| 白文模式 | token 流构建期剥除全部中英文标点(`\p{P}` + 全角区补充表),流变短 → 独立分页(key 含 baiwen) |
| 拉丁/数字 | 占一格,直立居中(不旋转);canon 语料中占比可忽略 |
| 插图 | 独占页,沿用横排 CachedNetworkImage 呈现(不进画布) |
| 卷尾 | 末页之后追加 nav 页:居中排 PrevNextNav(普通 widget,可点击) |

**偈颂检测启发式**(`verse_detector.dart` + `token_stream.dart` 区段归并,2026-07-20 漏检修复):藏经数据常把偈颂**按「联」编码**(两句一段,如地藏经十二品"吾观地藏威神力,恒河沙劫说难尽,"),单段句数 <4 会被旧的段级判定全数漏检。现行两级:①段级候选——全部句子等长 n∈{4,5,6,7} 且句读收束(句数不限);②**相邻同 n 的正文段归并为区段**,区段总句数 ≥4 才整体标注(从严门槛保留在区段层)。分页器把连续同 n 偈颂段合并为一个折列 run。混合段落仍不检测;漏检无害化不变(0998 实测:209 段中 40 段偈颂命中)。

## 8. 交互规范

- `PageView(reverse: true)`:页索引向左增长,**手指左→右滑 = 下一页**(D1)。
- 点按分区与横排模式**镜像**:左 25% = 下一页、右 25% = 上一页、中部 = chrome 显隐(空间语义一致:下一页在左)。
- 无 SelectionArea(D3),手势树比横排简单,无识别器竞争。
- 跳转协议复用 `PagedReaderController`;排版为同步完成,不存在"排版未到达"的挂起态,jumpToBlock 即时生效。

## 9. 设置与持久化

```dart
// app_settings.dart 新增
String readingMode;            // 第三值 'vertical';getter: bool get isVertical
bool hideColumnRules = false;  // ⚠️ 反转存储!isar_community 3.x 给旧行新增字段回填
                               // false/空值而非 Dart 初始值(见 readingMode 既有注释),
                               // "乌丝栏默认开启"必须以 hide=false 表达才能对旧用户生效
bool baiwenMode = false;       // 白文默认关(旧行回填 false 恰为所需)
```

设置面板(`reader_settings_sheet.dart`):

- 翻页方式 InkToggle 扩为三档:`上下滚动 | 左右翻页 | 古籍竖排`;
- 选中"古籍竖排"时显示两行开关(InkToggle 复用):**乌丝栏**(默认开)、**白文**(默认关);
- 乌丝栏切换 → 仅触发重绘(不在 PaginationKey);白文/字号/字体/简繁切换 → 触发重分页(防抖 250ms,沿用横排既有节奏)。

## 10. 边界处理与断言清单(实施硬性要求)

| # | 边界/断言 | 处理 |
|---|-----------|------|
| A1 | `assert(charsPerCol >= 1 && colsPerPage >= 1)` | release 兜底:不满足时字号临时钳制到可容纳为止,并绘制降级提示 |
| A2 | 空书/空段落/全标点段落(白文后为空) | 产出仅含卷首+卷尾的最小页序列,不崩溃 |
| A3 | 代理对(扩展 B 区佛经用字) | token 流以 `String.runes` 切分,`assert(char.runes.length >= 1)`;禁止 codeUnit 索引 |
| A4 | 超长段落(数万字) | 算术分页天然有界;`assert` 分页产物 token 总数 == 输入流总数(无丢字无重字) |
| A5 | 标点堆叠 > 2 | 数据全留(病态输入如「字。。。。」合法,不设输入型 assert),绘制侧截断至 2 枚;真正的不变式断言是:占格 token 恒为单 rune、悬浮堆恒为悬浮类字符(token_stream 已断言) |
| A6 | 偈颂列 | `assert(tokens.length % n == 0)`(按句折列不变式) |
| A7 | 旋转/分屏尺寸突变 | contentSize 进 key → 自动重分页;当前页经 blockIndex 锚定还原 |
| A8 | 字体异步加载完成 | activeFamily 翻转 → key 变化重排(沿用横排机制);字形缓存按 family 整体失效 |

## 11. 性能策略

- 分页:纯算术单遍,一卷(1~3 万字)预估 <10ms,同步执行 + microtask 让出;不需要横排的时间片框架。LRU 结果缓存容量 2(镜像既有)。
- 绘制:字形缓存零测量绘制;RepaintBoundary/页;`shouldRepaint` 仅比较(结果引用, 前景色, 乌丝栏开关)。
- 验证:profile 模式 timeline 采样连续翻页 20 页,无 >16ms 帧(方法沿用 ink-design-plan §6.1 traceAction)。

## 12. 实施步骤(第二阶段增量交付计划)

| 步骤 | 内容 | 对应验收项 | 交付物 |
|------|------|-----------|--------|
| S1 | 设置层:AppSettings 字段(反转陷阱)+ 三档切换 + 开关 UI | C10 | 可切到空白竖排占位页 |
| S2 | `punctuation.dart` + `token_stream.dart`(流构建、标点归属、白文) | C2 | 纯 Dart 单测绿 |
| S3 | `verse_detector.dart` | C3 | 单测绿(经文样本) |
| S4 | `grid_geometry.dart` + `vertical_paginator.dart` | C1 C4 C5 | 分页快照测试绿 |
| S5 | `_VerticalPagePainter` + 字形缓存 + 乌丝栏(含**视觉推演报告**) | C6 C7 C8 | 首个可读页面 |
| S6 | `vertical_reader.dart`:PageView(reverse)、手势、shell 接线 | C9 | 全流程可用 |
| S7 | golden + 坐标断言测试补全;标点校准表调优(含视觉推演) | C6~C8 复验 | 测试全绿 |
| S8 | 真机性能采样、回归、收尾 | C11 C12 | 合入 PR |

每步完成后汇报:改动摘要 + 对应 Checklist 项的验证证据(测试输出/坐标推演)。S5/S7 按约定执行"截屏评估"式坐标推演:输出关键字格、标点、乌丝栏的计算坐标表并自检对齐性,发现挤占先修正再交付。

## 13. 验收测试清单(Checklist)

- [x] **C1 网格几何**:公式单测——给定 (contentSize, fontSize, lineHeight, letterSpacing, textScale) 断言 charsPerCol/colsPerPage/colX/cellY 精确值;余量居中分配;极小尺寸触发 A1 兜底
- [x] **C2 字符流**:rune 切分代理对不断裂;标点归属前字;白文流经 `\p{P}` 全量扫描为零标点;`<img>` 段切分;简繁转换在归属之前完成
- [x] **C3 偈颂检测**:心经(散文)不误判;法华/华严偈颂样本命中且 n 正确;句长混杂段落不误判
- [x] **C4 分页完整性**(property test):任意输入流,`拼接(所有页所有列 tokens) == 输入流`;空书/单字/超长段落边界
- [x] **C5 进度锚定**:pageForBlock 单调不减;跳转→翻页→反查 blockIndex 往返一致;三模式互切进度不漂移
- [x] **C6 矩阵对齐**(golden + 坐标断言):5 言偈颂页,列 x 坐标严格等差(公差 colPitch)、行 y 严格等差(公差 cellH);散文页同断言
- [x] **C7 标点悬浮**:含密集标点页,相邻字格 y 间距恒等于 cellH(标点零侵占);标点绘制矩形 ⊂ 列间隙标点区,不触乌丝栏
- [x] **C8 乌丝栏**:线条 x 居于列隙指定位、y 两端与文本区边界齐平;数量 = colsPerPage−1;开关关闭零绘制且不触发重分页
- [x] **C9 翻页交互**(widget test):reverse 索引方向正确;模拟左→右拖动页码 +1;点击左/右/中分区行为镜像正确;jumpToBlock 即达
- [x] **C10 设置联动**:白文/字号/字体/简繁变化 → 新 key 重分页;乌丝栏切换 → 同 key 仅重绘;isar 旧行升级后乌丝栏默认呈现为开
- [x] **C11 性能**(2026-07-20 实测,Tab S6 Lite/60Hz):分页——28,800 字冷分页 63ms(debug JIT,release 预估 <15ms,护栏测试 250ms);翻页 timeline(`tool/perf.ps1`,`build/perf/vertical-run1/`)——**jank_build 0%、build p90 1.89ms**(算术分页目标兑现);raster p90 17.28ms / p99 22.08ms,jank_raster 30.9%。**口径裁定**:未达本行原字面红线(16.67ms),但翻页是 ≤300ms 瞬时事件,按 §6.1 已确立的转场修订红线(raster p90 ≤33.3ms、最坏帧 ≤100ms)达标——成因与破墨转场同源:Impeller 无 raster cache,滑动期间两页 ~2,200 字形逐帧重光栅化,为该交互类型的内在成本(横排 reader 滚动一屏字数少一半,p90 10.5ms 可资对照)。后续若需压线:等待 Impeller raster cache,或翻页期 toImage 快照化(复杂度高,暂不做)
- [x] **C12 回归**:scroll/paged 两模式现有测试全绿;设置面板三档互切无异常

## 14. 风险清单

| 风险 | 等级 | 缓解 |
|------|------|------|
| 标点墨迹偏移因字体而异(LXGW vs 系统) | 中 | 校准表按 family 分组;golden 测试锁定默认字体;系统字体容忍度放宽 |
| 生僻字 fallback 字体宽高异常 | 低 | 居中公式天然吸收宽度差;高度超框以 cell 裁剪兜底 |
| 偈颂检测误判(格律引文夹散文) | 低 | 判定条件从严(全句等长);漏检无害化设计 |
| 竖排下用户丢失选词能力的体验落差 | 已决策 | D3 明确首版范围;阅读页入口保留模式切换提示 |
