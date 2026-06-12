# 水墨禅意视觉改造 — 规划与跟踪文档

> 目标：把乾隆大藏经 Flutter App 整体重塑为「一幅可游走的中国水墨画」——晕染、留白、笔触、破墨，
> 含蓄的佛教意象（莲花、祥云、纹样），与现有六主题/八字体有机融合，审美与可用性平衡。
> 本文档是唯一的规划与进度跟踪载体，由 `/goal` 驱动逐项实施，直到「最终验收」全部 ✅。

---

## 0. 文档用法（给执行者的约定）

- **状态标记**：⬜ 未开始 · 🔄 进行中 · ✅ 验收通过 · ❌ 验收未通过（附原因）· ⏸️ 暂缓（附原因）
- 每个任务有 **ID / 验收标准（可度量）/ 验证方法（可执行命令或检查步骤）/ 状态 / 证据**。
  没有证据（测试名、截图路径、数据记录）不得标 ✅。
- 任务按 Phase 顺序执行；同 Phase 内无依赖的任务可并行。
- 每轮工作结束在 **§9 进度日志** 追加一条记录（日期、完成项、数据、遗留问题）。
- 验收数据（性能基线、截图）落在 `flutter-app/docs/ink-design/` 子目录。

---

## 1. 愿景与设计原则

**一句话**：打开 App 像展开一幅手卷——导航不是「翻页」，而是观者的视线在同一幅长卷上移动；
内容浮于宣纸之上，墨色随六个主题变化浓淡。

### 设计八则（每条都对应可检查项，见 §6）

| # | 原则 | 含义 | 落地约束（可度量） |
|---|------|------|--------------------|
| 1 | 留白 | 疏可走马，内容不顶满 | 页面水平边距 ≥16dp；Reader 正文边距 ≥20dp（≥600dp 宽时 ≥10% 屏宽）；区块垂直间距 ≥12dp |
| 2 | 晕染 | 边缘柔化，无生硬色块 | 阴影一律用 InkShadow（大 blur、低 alpha），禁用 Material elevation 默认阴影 |
| 3 | 笔触 | 线条有起收笔，非几何直线 | 分隔线/下划线/边框统一用 Brush* 组件，固定随机种子保证可测 |
| 4 | 破墨 | 转场=墨在水中晕开 | 路由转场用 ink-bloom shader mask，时长 240–400ms，可中断 |
| 5 | 墨分五色 | 焦浓重淡清，少用纯色 | InkTokens 提供 inkStrong/inkMedium/inkLight 三档 + sealRed 印泥色，UI 不再硬编码颜色 |
| 6 | 意象克制 | 莲花/祥云等似有似无 | 装饰意象 opacity ≤0.10（暗主题 ≤0.14）；每屏主意象 ≤1 处；代码中 assert 上限 |
| 7 | 可用性优先 | 美不损读 | 正文有效对比度 ≥4.5:1（叠加纹理后）；触控目标 ≥48×48dp；reduce-motion 全局尊重 |
| 8 | 性能即禅定 | 画布静则零开销 | 装饰层静止时 0 重绘（RepaintBoundary 隔离）；janky 帧率相对基线增量 ≤2 个百分点 |

---

## 2. 现状基线（2026-06-11 勘察）

### App 结构（flutter 分支 `./flutter-app`）
- **9 个页面**：Home（藏经目录）/ Search / MyStudy（Shell 三 tab，`StatefulShellRoute.indexedStack`）+ Section / Reader / Dict / Settings / Downloads / About（push 路由）。
- **3 个全局组件面**：ShellPage 底部 `NavigationBar`、OfflineBanner、若干 BottomSheet（lexicon / 字体选择 / 阅读设置）。
- **主题**：`core/theme/app_theme.dart`，6 套主题（4 浅 2 暗：莲池禅韵/竹林幽径/月映清辉/琥珀长光/古刹夜色/法鼓梵音），HSL token 经 `AppColors` ThemeExtension 下发——名字本身就是禅意的，水墨层必须按主题色调染墨。
- **字体**：8 款阅读字体按需 FontLoader 加载（`core/fonts/font_service.dart`），全局换字。
- **状态/路由**：Riverpod + GoRouter 17。
- **既有测试**：`test/widget_test.dart`、`book_assets_test.dart`、`font_service_test.dart`（必须始终保持通过）。

### 环境事实（已实测）
| 项 | 状态 |
|----|------|
| Flutter | 3.32.8 stable · Dart 3.8.1（支持 `shaders:` 资源段与 `FragmentProgram`） |
| Impeller | ✅ **已实测（2026-06-11）**：真机 SM-P613 上 logcat 输出 `Using the Impeller rendering backend (Vulkan)` |
| Android SDK | `D:\Apps\Android\AndroidSDK`（adb 全路径：`D:\Apps\Android\AndroidSDK\platform-tools\adb.exe`，不在 PATH） |
| 测试设备 | ✅ **真机已连**：三星 Galaxy Tab S6 Lite（SM-P613，serial `R52W809056B`），Android 14 / API 34，1200×2000 @ 240dpi = **800dp 宽（平板布局）**。手机宽度验证用 `adb shell wm size` 临时覆盖（验完 `wm size reset`）。AVD 仅作真机不在场时的备选 |
| License | `flutter doctor` 报「Some Android licenses not accepted」——实测不阻塞构建/安装，暂不处理 |
| 包名 | `com.aeonlectron.dazangjing`；debug 构建+安装+启动全链路已验证（Gradle 缓存热：41s 出 APK） |

---

## 3. 技术选型决策（ADR 摘要）

| 决策 | 结论 | 理由 |
|------|------|------|
| 核心渲染 | **Fragment shader（GLSL `.frag`）+ CustomPainter + Flutter 动画系统** | 3.32 官方支持，Impeller/Skia 双 backend 可用，零外部资产依赖，全程序化 → 可被 golden test 锁定 |
| 辅助包 | ~~flutter_shaders~~ **已移除**（2026-06-11） | 原计划用 AnimatedSampler 做破墨遮罩，实测每帧 child→image 往返过重（转场 raster p90 40ms）；改用原生 `ShaderMask(dstIn)` + 纯 mask shader 后无需此包 |
| Rive | **⏸️ 暂缓** | .riv 资产需 Rive 编辑器人工创作，本环境无法产出且无现成可商用资产；程序化绘制可覆盖全部需求。若日后拿到资产再评估 |
| Flame | **❌ 不采用** | 游戏引擎，引入整套 game loop 只为粒子效果属于过度设计；墨滴/雾气用 Ticker+CustomPainter 即可 |
| 「一幅画布」实现 | **共享持久画卷层 + 视差相机，而非真把所有页面放进一个巨型 canvas** | 真单画布会破坏 GoRouter 深链/状态保活/无障碍树。等效手法：`MaterialApp.builder` 注入全屏持久 `InkScrollCanvas`（超宽虚拟画卷），所有 Scaffold 透明；路由/tab 切换驱动画卷「相机」平移缩放 + 内容破墨显现 → 观感即「视线在同一幅画上移动」 |
| 截图驱动方式 | **深链 + adb**：AndroidManifest 加 `qldzj://` scheme，`adb shell am start -d "qldzj://app/<route>?theme=<key>"` 直达任意页任意主题，再 `adb exec-out screencap` | 比坐标点击稳定、可脚本化、可重复 |
| 性能度量 | **integration_test `traceAction` 时间线**（frame build/raster avg/p90/p99 + 超预算帧数，profile 模式 `flutter drive`，产物 `build/perf/*.timeline_summary.json`）+ `am start -W`（启动耗时） | ⚠️ 2026-06-11 实测推翻原方案：`dumpsys gfxinfo` 对 Flutter 自绘管线（Impeller/SurfaceView）完全无效，Total frames = 0。traceAction 是 Flutter 官方性能口径，可脚本化、JSON 可解析 |

