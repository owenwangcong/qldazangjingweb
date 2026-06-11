# AI 迁移日志（无人值守运行记录）

> 运行日期：2026-06-11。分支：`flutter`。目标目录：`./flutter-app`。

## 状态总览
| 阶段 | 状态 | 提交 |
|---|---|---|
| 1. 评估与拆解 | ✅ | `claudedocs/flutter-migration-plan.md` |
| 2. 基础设施（项目/主题/Isar/种子） | ✅ | flutter analyze 0 issues |
| 3. Outbox + SyncManager | ✅ | FIFO/退避/防卡队列 |
| 4. Repository 层 + Riverpod | ✅ | |
| 5. 移动端 UI（9 个页面） | ✅ | flutter analyze 0 issues，flutter test 5/5 通过 |

未发生“同一错误连续 3 次修复失败”需要跳过的模块。

## 关键技术决策
1. **Isar 选型**：官方 `isar` 3.1.0+1 的 generator 与 Dart 3.8/新版 analyzer 存在兼容风险，改用社区维护分支 `isar_community` 3.3.1（API 同 Isar 3.x，generator 兼容 analyzer 8）。一次解析成功，codegen 正常。
2. **繁简转换**：pub.dev 无可用纯 Dart OpenCC 包（`chinese_converter` 不存在；`opencc` 依赖实验性 native-assets）。方案：从 Web 项目 `node_modules/opencc-js` 提取 OpenCC 词表（STPhrases/STCharacters/TSPhrases/TSCharacters）生成 TSV 资产（`scripts/generate-opencc-assets.js`），Dart 侧实现贪婪最长匹配转换器。单测验证通过。
3. **离线策略**：正文数据约 6GB/1809 册，无法打包。目录元数据（mls/classics/bookMetaData，约 880KB）内置 assets 首启种子入 Isar；正文按需下载永久缓存；整部下载走 Outbox 队列。

## TODO: AI_ASSUMPTION 汇总（请复查）
- `app_constants.dart`：生产数据源 = `https://qldazangjing.com`（从 sitemap 推断）。如有独立 API 域名/鉴权请修改。
- `app_settings.dart`：v1 阅读字体使用系统字体；Web 的按书子集 woff 字体（14472 个文件）机制不适用移动端。后续可打包 LXGW 等开源全量字体或实现动态字体下载（需 woff→ttf 转换）。
- 划词注释（recogito-js）简化为「选中文本 + 笔记」模型（quote + body 存 Isar），未实现原文内高亮锚定渲染。
- PDF 下载（服务端 Puppeteer 渲染）不迁移：移动端以离线缓存替代；如需导出可后续接 share_plus 分享纯文本。
- Outbox 当前服务于下载队列；用户数据（收藏/书签/笔记）本地即真相、无云端同步后端，冲突解决策略=本地优先/最后写入获胜，云同步是预留扩展点。
- 全文搜索 ES 高亮 fragment 仅解析 `<em>` 标签，其余 HTML 剥离。
- 搜索跳转定位：按「简体化关键词包含」找第一个匹配块并滚动+高亮，未还原 Web 端基于上下文指纹（context 参数）的精确段落定位。

## 验证记录
- `flutter analyze`：0 issues（每阶段提交前均验证）
- `flutter test`：5/5 通过（OpenCC 转换 ×3、实体解析 ×2）
- `dart run build_runner build`：5 个 collection 生成成功
- `flutter build apk --debug`：见下方更新

## 构建验证
`flutter build apk --debug` ✅ 成功（app-debug.apk）。过程中修复的 Android 配置：
1. `android/settings.gradle.kts`：AGP 8.7.3 → **8.9.1**（androidx.core 1.18 要求 ≥8.9.1）
2. `android/app/build.gradle.kts`：`compileSdk = 36`（androidx.core 1.18 要求 API 36）、`ndkVersion = "27.0.12077973"`（connectivity_plus/isar/share_plus 等插件要求）、`minSdk = 23`（isar_community_flutter_libs 要求，即 Android 6.0+）

