# QA SUMMARY · my-test-v2-batch-001 · pilot5

| 字段 | 值 |
|---|---|
| 批次 | my-test-v2-batch-001 |
| 范围 | pilot 5 only |
| tested_revision | `3170da1789a87fc5bd83218cef6eb3321f4cb03e` |
| 装配包 | `assembly-v0.1.0-pilot5` |
| 装配 JSON sha256 | `233e500d8735fdfac023927b74c33e836d6f6535bb1432b5075aab151a1087de`（与期望一致） |
| transform_policy | `resolved_once` |
| 评审 | 奇幻兄弟·QA |
| 日期 | 2026-09-22 |
| 环境 | Cursor Cloud Linux VM；Python 3.9+；Pillow 12.3.0；**无 Godot 可执行文件** |
| user_approved | 未填 |
| game_verified | 未填 |
| qa_pass（manifest 资产） | 未填 |

本目录只做合成与取样，没有用图像模型重画。

## 用例计数（qa_matrix.json，126）

| 状态 | 数量 |
|---|---:|
| PASS | 2 |
| FAIL | 2 |
| BLOCKED | 122 |
| NOT_RUN | 0 |
| NOT_APPLICABLE | 0 |

PASS：`PIPE-01`，`WEAR-padded_001_intact-NONE`  
FAIL：`HGW-01`，`WEAR-padded_001_damaged-NONE`  
其余为 BLOCKED（缺后续波次资产，或无 Godot/装配台/动作运行时）。

## T01–T10

| 编号 | 状态 | 摘要 |
|---|---|---|
| T01 | PASS | 五件 pilot 图、提示、卡片、raw、装配哈希一致。见 HASHES.md |
| T02 | FAIL | ISS-02：盔口与破损甲破口有烘焙棋盘/近白填实。头、完好甲、剑洋红底干净 |
| T03 | PASS | 全部解析层 source_rect 在界内；逻辑宽高比与源矩形一致；完好/破损共用矩形 |
| T04 | PASS | padded 完好/破损同一位置尺寸枢轴；头盔三片同一变换；未见跳位 |
| T05 | FAIL | ISS-01 脸口偏低挡眼；ISS-02 窗口不是真透明。破损甲破口也不能稳定露内层 |
| T06 | FAIL | 1× 盔型/绗缝/剑可辨；脸因 ISS-01 不可读；破损 1× 破口发白（ISS-02） |
| T07 | BLOCKED | 无纸娃娃装配台/Godot，不能保存重载 |
| T08 | BLOCKED | 无动作运行时。剑只做了静态 flip_y 对照 |
| T09 | BLOCKED | 无 Godot，未跑游戏，未填 game_verified |
| T10 | PASS | my_test-v2 / catalog / modules / 原 static-bust PNG 哈希与 manifest 一致。空盔槽实机画面未跑 |

## 头部装备专项

| 用例 | 状态 | 原因 |
|---|---|---|
| HGW-01 | FAIL | ISS-01 + ISS-02；隔离 main 与完整组合都做了 |
| HGC-01 | BLOCKED | 缺 linen_001、mail_001_intact |
| HG-01-01…04 | BLOCKED | 缺 hair/beard（部分还缺 head_002） |

## 缺陷

见 [ISSUES.md](ISSUES.md)。

1. **ISS-01 MAJOR** 头盔脸口偏低，眼睛被帽檐盖住。装配器已注明，像素未改。
2. **ISS-02 MAJOR** 盔口与破损甲破口含烘焙棋盘/不透明近白。

## validate_batch.py

命令：`python3 art/production/my-test-v2-batch-001/tools/validate_batch.py art/production/my-test-v2-batch-001 --gate <plan|assembled> --project-root .`

### --gate plan

退出码 **0**。静态计划门通过。这不是美术或游戏验收。

首次运行（改矩阵前，126×NOT_RUN）见 [validate_plan.log](validate_plan.log)。  
矩阵写入后再跑见 [validate_plan_after_matrix.log](validate_plan_after_matrix.log)：`PASS 2 / FAIL 2 / BLOCKED 122`，资产 `registered 5 / planned 25`。

### --gate assembled

退出码 **1**。**不要写成 assembled PASS。**

[validate_assembled.log](validate_assembled.log)：`FAIL: 795 error(s) at gate=assembled`。  
原因包括：25 件仍 planned；5 件 registered 但未到 `qa_pass`；预设/用例未到 assembled 门槛。与「其余约 25 件仍是计划」一致。

`validate_batch` 过 plan ≠ 美术通过 ≠ 游戏通过。

## 引擎

`tools/godot/` 只有 `SHA512-SUMS.txt`，没有引擎二进制。T07/T08/T09 与 game 门控用例均为 BLOCKED，理由：无 Godot。

## 证据文件

- HASHES.md, ISSUES.md, analysis.json
- validate_plan.log, validate_plan_after_matrix.log, validate_assembled.log
- iss01_*.png, iss02_*.png / *.jpg
- hgw01_*.png, wear_*.png, t02_*.jpg, t06_*.png
- resolved_*.png, padded_intact_*.png, sword_source_vs_flipy.png
- alpha_*_magenta.png / alpha_*_checker.png