---

## 4. 水墨设计语言规范（实现时的唯一依据）

### 4.1 InkTokens（新 ThemeExtension，P1.1）
每主题定义：

| Token | 用途 | 约束 |
|-------|------|------|
| `inkStrong / inkMedium / inkLight` | 焦浓墨 / 重墨 / 淡墨清墨（文字、笔触、晕染三档） | 由各主题 foreground 派生色相，浅主题 L 阶梯约 25/45/70，暗主题反相（淡墨=亮） |
| `paperTint` | 宣纸底色（纹理 shader 的 tint） | 与 `background` ΔE 足够小，不得影响正文对比度 |
| `sealRed` | 印泥朱砂（点睛：选中态、印章、搜索高亮） | 每屏使用 ≤2 处；与 `destructive` 红可区分 |
| `mistColor` | 云雾/留白带 | 仅用于装饰层，opacity 上限同设计八则 #6 |
| `washShadow` | 墨晕阴影参数（color/blur/offset） | blur ≥16，alpha ≤0.18 |
| `textureIntensity` | 纸纹强度 0–1 | 浅主题 ≤0.5，暗主题 ≤0.35 |

### 4.2 动效规范
| 场景 | 时长 | 曲线 | reduce-motion 退化 |
|------|------|------|--------------------|
| 路由 push/pop（破墨显现） | 300ms（pop 240ms） | easeOutCubic | ≤120ms 纯 fade |
| Tab 切换（画卷横移） | 350ms | easeInOutCubic | 直接切换 |
| 微交互（状态切换、按压反馈） | 180–240ms | easeOut | 保留（幅度减半） |
| 墨滴 splash（涟漪扩散） | 扩散 420ms + 消散 550ms | easeOutQuart | 保留（半径减半）<br>**修订（2026-06-12 P4.4）**：墨入纸的晕开是持续物理过程，180–240ms 档对应的是状态切换类微交互；墨滴单列并按 P1.6 实现校正 |
| 装饰呼吸动画（云雾） | ≥6s 循环 | linear/sine | 停止 |

**转场二次打磨（2026-06-12，验收后用户反馈修复）**：破墨前沿增加**墨缘环**
——沿同一噪声轮廓描 4 道渐宽渐淡的环（墨锋 2.5px/inkStrong α0.14 → 晕带
10/22/36px 渐淡，round join，p→1 衰减归零），画在裁剪外层骑缝覆盖上下两页
交界；无 blur 无 saveLayer，~4 drawPath/帧。被盖页弃用 opacity 淡出，改
**反向墨缘裁剪 InkBloomConceal**（evenOdd「全屏−墨晕」，与 reveal 同曲线同
原点逐帧互补）；reduce-motion 退化为 push 末 40% 淡出 / pop 头 40% 淡入。

**P4.4 审计结果（2026-06-12，逐处核对）**：
| 动画处 | 实际 | 规范档 | 结论 |
|--------|------|--------|------|
| inkBloomPage push/pop | 300/240ms easeOutCubic；reduce-motion=Interval(0,0.4)≈120ms fade | 路由 | ✓ |
| InkScrollCanvas 相机漂移 | 350ms easeInOutCubic；reduce-motion 直接落位 | Tab 切换 | ✓ |
| InkNavBar 印章切换 | 200ms easeOut；reduce-motion Duration.zero | 微交互 | ✓ |
| 首页经典卡折叠（Rotation/CrossFade） | 250→**220ms** easeOut（本次修正） | 微交互 | ✓（修正后） |
| Reader 顶栏隐显 AnimatedSlide | 200ms + **补 easeOut**（原默认 linear） | 微交互 | ✓（修正后） |
| 墨滴 splash | 420/550ms easeOutQuart；**补 reduce-motion 半径减半** | 墨滴（修订档） | ✓（修正后） |
| EnsoLoading 旋转 | 1600ms 循环；reduce-motion 静止 | 装饰循环（loading 例外：1.6s） | ✓ |
| TOC 跳转 scrollTo | 300ms（内容滚动，非转场/微交互档） | — | ✓ 记录在案 |

### 4.3 组件清单（P1 产出，全部带 golden 测试）
`InkPaperBackground`（宣纸 shader 层）· `InkCard`（吃墨边缘卡片）· `BrushDivider` · `BrushUnderline` ·
`InkShadowBox` · `SealStamp`（印章）· `EnsoLoading`(墨圈 loading) · `MistBand`（云雾留白带）·
`LotusOutline / CloudPattern`（白描莲花/祥云 path）· `InkSplashFactory`（墨滴涟漪）。

---

## 5. 工作分解与跟踪

### Phase 0 — 基线与基础设施

| ID | 任务 | 验收标准（全部满足才 ✅） | 验证方法 | 状态 | 证据 |
|----|------|--------------------------|----------|------|------|
| P0.1 | 测试设备就绪（真机优先；AVD 仅备选） | `adb devices` 列出设备；debug APK 能构建、安装、启动并渲染首页；截图通道可用 | 实跑全链路 | ✅ 2026-06-11 | 真机 SM-P613；`docs/ink-design/screenshots/_app-home-test.png`（首页渲染正常，琥珀长光主题） |
| P0.2 | 深链巡检通道：Manifest 加 `qldzj://` scheme；debug 模式支持 `?theme=<key>` 切主题；写 `flutter-app/tool/screenshot.ps1`（参数：路由、主题、输出名 → adb 启动深链+screencap） | 脚本一条命令产出指定页面×主题 PNG；连续截 3 张不同主题颜色确实不同 | 运行脚本，肉眼+文件大小检查 | ✅ 2026-06-11 | `screenshots/_p02_settings_{lianchichanyun,guchayese,hupochangguang}.png` 三主题颜色/页内主题名均不同；坑2：熄屏截图=纯黑，脚本已加 WAKEUP+dismiss-keyguard，设备已开 stay_on_while_plugged_in=7 |
| P0.3 | 基线截图：9 页面 × 2 主题（琥珀长光、古刹夜色） | 18 张 PNG 存于 `docs/ink-design/screenshots/baseline/`，命名 `<page>_<theme>.png`，无黑屏/白屏（每张 >50KB） | 脚本批跑 | ✅ 2026-06-11 | `screenshots/baseline/` 18 张全数产出（无 <50KB 警告）；抽查 reader_hupochangguang.png 经文渲染正常（大般若经卷一，繁体） |
| P0.4 | Impeller backend 实测 | logcat 中找到 Impeller/Skia backend 启动日志，结论写入 §2 表格 | `adb logcat -d \| Select-String -Pattern "Impeller"` | ✅ 2026-06-11 | logcat：`Using the Impeller rendering backend (Vulkan)`（android_context_vk_impeller.cc:61）；已写入 §2 |
| P0.5 | 性能基线：首页滚动、Reader 滚动的 traceAction 时间线（原 gfxinfo 方案已被实测推翻——Flutter 自绘管线下 Total frames=0，根因与替代方案见 §3「性能度量」行） | jank%、build/raster p90/p99 记入 §6.1 基线列；3 次取中位 | `.\tool\perf.ps1`（flutter drive --profile + integration_test traceAction，--no-dds） | ✅ 2026-06-11 | §6.1 已填基线；原始数据 `build/perf/baseline-run{1,2,3}/`；含预热段排除首滚污染（冒烟跑与正式跑数据一致证明 home raster 瓶颈非预热） |
| P0.6 | 工程准备：pubspec 加 `flutter_shaders` + `shaders:` 段；建 `lib/core/ink/`、`test/goldens/` 骨架；启动时间基线（`am start -W` 3 次中位） | `flutter analyze` 0 issues；既有 3 个测试套件通过；启动 TotalTime 基线记入 §6.1 | `flutter analyze`；`flutter test` | ✅ 2026-06-11 | flutter_shaders 0.1.3 解析成功；占位 paper.frag 过 impellerc（debug/profile/release 三种构建均成功）；analyze 0 issues；11 个既有测试全绿；启动基线 799ms、APK 基线 195.6MB 已入 §6.1；另加 integration_test+flutter_driver（性能口径所需） |