## Android 真机运行调试（2026-06-11，SM P613 / Android 14）
症状：`flutter run` 后应用启动即白屏，logcat 报
`IsarError: Incorrect Isar Core version: Required 3.3.1 found 3.2.0-dev.2`。

根因：**isar_community_flutter_libs 3.3.1 的打包缺陷**——其 Android `libisar.so` 二进制实际是 3.2.0-dev.2，与 Dart 侧 3.3.1 的版本校验不符。

修复链（pubspec + 生成代码）：
1. `isar_community_flutter_libs` 升至 **3.3.2**（二进制已修复），它精确锁定 `isar_community: 3.3.2`。
2. `isar_community_generator` 3.3.2 需要 Dart ≥3.9（本机 Flutter 3.32.8 = Dart 3.8.1），而 generator 3.3.1 又精确锁定 isar_community 3.3.1 → 用 `dependency_overrides: isar_community: 3.3.2` 解除死锁（生成代码与运行时为补丁级兼容）。
3. 3.3.2 运行时的 `CollectionSchema` const 构造断言 `Isar.version == version`，生成文件中的 `version: '3.3.1'` 字面量触发 11 个 const 求值错误 → 将 5 个 `.g.dart` 中的版本字面量改为 `version: Isar.version`（运行时常量，今后补丁升级免改）。
   注意：若日后重跑 build_runner，生成器会重新写回字面量，需重做此替换或升级 Flutter SDK 后统一用 3.3.2 生成器。

修复后第二个崩溃：首帧渲染异常 `'crossAxisExtent > 0.0': is not true`（home_page 部类网格）。
根因：Android 启动的 warm-up 帧以 0×0 约束预布局，`SliverGridDelegateWithMaxCrossAxisExtent`
对 crossAxisExtent==0 直接断言（Flutter 已知行为），sliver geometry 留空导致后续每帧
`Null check operator used on a null value`，UI 卡死。修复：网格外包 `SliverLayoutBuilder`，
约束无效时短路返回空 sliver。

## 经文全部内置（2026-06-11，应用户要求）
用户反馈"可以打开 app 但打不开经文"。原设计正文按需联网下载（qldazangjing.com），
而该服务器从用户网络探测超时不可达 → 阅读功能瘫痪。

重新评估数据量：~6GB 是含 14472 个网页字体的总量，**纯正文仅 198MB（1809 个 JSON）**，
gzip -9 后 **56.5MB** —— 完全可打入 App。

改造内容：
- `scripts/generate-book-assets.js`：全部正文 gzip 入 `flutter-app/assets/books/{id}.json.gz`
- 新增 `BookAssets` 数据源：rootBundle 读取 → 后台 isolate（compute）解压+解析，避免 UI 卡顿
- `BookRepositoryImpl.ensureCached` / `SyncManager._downloadBook`：**资产优先**，
  网络仅作为资产缺失（目录与数据不匹配）时的兜底；Outbox 保留该兜底职责
- 移除已无意义的"下载整部离线"按钮与 `downloadSection` 队列操作类型
  （注意：手工同步修改了 outbox_operation.g.dart 的枚举映射；旧安装若有遗留
  downloadSection 队列项，fromMap 回退为 downloadBook——开发期无影响）
- APK 体积增加约 56MB；Play 商店上架时如超 200MB 基础包限制可改用 Play Asset Delivery

## 构建后修复（代码复查发现）
- 阅读器列表首项为书名头部，初始滚动索引需 blockIndex+1 偏移（书签/进度跳转此前会偏一项）
- 进度恢复与正文缓存命中存在时序竞争：列表已挂载时改用 `jumpTo` 显式跳转
- `mystudy` 的标题解析 provider 以 `List<String>` 作 family key 会因列表实例不等导致无限重建，改为逗号拼接的 String key
- 段落块底部双重间距修正
