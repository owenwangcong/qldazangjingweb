# 乾隆大藏经 Flutter App

离线优先（Offline-First）的乾隆大藏经阅读应用，由 Next.js Web 版（qldazangjing.com）迁移而来。

## 架构

Clean Architecture 三层 + 离线优先单一事实源（SSOT = Isar）：

```
lib/
├── core/            # 常量 / 6 套主题(ThemeData+ThemeExtension) / Dio / 连接监听 / OpenCC 转换
├── data/
│   ├── models/      # Isar Collections（目录、正文缓存、收藏/历史/书签/笔记、设置、Outbox）
│   ├── datasources/ # local: IsarService(含首启种子)  remote: ApiClient(qldazangjing.com)
│   ├── repositories/# Repository 实现（local-first）
│   └── sync/        # Outbox(FIFO) + SyncManager(连接恢复自动消费、指数退避)
├── domain/          # 实体 + Repository 抽象
└── presentation/    # GoRouter + Riverpod + 页面/组件
```

### 离线优先数据流
- 全部目录（1809 册元数据）内置 assets，首启导入 Isar——浏览零网络。
- **全部经文正文内置 App**（`assets/books/*.json.gz`，198MB 原文 gzip 后 56.5MB）：
  打开时由后台 isolate 解压导入 Isar 缓存，阅读完全不需要网络；
  网络下载仅作为资产缺失时的兜底（Outbox 队列）。
  资产重新生成：仓库根目录运行 `node scripts/generate-book-assets.js`。
- 收藏/历史/书签/笔记/阅读进度全部本地写入，UI 即时响应，永不等待网络。
- 全文搜索/字典/AI 今译释义为在线功能，离线明确降级提示（标题搜索离线可用）。

### 字体
8 款全量 TTF（`assets/fonts/`，~132MB）与 Web 字体选择器 1:1。
刻意**不在 pubspec `fonts:` 声明**：运行时 `FontLoader` 只加载用户选中的
那一款（`core/fonts/font_service.dart`），其余仅占 APK 不占内存；
启动时后台预热持久化的选择，首帧用系统字体直出、加载完成整树切换。

### 简繁转换
OpenCC 词表（取自 web 项目 opencc-js）打包为 `assets/opencc/*.tsv`，
纯 Dart 贪婪最长匹配实现（`core/utils/chinese_converter.dart`）。
词表更新：在仓库根目录运行 `node scripts/generate-opencc-assets.js`。

## 开发

```bash
flutter pub get
dart run build_runner build   # Isar schema 变更后重新生成
flutter analyze
flutter test
flutter run                   # 连接设备/模拟器
```

## 移动端交互对照（vs Web）
| Web | App |
|---|---|
| 划词右键菜单 | 长按选词 → 选择工具条（复制/字典/今译/释义/笔记） |
| 悬浮 Header 隐/显 | AppBar 随滚动方向自动隐/显 |
| 列表 hover 删除 | 左滑操作（flutter_slidable） |
| 分页器 | 无限滚动 |
| PDF 下载 | 离线缓存管理（下载整部/删除缓存） |
| localStorage | Isar 数据库 |