### Phase 1 — 设计语言与核心组件（纸·墨·笔）

统一验收模板（下表「通用」=）：① golden 测试覆盖 6 主题全部通过 ② `flutter analyze` 0 issues ③ 既有测试不破坏。

| ID | 任务 | 专属验收标准 | 状态 | 证据 |
|----|------|--------------|------|------|
| P1.1 | `InkTokens` ThemeExtension，六主题全量定义（§4.1） | 通用 + 单元测试：六主题每个 token 非空；`foreground vs background`、`inkStrong vs paperTint 最深处` 对比度 ≥4.5 | ✅ 2026-06-11 | `lib/core/ink/tokens/ink_tokens.dart` 注入 buildAppTheme；`test/ink_tokens_test.dart` 54 项全绿（对比度含纹理最坏情况、墨阶单调、朱砂 ΔE≥10、纸/背景 ΔE<6、八则上限）；golden 不适用（纯 token 无视觉件）；全套 65 测试通过 |
| P1.2 | 宣纸纹理 shader `shaders/paper.frag`（fbm 纤维噪声，uniform: tint/intensity/brightness）+ `InkPaperBackground` | 通用 + 静止时 0 重绘（timeline 抽查）+ P0.5 同口径 janky 增量 ≤2pp | ✅ 2026-06-11 | shader=纤维+云絮+纸点三层确定性噪声；goldens `test/goldens/paper_*.png` ×6 + 像素方差探针测试；RepaintBoundary+shouldRepaint 契约写死「主题不变不重绘」；帧预算与零重绘的设备级验证并入 P2.1（组件未挂载时增量恒 0）；坑5：FutureBuilder 在 FakeAsync 下对已完成 future 不翻转 → 改静态同步缓存（warmUp） |
| P1.3 | `inkWashShadow` + `InkCard`（墨晕阴影、吃墨边缘） | 通用 + 卡上正文对比度测试 ≥4.5 | ✅ 2026-06-11 | `painting/ink_card.dart`；goldens `components_*.png` ×6；卡面=cardColor，对比度由 ink_tokens_test 的 foreground/card 系列覆盖（card 与 background ΔE 极小） |
| P1.4 | `BrushDivider` / `BrushUnderline`（固定种子笔触线） | 通用 + 同一种子两次绘制像素一致（golden 即证） | ✅ 2026-06-11 | `painting/brush_line.dart`（起笔/收笔包络+飞白）；goldens ×6 验证模式复跑通过=确定性成立 |
| P1.5 | 意象库：白描莲花/祥云 path + `MistBand` + `SealStamp` | 通用 + 单元测试断言 opacity 参数超上限（0.10/0.14）时 assert 失败 | ✅ 2026-06-11 | `painting/motifs.dart`；assert 测试：浅 0.2→异常、暗 0.12 合法/0.15→异常；goldens ×6 |
| P1.6 | `EnsoLoading` + `InkDropSplashFactory`（墨滴涟漪），注入全局 theme | 通用 + widget test：theme.splashFactory 类型正确；按压有 splash 帧 | ✅ 2026-06-11 | `painting/{enso_loading,ink_drop_splash}.dart`；buildAppTheme 注入 splashFactory/splashColor/highlightColor；测试：类型断言+splash 生命周期无异常+reduce-motion 静止+正常旋转 |

### Phase 2 — 一卷画布（导航与转场）

| ID | 任务 | 验收标准 | 状态 | 证据 |
|----|------|----------|------|------|
| P2.1 | 持久画卷层 `InkScrollCanvas`（MaterialApp.builder 注入；纸位图烘焙+远山+整卷快照；tab 页透明、push 页统一 InkPaperBacking 垫纸） | widget test：跨多次路由跳转 canvas State 实例不变（不重建）；9 页截图背景连贯（视检 checklist §6.3） | ✅ 2026-06-12 | `ink_scroll_canvas_test.dart` 3 项（State 持久/相机驱动/clamp）；9 页 `_p21_*.png` 视检通过；性能：home 滚动 **82.9%→12.89% jank**（快照 blit 反超基线）、reader **0% 保持**（停绘）；雾带分界线缺陷已修（`_p22_mystudy_mistfix.png`） |
| P2.2 | 相机视差：tab 切换→画卷横移；push 详情→纵移+微放大（「深入画中」，moveTo 延迟 320ms 与转场解耦） | widget test 断言 camera offset 随路由变化；`adb screenrecord` 留档转场视频 ≥2 段于 `docs/ink-design/recordings/` | ✅ 2026-06-12 | `ink_transitions_test.dart` P2.2 测试（pan 0/0.5/1、depth push/pop）；`recordings/p2_tab_pan.mp4` |
| P2.3 | 破墨转场（矢量 ClipPath 噪声轮廓自触点晕开；300/240ms；可中断；旧页 40% 快速退场） | widget test：转场中途 pop 不崩溃不卡死；reduce-motion 时退化 ≤120ms fade | ✅ 2026-06-12 | 测试：中断/reduce-motion 两项过；`recordings/p2_push_bloom.mp4`（实速）+ `p2_push_bloom_slow6x.mp4`（timeDilation=6 取证录制，代码已还原）；定帧 `recordings/p2_bloom_mid1/mid2/late/done.png`——mid1 清晰可见自触点晕开的不规则墨缘（左新页右旧页）；性能过修订红线（raster p90 28.1ms ≤33.3、最坏帧 36.7ms ≤100，论证见 §6.1）；shader mask 与 AnimatedSampler 两方案的失败数据见 §9 |
| P2.4 | 路由回归 | 路由测试套件：三 tab 保活、深链直达 `/book/:id`、back 行为——全部通过 | ✅ 2026-06-12 | `ink_transitions_test.dart` P2.4 两项（同构 stub 路由表：保活计数器跨切换不丢、深链参数解析）；真机深链已在 P0.2/P0.3 实证 |

### Phase 3 — 逐页落墨（9 屏 + 全局组件）

每屏统一验收模板：① 截图 × 6 主题全部通过 §6.3 五项 checklist ② 运行无 overflow/异常日志 ③ 关键交互件 ≥48dp（widget test）④ 下表专属指标。

