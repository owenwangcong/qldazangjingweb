# APK 自托管说明（qldazangjing.com）

网站上的 App 下载入口有两处，都不新增页面或 header 按钮：

| 位置 | 文件 | 形态 |
|---|---|---|
| 首页底部 footer | `src/app/page.tsx:250` | `<AppDownload variant="compact" />` 一行 CTA |
| 简介页「其他」之前 | `src/app/intro/IntroPageClient.tsx:212` | `<AppDownload variant="full" />` 完整小节 |

链接常量集中在 `src/app/components/AppDownload.tsx` 顶部：`PLAY_STORE_URL` / `APP_VERSION` / `APK_URL` / `APK_SIZE`。

## 为什么不放 `public/`

`public/` 里的文件由 Next 的 Node 进程提供。而 `deploy/qldazangjingweb.service` 给 Node 设了 `MemoryMax=1200M` 的 cgroup 上限，这台机器还同时跑着 Elasticsearch、MySQL、Apache/Plesk 和 Docker（2026-06-17 出过一次全局 OOM）。让 200MB 的下载流反复穿过 Node 进程，是往一个已经出过事的地方加压。

Apache 已经在 :443 反代到 :3000，让它直接吐这个文件即可 —— Node 完全不参与，内核 sendfile 直出。

顺带：`/public` 本来就在 `.gitignore` 里，APK 无论如何都得手动上传，所以走 Apache 并不多一道手工步骤。

## 一次性配置

APK 存放目录（放在 `/var/www/qldazangjingweb` 之外，避免被 `deploy.sh` 的构建流程波及）：

```bash
sudo mkdir -p /var/www/qldazangjing-apk
sudo chown ubuntu:ubuntu /var/www/qldazangjing-apk
```

Apache vhost 里，**在反代规则之前**加上（Plesk 面板里是 "Apache & nginx Settings" → "Additional Apache directives"）：

```apache
# Serve APK downloads straight from disk; never proxy them to the Node app.
Alias /apk /var/www/qldazangjing-apk
ProxyPass /apk !

<Directory /var/www/qldazangjing-apk>
    Require all granted
    Options -Indexes
    AddType application/vnd.android.package-archive .apk
    <FilesMatch "\.apk$">
        Header set Content-Disposition "attachment"
        # APK 文件名带版本号，内容不会变，可以长缓存。
        Header set Cache-Control "public, max-age=31536000, immutable"
    </FilesMatch>
</Directory>
```

`ProxyPass /apk !` 是关键那一行——没有它，`/apk` 仍然会被转发给 Node。

改完 `sudo apachectl configtest && sudo systemctl reload apache2`。

## 每次发版

**APK 必须从 Play Console 下载，不要用 `flutter build apk` 的产物。**

开启 Play App Signing 后，Google 会用 app signing key 重新签名再分发。Play Console 提供的
"Signed, universal APK" 用的是同一把钥匙，和商店发给用户的签名一致；本地
`flutter build apk --release` 签的则是 upload key。两者混用的后果是：从网站装了 APK 的
用户，之后 Play 推更新会因签名不匹配而安装失败，只能卸载重装 —— 收藏、书签、阅读进度全丢。

1. Play Console → 对应 release 的 App bundle → **Downloads** 标签页 → Assets 表里下载
   **Signed, universal APK**（1.0.0 时为 71.7 MB）。同表其余项都不是分发用的：Original
   file 是 `.aab` 本身，Archived APK 是系统归档用的占位壳，两者都不可安装；ReTrace
   mapping 和 Native debug symbols 是崩溃反混淆用的符号表。
2. 按版本号命名上传（文件名必须和 `AppDownload.tsx` 里的 `APK_URL` 对上）：
   ```bash
   scp <下载到的文件>.apk ubuntu@<服务器>:/var/www/qldazangjing-apk/qldazangjing-1.0.0.apk
   ```
3. 更新 `src/app/components/AppDownload.tsx`：`APP_VERSION` 填 **Play 上的版本名**，不是
   `pubspec.yaml` 的版本 —— 两者会不一致（Play 是 1.0.0 时，pubspec 已经是 1.0.4）。
   `APK_SIZE` 按 `ls -lh` 的实际大小填。然后部署网站。
4. 验证走的是 Apache 而不是 Node：
   ```bash
   curl -sI https://qldazangjing.com/apk/qldazangjing-1.0.0.apk | head
   ```
   `Content-Type` 应为 `application/vnd.android.package-archive`，且响应头里**不应**出现
   `X-Powered-By` 或 Next 的 `x-nextjs-*`。

旧版本 APK 建议保留一到两个，避免用户手里的旧链接直接 404。

## 待办 / 已知问题

- **体积**：Play Console 的 universal APK 为 71.7MB —— AAB 构建流程对 assets 的压缩远好于本地 fat APK（本地 `flutter build apk` 产物 204MB，几乎没压）。原先设想的「只内置 1 款字体、其余按需下载」优先级因此下降；`assets/fonts` 未压缩前仍占 133MB（8 款 TTF 全量内置，见 `flutter-app/pubspec.yaml:103-105`），若之后还要再瘦一轮，那里仍是最大的一块。
- **Play 徽章合规**：现在用的是文字按钮 + lucide 图标。Google 的品牌规范要求使用官方 "Get it on Google Play" 徽章图片，若要严格合规需下载官方素材放到 `public/images/` 再替换。
- **校验值**：页面上没有放 SHA256。侧载场景下提供校验值是好实践，但普通用户基本不会用，暂略。需要的话在 `variant="full"` 里补一行即可。
