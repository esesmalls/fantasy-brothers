# GitHub 同步记录

更新：2026-09-17，首次同步已完成。

## 目标

将本项目同步到 GitHub 用户 `esesmalls` 名下的仓库 `fantasy-brothers`。当前远端已由用户创建为公开仓库；后续如需隐藏源码，再单独调整可见性。

## 本地准备

- 当前工作区已初始化本地 `.git`，分支为 `main`；尚未创建首个提交，不能从远端覆盖本地文件。
- `.gitignore` 排除了 Godot 编辑器下载包、导出模板、构建输出、Godot 生成状态、个人存档与常见凭据文件。
- `tools/fetch_windows_templates.py`、`tools/godot/SHA512-SUMS.txt` 和导出模板的 `source.json` 保留，便于追溯工具来源与重新下载。
- `.gitattributes` 统一文本文件换行，并将媒体和二进制标为二进制文件。

## 认证与远端状态

截至本记录更新时，GitHub 连接器已确认当前授权用户为 `esesmalls`，并确认 `esesmalls/fantasy-brothers` 已创建、可写，默认分支为 `main`。仓库当前为公开可见性，保留用户创建时的设置；本机已完成首次提交并推送，CLI 凭据不写入项目。

首次同步完成后，按以下顺序复核：

1. 查询 `esesmalls/fantasy-brothers` 是否存在及其可见性。
2. 确认本地 remote 指向 `https://github.com/esesmalls/fantasy-brothers.git`。
3. 提交前确认待提交清单不含被排除的下载包、模板、构建物、存档或凭据。
4. 推送 `main` 后核对远端提交哈希与本地一致。

已记录提交哈希、远端 URL 和因忽略规则未同步的本地文件；不得把认证信息写入本文件或仓库。

## 首次同步结果

- 提交：`0f02560`（Build playable prototype vertical slice）
- 远端：`https://github.com/esesmalls/fantasy-brothers.git`
- 分支：`main`
- 已排除：`builds/`、Godot 可执行文件与导出模板、`.godot/`、运行日志和本地存档。