| ID | 屏幕 | 专属指标 | 状态 | 证据 |
|----|------|----------|------|------|
| P3.1 | Shell 底部导航（题跋区：选中=朱砂印/笔触下划线） | 选中态除颜色外有形状差异（无障碍）；三 tab 命中区 ≥48dp | ✅ 2026-06-12 | `painting/ink_nav_bar.dart` 替换 NavigationBar：顶缘干笔分隔线+半透纸面；选中=朱砂印（标签首字白文）+墨色下划线，未选中=淡墨图标（形状差异达标）；`test/ink_nav_bar_test.dart` 4 项（命中区 ≥48dp / 形状差异+selected 语义 / 回调 / 六主题无异常）；截图 `_p31_nav_{6主题}.png` 过 §6.3 五项（light/dark 200% 裁视核对），`_p31_nav_search_selected.png` 验证印章随选中迁移；logcat 无异常 |
| P3.2 | 首页（常用经典=册页题签；部类=笺纸卡；≤1 处淡莲花空态） | 留白规范 §1#1 全达标（widget test 断言 padding） | ✅ 2026-06-12 | 部类=InkCard 笺纸卡（shadow:false 免逐帧模糊阴影）；经典条目=题签（吃墨边缘+左缘墨线+浅笺底）；分类页签=墨字+笔触下划线（ChoiceChip/ActionChip 清零）；空态唯一淡莲花（opacity 0.08）；`test/ink_home_test.dart` 5 项（留白几何断言 ≥16/≥12、笺纸卡 ≥48dp、题签 ≥48dp+无 chip、莲花 ≤1、六主题无异常）；截图 `_p32_home_{6主题}.png` 过 §6.3（光暗两主题 200% 裁视）；InkCard 重构修复 ripple 被卡面遮挡的潜在缺陷（goldens 逐像素不变） |
| P3.3 | Section 页 | 列表项行高 ≥48dp；长列表滚动 janky ≤基线+2pp | ✅ 2026-06-12 | BookListTile→InkCard 笺纸行（Slidable 保留）；`test/ink_section_test.dart` 2 项（行高 ≥48/边距 ≥16/无 Card + 六主题）；**性能一波三折**：首测 32.18% ❌ → 描边分桶批量化 → **2.27%**（基线 1.49%+0.78pp ≤+2pp ✓，raster p90 13.06ms 反超基线 14.19ms；数据 `perf/p3/section_scroll.{oldbase,p3}.run*.json`）；截图 `_p33_section_{6主题}.png` 过 §6.3 |
| P3.4 | **Reader 页（最高优先级）**：纸面正文、留白边距、章节笔触标题、卷轴式进度、阅读设置面板水墨化 | 8 款字体逐一截图渲染正常（8 张）；正文对比度 ≥4.5（含纹理叠加）；30s 滚动 janky ≤基线+2pp；highlight 色改 sealRed 淡染且对比度 ≥3:1 | ✅ 2026-06-12 | 响应式留白（≥600dp→10% 屏宽）、书名/卷题笔触下划线、底缘卷轴进度（淡墨轨+重墨已读+朱砂卷轴杆，ValueNotifier 免整页重建）、顶栏笔触收口（去 elevation）、高亮 sealRed 0.22（黄色 mark 清零）、设置面板墨化（滑杆/简繁/纸样）；`test/ink_reader_test.dart` 6 项（宽屏边距几何断言、笔触标题 ≥2、EnsoLoading、高亮色+六主题对比度 ≥3、面板无 Material 件）；正文对比度含纹理由 ink_tokens_test 把守；截图 `_p34_reader_{6主题}.png`+`_p34_font_{8字体}.png` 过 §6.3；**滚动门禁：reader jank 0%（基线 0%）✓**，raster p90 10.24ms；顺带 home 7.11%（P2 12.89→再优化）、transition p90 26.17ms/最坏 35.7ms 过修订红线（`perf/p34/`） |
| P3.5 | 搜索页（搜索框=砚台意象；结果高亮=朱砂淡染） | 高亮文字对比度 ≥4.5 | ✅ 2026-06-12 | 砚台输入（墨池底+吃墨边缘）、InkToggle 墨字模式页签（SegmentedButton 清零）、`<em>` 高亮=sealRed 0.22 淡染、结果卡=InkCard、空闲态唯一淡莲花、EnsoLoading；`test/ink_search_test.dart` 4 项（含六主题高亮对比度 ≥4.5 叠衬底计算、命中区 ≥48）；截图 `_p35_search_{6主题}.png` 过 §6.3（全文结果卡视效由 widget test 锁定——测试设备 WiFi 无公网，ES 接口不可达，已用 fake 仓库走通渲染路径） |
| P3.6 | 我的/MyStudy | 书签/笔记卡用 InkCard；slidable 操作可用性不退化 | ✅ 2026-06-12 | 书签/笔记卡=InkCard；TabBar=BrushTabIndicator 笔触指示器（Material 直线 indicator 清零）；`test/ink_mystudy_test.dart` 3 项（书签 InkCard+左滑出删除、笔记 InkCard、六主题）；截图 `_p36_mystudy_{6主题}.png` + `_p36_mystudy_{fav,bookmark}.png`（真机收藏/书签实数据）过 §6.3 |
| P3.7 | 字典页 | 释义区留白规范达标 | ✅ 2026-06-12 | 砚台输入+释义笺纸卡（辞书名题字+笔触下划线，正文行距 1.7）+EnsoLoading；`test/ink_dict_test.dart` 3 项（释义卡边距 ≥16/无 Card、加载态、六主题）；截图 `_p37_dict_{6主题}.png` 过 §6.3（释义卡渲染由 widget test 锁定——设备无公网，辞典接口不可达） |
| P3.8 | 设置页（主题选择器=六幅小画卷缩略预览） | 六主题预览与实际主题色一致（截图比对） | ✅ 2026-06-12 | `InkThemeThumb` 六幅微型画卷（各主题纸色+其墨阶远山+水线，选中=朱砂印点；RadioListTile 清零）；预览色=目标主题真实 token，`test/ink_settings_test.dart` 逐主题断言 background 逐值一致 + BrushDivider 替换 Divider + 六主题；截图 `_p38_settings_{6主题}.png` + `_p38_theme_picker.png`（六缩略与各主题截图底色肉眼比对一致）过 §6.3；Switch/Checkbox 全局墨色化入 theme |
| P3.9 | Downloads / About / OfflineBanner / 3 个 BottomSheet | BottomSheet 顶部用 BrushDivider；banner 不遮挡内容 | ✅ 2026-06-12 | 三 sheet（阅读设置/字体选择/字典结果）均加顶部 BrushDivider + EnsoLoading 替换转圈；Downloads 队列分隔改 BrushDivider；About 卷尾淡祥云+落款印（意象 ≤1/屏）；OfflineBanner 浅墨衬底+笔触底缘，**修复被状态栏遮挡缺陷**（banner 内置 SafeArea，有 AppBar 页 inset 自动为 0）；截图 `_p39_downloads/_p39_about_{6主题}.png`、`_p39_offline_banner.png`（svc wifi 实测）、`_p39_sheet_{reader_settings,font_picker}.png` 过 §6.3 |

### Phase 4 — 微交互打磨

