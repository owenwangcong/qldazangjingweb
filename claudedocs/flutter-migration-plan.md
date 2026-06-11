# 乾隆大藏经 Web → Flutter 离线优先迁移方案

> Phase 1 评估产物。源：Next.js 14 Web App（qldazangjing.com）。目标：`./flutter-app`（Flutter 3.32.8 / Dart 3.8.1）。

## 1. 源应用解剖

### 1.1 数据层（静态 JSON，无用户数据后端）
| 数据 | 路径 | 大小 | 说明 |
|---|---|---|---|
| 部类目录 | `/data/mls.json` | 679KB | 13 个部类（大乘般若部…），每部类含 bus[]（册：id/title/author/bu/volume） |
| 书籍元数据 | `/data/bookMetaData.json` | 217KB | bookId → {title, author} |
| 常用经典 | `/data/classics.json` | 2.4KB | 分类（般若/唯识/楞严/法华…）→ [{id, title}] |
| 经文正文 | `/data/books/{id}.json` × 1809 | 共 ~6GB（含字体） | `{meta:{id,Bu,title,Arthur,last_bu,next_bu}, juans:[{id,type:bt|bm|p,content:[string]}]}` |
| 子集字体 | `/data/book_fonts/{font}_{bookId}.woff` × 14472 | — | Web 端按书子集化字体（Flutter 不适用） |

**关键结论**：正文总量太大无法打包。策略 = **目录元数据内置 App、正文按需下载并永久缓存到本地库**。

### 1.2 状态/业务（全部 localStorage，无登录）
- `FontContext`：fontSize(text-sm..text-6xl)、lineHeight(1..3)、letterSpacing、paragraphSpacing、字体、版宽
- `ThemeContext`：6 套主题 — lianchichanyun/zhulinyoujing/yueyingqinghui/**hupochangguang(默认)**/guchayese(暗)/fagufanyin(暗)，HSL 变量见 globals.css
- `LanguageContext`：繁简切换（OpenCC，源数据为简体；繁体 = cn→tw 实时转换）
- `MyStudyContext`：收藏 FavoriteBook{bookId,timestamp}、历史(≤50)、书签 Bookmark{bookId,partId,content,timestamp}
- `AnnotationContext`：划词注释（recogito-js）{id,text,bookId,body[]}
- 其他 localStorage：classicTextsActiveTab/Visible、isHeaderVisible、hasSeenBookTour

### 1.3 网络 API（Flutter 直连生产环境）
| 功能 | 端点 | 备注 |
|---|---|---|
| 全文搜索 | `POST https://qldazangjing.com/api/elasticsearch/search` {query, mode:smart\|phrase, fields, from, size, highlight} → {hits:[{id,title,author,score,highlights}], total} | 在线功能；离线降级为本地标题搜索 |
| 字典 | `POST https://qldazangjing.com/api/todict` {key} → {results:[{id,key,dict,value}]} | 在线 |
| AI 今译/释义 | `POST https://qldazangjing.com/api/tochatgpt` {text, action:tomodernchinese\|explain} | 在线 |
| 正文/目录 | `GET https://qldazangjing.com/data/...` | 下载后永久缓存 |
| PDF 下载 | Puppeteer 服务端渲染 | **移动端不迁移**（用离线缓存/系统分享替代） |

### 1.4 页面清单与移动端范式转换
| Web 页面 | 交互（Web 范式） | Flutter 方案（Mobile 范式） |
|---|---|---|
| `/` 首页 | 常用经典折叠卡 + 部类 Grid + Hover | Home Tab：经典横向分类 chips + 卡片网格，InkWell 波纹 |
| `/juans/[id]` 部类册列表 | 列表 + hover | 列表页，滑动可收藏（flutter_slidable） |
| `/books/[id]` 阅读器 | 划词右键菜单（复制/搜索/字典/今译/释义/注释）、悬浮 Header、滚动高亮、书签段落跟踪 | SelectionArea 自定义选择工具条 → BottomSheet 呈现字典/AI 结果；AppBar 自动隐藏；scrollable_positioned_list 书签定位；阅读设置 BottomSheet |
| `/search` | 全文/标题双模式 + 分页 | Search Tab；在线全文 + 离线标题；无限滚动替代分页 |
| `/mystudy` | 收藏/历史/书签/注释四区 + 分页 | 我的 Tab：分段列表，左滑删除 |
| `/dicts` | 词典查询 | 字典页（在线，离线提示） |
| `/favorites`、`/downloads`、`/settings` | 占位/空壳 | 收藏并入"我的"；下载页 = **离线缓存管理**（新核心能力）；设置页 = 主题/繁简/阅读偏好 |
| `/intro` | 静态介绍 | 关于页 |
| Header 浮动按钮组 | 隐/显、设置弹窗、全屏 | 底部导航 + 阅读器内 BottomSheet，48dp 触摸目标 |

