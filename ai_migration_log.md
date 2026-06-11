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

## 构建后修复（代码复查发现）
- 阅读器列表首项为书名头部，初始滚动索引需 blockIndex+1 偏移（书签/进度跳转此前会偏一项）
- 进度恢复与正文缓存命中存在时序竞争：列表已挂载时改用 `jumpTo` 显式跳转
- `mystudy` 的标题解析 provider 以 `List<String>` 作 family key 会因列表实例不等导致无限重建，改为逗号拼接的 String key
- 段落块底部双重间距修正