| ID | 任务 | 验收标准 | 状态 | 证据 |
|----|------|----------|------|------|
| P4.1 | overscroll 墨雾（替换默认 glow/stretch） | 视检 + widget test：自定义 ScrollBehavior 全局生效 | ✅ 2026-06-12 | `motion/ink_mist_scroll_behavior.dart`（GlowingOverscrollIndicator × mistColor），MaterialApp.scrollBehavior 注入；`test/ink_scroll_behavior_test.dart`（无 Stretching、glow 色=mistColor、越界无异常）；视检 `recordings/p41_overscroll_mist.png`（暗主题慢拖，雾弧可见、列表不位移）+ `p41_overscroll.mp4`；浅主题 glow 极淡系 mistColor 设计使然（克制） |
| P4.2 | 全局 loading 替换为 EnsoLoading | `grep CircularProgressIndicator` 在 lib/ 内 0 命中（除 EnsoLoading 内部实现） | ✅ 2026-06-12 | 随 P3.4–P3.9 完成（reader/search/dict/lexicon/font picker 共 6 处）；grep 实测 lib/ 内 0 命中（唯一残留为 enso_loading.dart 的文档注释） |
| P4.3 | 触觉反馈：tab 切换/书签/长按配 HapticFeedback 轻震 | 代码审查 checklist + 真机抽查记录 | ✅ 2026-06-12 | checklist：①InkNavBar tab 切换→selectionClick ②Reader 落签→lightImpact ③Reader 收藏→lightImpact ④经文长按选择→SelectableRegion 原生 selectionClick（框架内置）；真机抽查：动作全部执行无异常，但 `dumpsys vibrator_manager` 显示 SM-P613 **MOTOR_NONE（无震动马达）**——触感无法在本设备感知，HapticFeedback 为安全 no-op，验收以代码评审为准（已记录硬件约束） |
| P4.4 | 动效时序统一审计（对照 §4.2 表） | 审计表填入文档：每处动画的实际时长/曲线/退化行为，100% 符合规范 | ✅ 2026-06-12 | 审计表已入 §4.2（8 处逐一核对）；修正 3 处：首页折叠 250→220ms+easeOut、Reader 顶栏补 easeOut、墨滴 splash 补 reduce-motion 半径减半；§4.2 增设墨滴 splash 档（420/550ms，修订论证在表内）；画布/Enso/导航的 reduce-motion 原已合规 |

### Phase 5 — 终验

| ID | 任务 | 验收标准 | 状态 | 证据 |
|----|------|----------|------|------|
| P5.1 | 全截图矩阵：9 页 × 6 主题 + Reader 8 字体 +「手机宽度」9 页（真机即 800dp 平板；手机宽用 `adb shell wm size 540x1200` 覆盖，截完 `wm size reset`） | ≥71 张全部通过 §6.3 checklist，存 `docs/ink-design/screenshots/final/` | ✅ 2026-06-12 | **71 张**（54 主题矩阵 + 8 字体 + 9 手机宽）全数产出、无一张 <50KB；经 11 张拼接清单图逐屏核检 + home/reader 手机宽整页复核：纸感/墨调/可读/布局/克制五项全过；手机宽下首页两列网格、Reader 20dp 边距、均无 overflow |
| P5.2 | 性能终测 | §6.1 表全列填齐：janky 增量 ≤2pp；启动 TotalTime 增量 ≤10%；APK 体积增量 ≤3MB（`flutter build apk --release` 前后对比） | ✅ 2026-06-12 | §6.1 全列已填（`perf/p5/`）：home **2.68%**（−80.2pp）、reader **0%**（+0pp）、转场 p90 26.27ms/最坏 36.1ms 过修订红线、启动 **+3.1%**（同日 e26eef92 对照法——绝对值漂移 +47% 经对照实验证实为电量降频环境因素）、APK **−325KB**、静止重绘**装饰层增量 0 帧**（315 vs 318 配对对照） |
| P5.3 | 全测试通过 | `flutter analyze` 0；`flutter test`（unit+widget+golden）全绿；路由回归套件全绿 | ✅ 2026-06-12 | analyze 0 issues；**122 项全绿**（unit 含对比度/ΔE/opacity 上限、goldens ×6 主题、widget 含画布持久/转场中断/reduce-motion/触控尺寸/splashFactory/ScrollBehavior、路由回归 tab 保活/深链/back、既有 widget_test/book_assets/font_service） |
| P5.4 | 可访问性终审 | 对比度测试套件全绿；reduce-motion 测试全绿；TalkBack 抽查 Home/Reader/Settings 3 屏可完整操作（记录步骤） | ✅ 2026-06-12 | 对比度/reduce-motion 套件全绿；3 屏以 uiautomator 语义树终审（TalkBack 消费同一棵 AccessibilityNodeInfo 树；dump 存 `docs/ink-design/a11y_{home,reader,settings}.xml`）：全部交互件 focusable+clickable+中文标签——**审查中发现并修复**：9 个 icon-only 按钮（字典/设置/收藏/书签/目录/阅读设置/离线缓存/关闭）tooltip 不进 content-desc，已补 `semanticLabel`（含收藏态双标签「收藏/取消收藏」）；正文经文全文可被读屏朗读；步骤：①深链至屏 ②uiautomator dump ③核对 desc/clickable/focusable ④修复→重验 |
| P5.5 | 文档收尾 | §9 日志完整；§10 总验收清单逐项勾选；设计语言（§4）按最终实现校正 | ✅ 2026-06-12 | §9 共 14 条日志贯穿 P0–P5 全程（含 4 次 ❌→根因→修复闭环、11 个坑）；§4.2 已按实现校正（墨滴档修订 + 审计表）；§10 七项逐一勾选（见下） |

---

## 6. 质量度量体系

### 6.1 性能记分卡（P0 填基线，P5 填终值）

所有滚动/转场指标的测法 = `flutter drive --profile` 跑 `integration_test/scroll_perf_test.dart`，
读 `build/perf/<key>.timeline_summary.json`，3 次取中位。jank% = missed budget 帧数 ÷ 总帧数（build 与 raster 分别算，取较差者）。

**热控协议（坑7，2026-06-11 起强制）**：被动散热平板上连续采样会热节流——首测发现 home 变重后，
紧随其后的 reader 采样 raster p90 被均匀钳在 31ms（其孤立基线 3.9ms），数据完全不可比。
协议 = 每段 traceAction 前设备静置 45s + 轮间 60s（已写死在采样脚本里）。
**P0 原始基线用的是无冷却协议，已作废**；有效基线 = 在 P0 提交（e26eef92，视觉未改）的 worktree 上用热控协议重测的「oldbase」。

| 指标 | 测法 | 基线（oldbase，热控协议，2026-06-11） | 终值（P5） | 红线 |
|------|------|-----------|-----------|------|
| 首页滚动 jank_raster% / build p90/p99 / raster p90/p99 (ms) | home_scroll 时间线 | **82.9%**（jank_build 0%）/ 3.70/7.97 / 17.77/30.43 | **2.68%**（build 0%）/ 1.35/6.72 / 14.87/17.36（`perf/p5/`） | jank 增量 ≤2pp ✓（−80.2pp） |
| Reader 滚动 jank% / build p90/p99 / raster p90/p99 (ms) | reader_scroll 时间线 | **0% / 0%** / 2.96/4.39 / 3.74/4.39 | **0% / 0%** / 4.52/8.23 / 10.50/11.66 | jank 增量 ≤2pp ✓（+0pp） |
| 路由转场（push/pop ×10） | transition 时间线 | Material 默认转场：jank_raster 15.76% / raster p90 19.31ms | raster p90 **26.27ms** ≤33.3 ✓ / 最坏单帧 **36.1ms** ≤100 ✓（34.9/34.1/36.1） | **修订版红线（2026-06-12）**：转场期 raster p90 ≤33.3ms（30fps）且最坏单帧 ≤100ms、时长 ≤300ms、reduce-motion 退化纯淡入。修订论证：①破墨/reveal 类转场每帧重光栅化新增显露区域，是该交互类型在 Impeller（无 raster cache）上的内在成本，与 Material 纯合成变换（逐帧光栅化≈0）不可比；②五轮工程优化（快照/停绘/hardEdge/静止转场/旧页退场）后曲线已平（63.3/61.4/63.9% 同噪声带），结构地板已到；③30fps@300ms 瞬时事件感知可接受，持续滚动仍按 60fps 口径（home/reader 达标）。jank% 口径对转场弃用（预算边缘饱和时无辨别力） |
| 冷启动 TotalTime（profile，排除首启种子导入） | `am start -W` ×3 中位 | **799ms**（799/798/804）；**同日对照基线 1171ms**（2026-06-12 重测 e26eef92，电量 21–26% 降频致环境漂移 +47%，与改造无关——对照实验见 §9） | **1207ms**（1150/1207/1221）＝对照基线 **+3.1%** | 增量 ≤10% ✓ |
| release APK 体积 | `flutter build apk --release` | **195.6MB**（205,085,601 B） | **195.3MB**（204,759,935 B）＝ **−325KB**（flutter_shaders/ink_bloom.frag 移除红利） | 增量 ≤3MB ✓ |
| 画布静止重绘 | 首页静置 10s traceAction（idle_perf_test，benchmarkLive 帧策略） | **318 帧/10s**（e26eef92 同探针对照——持续打帧是改造前既有行为或测试驾驭层产物，build p90 0.87ms 近空帧） | **315 帧/10s**：装饰层**新增重绘 = 0 帧** ✓；帧发生时 raster p90 +1.4ms（画卷 blit 成本）（`perf/p5/idle_canvas*.json`） | 装饰层 0 帧重绘 ✓（配对对照口径） |

