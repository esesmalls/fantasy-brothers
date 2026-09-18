# GitHub 同步记录

更新：2026-09-18，首次同步已完成并已跨对话核对。

## 第三台电脑 0.1.1 接续

本轮基线为 `88c55c8`，实施前与收尾时均只读核对远端 main 相同，未覆盖其他电脑的提交。本轮包含战斗可读性、友军通行、两路线与旧档兼容；本地使用 `codex/battle-readability-routes` 隔离交付提交后快进 main，同步至原仓库。最终哈希以 Git 历史为准，不在同一提交中自引用哈希。未发布 Release。

试玩包为 `builds/FantasyBrothers-0.1.1-windows.zip`，不会随源码推送；其他电脑可复制该压缩包或拉取后重建。个人存档也不经 Git 同步，转移规则见 `docs/10-framework-roadmap.md`。

## 目标

将本项目同步到 GitHub 用户 `esesmalls` 名下的仓库 `fantasy-brothers`。当前远端已由用户创建为公开仓库；后续如需隐藏源码，再单独调整可见性。

## 本地准备

- 当前工作区已初始化本地 `.git`，分支为 `main`，已完成首个实现提交与同步记录提交。继续工作时先核对本地更改和远端历史，不能直接以远端覆盖本地文件。
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

2026-09-18 主任务接续复核：本地 HEAD、origin/main 与实时查询远端 main 均为 `025e8af891c933c0b2699264b4b0bb2575486b5e`，工作树当时干净。接受已提交的存档规范化和 AI 绕行修复，以该提交为基线完成交付检查。后续维护提交以 Git 历史为准，避免在同一提交的文件中记录自身哈希。