## 2. Flutter 架构（Clean Architecture）

```
flutter-app/lib/
├── main.dart                 # 入口：初始化 DB → ProviderScope → MaterialApp.router
├── core/
│   ├── constants/            # API 端点、资源路径
│   ├── theme/                # 6 套主题 → ThemeData + AppColors ThemeExtension
│   ├── network/              # Dio 客户端、connectivity 监听
│   └── utils/                # 繁简转换、文本工具
├── data/
│   ├── models/               # Isar Collections（强类型）
│   ├── datasources/          # local(Isar) / remote(Dio)
│   ├── repositories/         # Repository 实现（local-first 协同）
│   └── sync/                 # Outbox + SyncManager
├── domain/
│   ├── entities/
│   └── repositories/         # 抽象接口
└── presentation/
    ├── router/               # GoRouter
    ├── providers/            # Riverpod providers
    ├── pages/                # home/category/reader/search/mystudy/dict/settings/about/downloads
    └── widgets/              # 复用组件
```

### 2.1 技术选型（按目标规范从括号中选定）
- 状态管理：**Riverpod**（flutter_riverpod）— 与 Isar watcher/Stream 自然衔接
- 路由：**GoRouter**
- 本地库：**Isar**（首选 isar_community 分支以兼容 Dart 3.8；失败则官方 isar 3.1.0；再失败 hive_ce — 见 ai_migration_log.md）
- 网络：Dio + connectivity_plus；图片 cached_network_image；列表操作 flutter_slidable
- 繁简：chinese_converter（纯 Dart OpenCC 词表）；不可用则降级标记 TODO: AI_ASSUMPTION

### 2.2 Isar Collections（SSOT）
- `CatalogSection`：部类（id, name, order）— 种子数据来自内置 assets
- `CatalogBook`：册（bookId, sectionId, title, author, bu, volume, isMulu）
- `BookContent`：正文缓存（bookId, metaJson, juansJson, cachedAt, sizeBytes）
- `ClassicEntry`：常用经典（category, bookId, title, order）
- `FavoriteBook` / `HistoryItem` / `Bookmark` / `Note`（注释）
- `ReadingProgress`：bookId → 滚动位置（段落索引）——移动端新增，断点续读
- `AppSettings`：单例（theme, isSimplified, fontSize, lineHeight, letterSpacing, paragraphSpacing, fontFamily…）
- `OutboxOperation`：{id, type, payloadJson, status(pending/inFlight/done/failed), attempts, createdAt} — FIFO
- `DownloadTask`：整部/批量离线下载队列（由 SyncManager 消费）

### 2.3 离线优先数据流
1. 首启：assets 种子（mls/classics/bookMetaData）→ Isar；UI 永远 watch Isar
2. 打开书：Isar 命中 → 直接渲染；未命中且在线 → Dio 拉取 → 写 Isar → UI 响应；未命中且离线 → 提示+加入待下载队列（可选）
3. 写操作（收藏/书签/笔记/设置）：直接写 Isar（本地即成功）→ 同时投递 OutboxOperation（为未来云同步预留，当前标记 done 的本地操作不需要网络）
4. SyncManager：connectivity_plus 监听恢复在线 → FIFO 消费 Outbox（下载任务、重试失败项）；指数退避，冲突以"最后写入获胜 + 本地优先"解决

## 3. 风险与假设（TODO: AI_ASSUMPTION 汇总）
- 生产数据源 = https://qldazangjing.com（从 sitemap 推断）
- 无用户后端 → Outbox 当前主要服务于下载队列与未来云同步扩展点
- 阅读字体：不打包 6GB 子集字体；v1 使用系统字体渲染汉字，字体切换项保留架构位
- recogito 划词注释 → 简化为"选中文本 + 笔记"模型（保留数据结构 quote/note）
- PDF 下载不迁移；以"离线缓存 + 系统分享文本"替代

## 4. 里程碑
1. ✅ 评估与拆解（本文档）
2. Flutter 项目初始化 + 主题 + Isar Schema + 种子数据
3. Outbox + SyncManager + 连接状态
4. Repository 层 + Riverpod providers
5. UI：Home → 部类 → 阅读器 → 搜索 → 我的 → 设置/缓存管理 → 字典/关于
6. flutter analyze / flutter test 全绿，按模块 git commit