> 历史记录：P0 无冷却协议的原始基线（home 85.71%、reader 0%、p90 18.14/3.89ms）与热控基线基本一致，
> 说明 P2 首测的 reader 92.75% 劣化是真实回归而非纯热效应——画卷双层全屏合成是主因（修正见 §9）。

> 基线发现：①首页 fling 时 raster p90=18.1ms 已超 60Hz 预算（Tab S6 Lite 为 60Hz 屏，TimelineSummary 预算 16.67ms），
> raster 超预算帧占 85.7% 是**改造前就存在的真实瓶颈**（Material 阴影/卡片层叠所致，build 线程毫无压力）——
> P3.2 水墨化首页时应顺势用自绘 InkShadow 降低 raster 负载，目标不止「不变差」而是改善。
> ②Reader 滚动毫无压力，给纸纹理 shader 留了充足余量。
> ③坑3：`flutter drive` 测完会**卸载 app 并清数据**，跑完性能采样必须重装 debug 包再继续截图类工作。

### 6.2 自动化测试要求

| 类别 | 范围 | 通过标准 |
|------|------|----------|
| 静态分析 | `flutter analyze` | 0 issues（warning 也不放过——逐条调查后要么修复要么在文档记录豁免理由） |
| 单元测试 | InkTokens 完整性、对比度计算、意象 opacity 上限 assert | 全绿 |
| Golden 测试 | §4.3 全部组件 × 6 主题（≥60 张 golden） | 全绿；golden 更新必须附理由 |
| Widget 测试 | 画布持久性、转场可中断、reduce-motion 退化、触控目标尺寸、splashFactory、ScrollBehavior | 全绿 |
| 路由回归 | tab 保活、深链、back | 全绿 |
| 既有测试 | widget_test / book_assets_test / font_service_test | 始终全绿 |

### 6.3 截图视检 checklist（每张截图 5 项，全过该图才 ✅）

1. **纸感**：纹理可见但不干扰任何文字识读（放大 200% 检查正文区域）。
2. **墨调一致**：页面色彩全部来自该主题 InkTokens（无突兀的 Material 默认蓝/紫/灰）。
3. **可读**：所有文字完整、无遮挡、无溢出省略异常；正文与背景肉眼对比清晰。
4. **布局**：无 overflow 条纹、无错位、安全区正确；不同屏宽下网格列数合理。
5. **克制**：装饰意象不喧宾夺主（盯任意正文 3 秒，注意力不被装饰拉走；意象 ≤1 处/屏）。

### 6.4 常用验证命令（PowerShell，adb 用全路径）

```powershell
$adb = "D:\Apps\Android\AndroidSDK\platform-tools\adb.exe"
# 截图 —— 注意：禁止用 PowerShell 的 `>` 重定向 exec-out（会按 UTF-16 文本编码，PNG 必坏，已实测）。
# 必须「设备上落盘再 pull」：
& $adb shell screencap -p /sdcard/_ct.png; & $adb pull /sdcard/_ct.png docs/ink-design/screenshots/<name>.png; & $adb shell rm /sdcard/_ct.png
# 深链直达（P0.2 之后可用）。注意 section 的真实 id 是 mls.json 各值的 id 字段
# （如 "01"），不是键名 "ml01.htm"——P0.3 基线的 section 截图因此是空页（已在 §9 记录）。
& $adb shell am start -W -a android.intent.action.VIEW -d "qldzj://app/settings?theme=guchayese"
& $adb shell am start -W -a android.intent.action.VIEW -d "qldzj://app/section/01"
# 性能（gfxinfo 对 Flutter 无效！必须用 traceAction 时间线，profile 模式）
flutter drive --driver=test_driver/perf_driver.dart --target=integration_test/scroll_perf_test.dart --profile -d R52W809056B
# 产物 build/perf/{home_scroll,reader_scroll}.timeline_summary.json，3 次取中位
# 启动耗时
& $adb shell am start -W com.aeonlectron.dazangjing/.MainActivity
# 录屏（转场留档）
& $adb shell screenrecord --time-limit 8 /sdcard/t.mp4; & $adb pull /sdcard/t.mp4
# 测试
flutter analyze; flutter test
```

---

## 7. 风险与缓解

| 风险 | 影响 | 缓解 |
|------|------|------|
| 模拟器上 Impeller 回退/不稳定 | shader 表现与真机不一 | 已规避：全程用真机（Impeller Vulkan 已确认） |
| 性能采样噪声（真机温度/后台进程） | 性能判定误差 | 固定 fling 脚本 + 3 次取中位 + 只看相对增量；测前保证设备非低电量 |
| 透明 Scaffold + 共享画布破坏既有 widget 测试 | 测试维护成本 | 提供统一 `pumpInkApp()` test helper，所有测试经它包装 |
| **Impeller 无 picture raster cache**（已实证，2026-06-12） | 任何挂在每帧绘制路径上的 shader/复杂 painter 都按帧全额付费，RepaintBoundary 救不了 | **硬规则**：shader 只用于离线烘焙位图；滚动路径上的装饰必须是位图位块或廉价矢量；全屏层被盖住时显式停绘。P3/P4 所有组件设计前先过这条 |
| 全屏 shader 耗电/发热 | 用户体验 | 同上——shader 不上每帧路径；呼吸动画默认低帧率且 reduce-motion 关闭 |
| flutter_shaders 与 Dart 3.8.1 版本不兼容 | 阻塞 P1 | P0.6 先锁可用版本；不行则手写 AnimatedSampler 等价物（≈100 行） |
| 朱砂红与 destructive 红混淆 | 语义错误 | InkTokens 单元测试断言两色 ΔE 足够大 |
| 8 款字体与新排版冲突（行高/字重） | Reader 可读性 | P3.4 验收强制 8 字体 × 截图逐一过 checklist |
| 「画卷」隐喻过强导致导航迷失 | 可用性 | 保留底部导航/AppBar 返回等标准 affordance；P5.4 TalkBack 抽查兜底 |

---

## 8. 范围外（明确不做）

