# 将 flutter-app 以 git subtree 发布到独立仓库

目标：把本仓库的 `flutter-app/` 目录（含其提交历史）发布到
`https://github.com/owenwangcong/qldazangjingweb-flutter.git`，
之后可双向同步（主仓库推出去 / 子仓库改动拉回来）。

> 所有命令都在**主仓库根目录**（`D:\Projects\Cursor\qldazangjingweb`）执行，
> 当前分支为 `flutter`。git subtree 随 Git for Windows 自带，无需安装。

## 0. 前提
- 在 GitHub 上已创建空仓库 `qldazangjingweb-flutter`
  （**不要**勾选 Initialize with README / .gitignore / license，保持全空，
  否则首次推送会因历史不相关被拒绝）。
- 本地工作区干净（`git status` 无未提交改动）。

## 1. 一次性配置：添加远程
```powershell
git remote add flutter-origin https://github.com/owenwangcong/qldazangjingweb-flutter.git
git remote -v   # 确认 flutter-origin 已添加
```

## 2. 首次推送
```powershell
git subtree push --prefix=flutter-app flutter-origin main
```
- `--prefix=flutter-app`：只取该目录的内容与历史（路径分隔用 `/`，不要写反斜杠）。
- `flutter-origin main`：推送到新仓库的 `main` 分支（不存在会自动创建）。
- 首次会扫描全部历史生成拆分提交，且 `flutter-app/assets` 含约 190MB
  资产（经文 gz + 字体 TTF），**推送较慢属正常**。单文件最大 31.6MB，
  低于 GitHub 100MB 限制，无需 LFS。

## 3. 日常更新：主仓库 → 子仓库
在主仓库正常开发、提交后，随时再执行同一条命令即可增量同步：
```powershell
git subtree push --prefix=flutter-app flutter-origin main
```

### 大仓库提速（可选）
`subtree push` 每次都重新拆分历史，仓库变大后会变慢。可改用先拆分后推送：
```powershell
git subtree split --prefix=flutter-app -b flutter-app-split   # 生成/更新拆分分支
git push flutter-origin flutter-app-split:main                # 推送
git branch -D flutter-app-split                               # 用完即删（可选）
```

## 4. 反向同步：子仓库 → 主仓库
如果有人直接在 qldazangjingweb-flutter 仓库提交了改动：
```powershell
git subtree pull --prefix=flutter-app flutter-origin main --squash
```
- `--squash` 把对方的多次提交压成一个合并提交，保持主仓库历史干净（推荐）。
- 去掉 `--squash` 则完整保留对方逐条提交历史。

## 5. 常见问题
| 现象 | 原因与处理 |
|---|---|
| 首次 push 被拒（fetch first / non-fast-forward） | 新仓库不是空的（带了 README）。处理：`git subtree pull --prefix=flutter-app flutter-origin main --squash --allow-unrelated-histories` 先合并，再 push；或删掉远程仓库重建为全空。 |
| push 卡在 "Counting objects" 很久 | 正常：约 190MB 资产 + 历史拆分。用第 3 节的 split 方式可加速后续推送。 |
| 提示 `'subtree' is not a git command` | Git 版本过旧，升级 Git for Windows（≥2.x 均自带）。 |
| 子仓库的提交 SHA 与主仓库不同 | 预期行为：subtree 会重写提交（仅保留 flutter-app 相关内容），两边 SHA 不互通，同步只能靠 subtree push/pull。 |

## 6. 验证
推送完成后打开
https://github.com/owenwangcong/qldazangjingweb-flutter
应能看到 `lib/`、`assets/`、`pubspec.yaml` 等位于仓库根目录，
且历史中包含 `Auto-migration: ...` 等相关提交。
克隆该仓库后 `flutter pub get && flutter run` 即可独立构建。