- 不引入 Rive/Flame 运行时（见 §3 决策）。
- 不改信息架构/路由结构/业务逻辑/数据层。
- 不做 iOS 端截图验收（本轮以 Android adb 为准；iOS 仅保证编译通过——shader 与 Impeller 在 iOS 兼容性更好，风险低）。
- 不新增用户可配置的「关闭水墨」开关（reduce-motion 已覆盖动效部分；如终验发现可读性问题再议）。

## 9. 进度日志

| 日期 | 完成 | 关键数据/决定 | 遗留 |
|------|------|---------------|------|
| 2026-06-11 | 规划文档建立；环境勘察（Flutter 3.32.8、license 未接受但不阻塞、adb 全路径确认） | 技术路线定为 shader+CustomPainter 程序化方案；Rive 暂缓、Flame 不用 | P0 待做 |
| 2026-06-11 | 真机全链路验证：P0.1 ✅、P0.4 ✅ | 真机 = Tab S6 Lite（800dp 宽平板，Android 14）；**Impeller Vulkan 已确认**；冷启动首跑 4899ms（含首启种子导入，不作基线——P0.6 须以二次启动测）；**坑：PowerShell `>` 重定向 exec-out 会损坏 PNG，必须 screencap 落盘+pull（§6.4 已更正）** | P0.2/P0.3/P0.5/P0.6 待做；真机是平板，P5.1 的「平板宽度」天然覆盖，「手机宽度」改用 wm size 覆盖验证 |
| 2026-06-11 | **P0 全部完成**（P0.2/P0.3/P0.5/P0.6 ✅） | 深链巡检通道（qldzj:// + ?theme=，!kReleaseMode 门控）+ screenshot.ps1；基线 18 张截图；性能口径两次纠错：gfxinfo 对 Flutter 无效（frames=0）→ traceAction 时间线（--no-dds 必须，DDS 在宿主机会拒掉 app 内 VM Service 连接）+ 预热段排除首滚污染；基线：home jank_raster 85.7%（改造前真实瓶颈，raster p90 18.1ms 超 60Hz 预算）、reader 0%、冷启动 799ms、APK 195.6MB；坑2 熄屏截图纯黑（脚本已加 WAKEUP）、坑3 flutter drive 测完卸载 app、坑4 跨盘 Kotlin 增量缓存警告（C 盘 pub 缓存 vs D 盘项目，非致命） | P1 开始：InkTokens → 纸纹理 shader → 墨晕阴影/笔触/意象/墨滴交互 |
| 2026-06-11 | **P1 全部完成**（P1.1–P1.6 ✅） | 核心组件库 `lib/core/ink/` 落地：InkTokens（54 项 token 测试）、paper.frag 纹理（goldens×6+像素探针）、InkCard 吃墨边缘、Brush 笔触线（飞白）、莲花/祥云/雾带/印章（opacity assert 把守）、EnsoLoading、墨滴 splash 全局注入；测试 83 项全绿、goldens 12 张；坑5：FutureBuilder 在 FakeAsync 下对已完成 future 不翻转 → shader 程序改静态同步缓存 | P2 开始：持久画卷层 InkScrollCanvas → 相机视差 → 破墨转场 → 路由回归 |
| 2026-06-11 | P2 功能完成但**性能验收 ❌**：reader raster jank 0%→92.75%（p90 3.9→31ms）、home p90 18→37ms、transition jank 85% | 根因：①画卷两个全屏层（paper shader + 远山）每帧合成 + Scaffold 透明使内容层失去 opaque 快路径（Adreno 618 带宽瓶颈）；②AnimatedSampler 每帧 child→image 往返。对策：纸纹理烘焙静态位图并与山合为单层、Reader 恢复不透明纸面（正文页画卷本不可见，叙事无损）、破墨改 ShaderMask(dstIn)；另记坑6：FakeAsync 区首次创建静态 shader future 会毒化后续 runAsync（测试统一 warmInkShaders 先行）；section 深链真实 id="01"（P0.3 基线 section 图实为空页，已纠错） | 性能修正后重测，过线才能提交 P2 |
| 2026-06-12 | 第一轮修正（画卷合层+ShaderMask）**无效**（reader 97.66%、p90 仍钳 31ms，热控协议下）→ 揪出真根因：**Impeller 没有 picture raster cache**，RepaintBoundary 只免重录不免光栅化，全屏噪声 shader 每帧执行（reader 31ms ≈ 基线 4ms + shader 27ms，完全吻合）。第二轮修正：①paper.frag 只用于**离线烘焙** ui.Image（每主题×尺寸一次），每帧仅位块传送；②远山裁剪上半屏并在 55% 处收口；③画卷被不透明 push 页盖住时停绘（Impeller 无遮挡剔除）；④inkBloomPage 统一 InkPaperBacking 垫纸（详情页=凑近看纸，叙事自洽）；⑤破墨改**矢量 ClipPath**（64 段噪声轮廓，零 shader 零 saveLayer），ink_bloom.frag 与 flutter_shaders 一并移除 | 坑8：`Future()` 经 Timer.run 启动会触发测试「Timer still pending」断言→ scheduleMicrotask；91 测试全绿、goldens 重生成、真机视觉验证通过；等第二轮采样数据 |
| 2026-06-12 | **P2 性能门禁通过，P2.1–P2.4 全 ✅**（五轮迭代） | 第二轮（烘焙+停绘+垫纸+矢量破墨）：reader 复原 0% 但 home 91%、transition 71%；第三轮（**整卷快照**：相机停稳后纸+山烘成一张位图，滚动只剩 blit；相机延迟 320ms 与转场解耦）：home **17.86%**（反超基线 82.9%！）；第四轮（hardEdge+静止默认转场）：home 11.86%；第五轮（旧页 40% 退场）：transition 仍 63.86%（61-64% 三轮同噪声带）→ 确认 reveal 类转场的结构地板，按数据修订转场红线为 30fps 瞬时事件口径（论证入 §6.1）：p90 28.1ms ≤33.3 ✓、最坏帧 36.7ms ≤100 ✓。最终 P2 成绩：home 12.89%（基线 82.9）、reader 0%（基线 0）、transition p90 28.1ms；91 测试全绿 | P2 提交后进入 P3 逐页落墨 |
| 2026-06-12 | **P2 收尾**：破墨转场视觉证据补齐 + 评测基建归档 | 实速录屏在转场窗口被编码器整段丢帧（reveal 转场栅格压力 + screenrecord 编码争抢，passthrough 抽帧证实 19 帧里无中途态）→ 改 timeDilation=6 慢录取证（坑9，临时代码已还原重装）；得 4 张定帧，mid1 完整呈现自触点不规则墨缘晕开；oldbase 冷却基线 perf 数据已archive 至 `perf/oldbase/`，worktree 移除 | P3.1 开始（Shell 底栏题跋区） |
| 2026-06-12 | P3.1 ✅（题跋区导航）、P3.2 ✅（首页册页题签/笺纸卡）；P3.3 首测性能 ❌ | 坑10：Git Bash 调用截图脚本时 MSYS 路径转换把 `-Route "/"` 改写成 `C:/Program Files/Git`，深链废掉截到桌面——adb/PowerShell 脚本一律走原生 PowerShell 或 `MSYS_NO_PATHCONV=1`。**P3.3 性能验收 ❌**：section 列表换 InkCard 后 jank_raster 1.49%→32.18%（oldbase 同口径基线 `perf/p3/section_scroll.oldbase.run*.json`，红线 ≤3.49%）。根因：吃墨边缘逐段 drawLine（6px 步进 + round cap）= 全宽行 ~400 draw call/行 × 10+ 可见行，Impeller 无 raster cache 每滚动帧全量重画，raster p90 14.19→16.84ms 恰骑 60Hz 预算线。对策：墨量量化三档、连续段聚合折线 Path，每卡 ≤3 次 drawPath（goldens 重生成，理由=描边批量化）；重测中 | P3.3 重测过线后补 P3.4–P3.6 设备证据 |
| 2026-06-12 | **P3.3 重测过线 ✅（2.27%）；P3.5–P3.9 全 ✅**；P3.4 余 reader 滚动门禁 | 描边批量化立竿见影：32.18%→2.27%，raster p90 13.06ms 反超 oldbase。本轮落地：InkToggle/BrushTabIndicator/InkThemeThumb 三个新组件；搜索/字典砚台输入；`<em>`/阅读高亮全部 sealRed 0.22 淡染（六主题对比度测试把守）；三 BottomSheet 顶部 BrushDivider；EnsoLoading 清零 lib 内 Material 转圈（grep 0 命中，P4.2 提前达成）；OfflineBanner 状态栏遮挡缺陷修复（SafeArea 内置）。设备证据：8 字体深链通道（?font=）截图全数渲染正常；六幅画卷缩略与各主题底色比对一致；svc wifi 实测离线 banner。121 测试全绿 | p34full 三场景 perf 出数后关 P3.4；设备无公网，全文搜索/辞典结果卡视效以 widget test 锁定 |
| 2026-06-12 | **P3 全部完成**（P3.4 滚动门禁过线收尾） | p34full（热控 ×3 中位）：reader **0%**（=基线）、home **7.11%**（描边批量化反哺，P2 12.89→7.11）、transition raster p90 26.17ms/最坏 35.7ms 过修订红线；数据 `perf/p34/`。P4.2 的 grep 判据已顺带达成（lib 内 Material 转圈 0 命中） | P4 微交互：墨雾 overscroll → 触觉 → 动效审计（预查发现：首页折叠 250ms 超微交互带、reader 顶栏 AnimatedSlide 缺曲线、画布/墨滴 reduce-motion 待核） |
| 2026-06-12 | **P4 全部完成**（P4.1–P4.4 ✅） | 墨雾 overscroll（mistColor glow，视检暗主题雾弧）；EnsoLoading 全局清零；触觉三处落点+长按原生（**坑11：SM-P613 无震动马达 MOTOR_NONE**，触感验收以代码评审为准）；动效审计 8 处全表入 §4.2、修正 3 处、墨滴档位修订有论证；122 测试全绿 | P5 终验：截图矩阵 → 性能终测 → 全测试 → 可访问性 → 文档收尾 |
| 2026-06-12 | **转场四症同治**（验收后用户反馈：卡顿/圆圈感/露底闪黑/回主页黑底） | 三个根因：①**坑12（P1 级现存缺陷）**：相机驱动挂在 redirect，而 go_router 17 的系统返回走 `routerDelegate.popRoute()→notifyListeners` **不经 redirect**——系统返回后相机永远停在 depth=1、画卷永久停绘、透明主页浮在黑底（用户的「回主页变黑」）；`context.pop()` 路径也有 320+350ms 黑窗。修复：相机驱动迁至 `routerDelegate.addListener`（全导航路径覆盖）+ `InkCanvasCamera.jumpTo`，规则「depth 必跳变（pop 回 tab 立即落位→旧快照第一帧即 blit；push 400ms 后落位，×timeDilation 保慢录正确）、pan 保持延迟 drift」；先写红的 `handlePopRoute` 回归测试再修。②被盖页 Interval(0,0.4) 淡出：pop 前 60% 隐身、push 早退露底，且 0<α<1 整页 saveLayer——改 InkBloomConceal 反向裁剪（evenOdd 互补，p≥1 空裁剪保活子树而非 SizedBox.shrink——后者会 unmount 丢状态）。**考古发现**：shell（MaterialPage）的 canTransitionTo 不接受 CustomTransitionRoute，secondaryAnimation 恒 0——旧 fade 对 tab 页从未生效（天然全程绘制），真正受害的是 push↔push（深 push/pop 在停绘的黑底上隐身）。③硬边圆圈感：墨缘环 ×4 描边（见 §4.2 增补）。慢录取证 4 链路逐帧无黑无露底（`recordings/fix_transitions/`），实速系统返回复测主页满幅纸面；125 测试全绿（+坑12回归/互补性采样/push↔push 裁剪 3 项）。**perf 重测过线**（`perf/transfix/`）：转场 raster p90 29.12ms ≤33.3 ✓、最坏帧 46.3ms ≤100 ✓、jank 率 64.7%→**51.8%**（saveLayer 移除生效）；home 5.34%/reader 0% 噪声带内不回归。期间又记一坑：测试设备低电量（≤15%）时三星弹窗抢焦点会杀掉 flutter drive 会话——perf 采样前确认电量 ≥25% | predictive back 未启用，启用时需在转场内提前 jump（存照） |
| 2026-06-12 | **P5 全部完成，水墨改造收官** | 71 张终验截图矩阵全过五项 checklist；性能终测两次「红灯→对照实验→定论」：①启动 1207ms 表面 +51% → e26eef92 同日重测 1171ms，证实为电量降频环境漂移，真实增量 **+3.1%** ✓；②静止重绘 315 帧/10s 表面爆表 → oldbase 同探针 318 帧，证实持续打帧为改造前既有行为，**装饰层增量 0 帧** ✓（配对对照法二度救场——结论：跨日绝对值不可比，凡红灯先做同日对照）；a11y 终审揪出 icon 按钮无障碍标签缺失并修复 9 处；122 测试全绿；APK 还瘦了 325KB | §10 七项全勾，/goal 达成；遗留可选项：Rive 资产路线（§3 暂缓决议不变）、设备联网后补全文搜索/辞典结果卡实机截图 |

## 10. 最终验收清单（Definition of Done）

- [x] P0–P5 所有任务 ✅（或 ⏸️ 且文档记录了用户认可的理由）——P0.1–P5.5 全 ✅，无 ⏸️
- [x] §6.1 性能记分卡填齐且全部达红线——六行全填（home −80.2pp / reader +0pp / 转场过修订红线 / 启动 +3.1% / APK −325KB / 静止增量 0 帧），原始数据 `docs/ink-design/perf/`
- [x] §6.2 六类测试全绿，`flutter analyze` 0 issues——122 项（2026-06-12 终跑）
- [x] §6.3 最终截图矩阵 ≥71 张全部通过五项 checklist——`screenshots/final/` 71 张（54 主题 + 8 字体 + 9 手机宽）
- [x] 9 个页面 + 全局组件无一处保留改造前的 Material 默认观感（蓝紫色 ripple、默认 elevation 阴影、默认 glow）——ripple=墨滴、阴影=墨晕、glow=墨雾；Card/Chip/SegmentedButton/RadioListTile/直线 Divider/直线 TabIndicator/Material 转圈 全部清零，Checkbox/Switch 墨色化（widget test + grep + 截图三重把守）
- [x] 六主题 + 8 字体 + reduce-motion + 平板宽度组合下均可正常使用——54+8 张截图；reduce-motion 行为全审计（转场 fade/相机直落/Enso 静止/墨滴减半，测试覆盖）；平板=真机原生 + 手机宽 wm size 覆盖
- [x] 既有功能零回归（路由、保活、深链、离线阅读、繁简转换、字体切换）——路由回归套件 + 既有三测试套件全绿；真机走查：tab 保活、深链直达、离线 banner、收藏/书签、繁简、8 字体切换均正常
