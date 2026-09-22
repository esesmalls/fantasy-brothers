# 批次QA · my-test-v2-batch-001 · pilot5

> 2026-09-22 已执行 pilot 5 验收。未填 `user_approved`，未填 `game_verified`，未把任何资产标成 `qa_pass`。`validate_batch --gate plan` 通过不等于美术/游戏通过。

完整证据：`art/production/my-test-v2-batch-001/previews/qa-pilot5-v0.1.0/`

## 1. 验收对象

| 字段 | 填写内容 |
|---|---|
| 批次 | `my-test-v2-batch-001`（只测 pilot 5） |
| 实际代码提交 | `3170da1789a87fc5bd83218cef6eb3321f4cb03e`（Lock pilot-5 assembly as a resolved_once package） |
| 基线配置哈希 | `my_test-v2.json` `da687e7979965d4ffa0b272f4358fdeee74b5310f9af0756da6ba71b1fc836f7`；catalog `b411dfd57a4efb9bbf1c866f2d37f8dbfbc351d838431da5403719e1c678123e`；modules `9976573dc1f5fbcbfe1936cbb261970a5b49ae24569ef3e961cff71cd9e017b5` |
| 装配包版本与哈希 | `assembly-v0.1.0-pilot5` / `transform_policy=resolved_once` / sha256=`233e500d8735fdfac023927b74c33e836d6f6535bb1432b5075aab151a1087de`（与文件字节一致） |
| 引擎/导出包版本 | 本环境无 Godot 可执行文件（`tools/godot/` 仅有 SHA512-SUMS.txt）。未读取引擎版本，未导出游戏包 |
| 测试环境 / 日期 / 人员 | Cursor Cloud Linux VM；Python 3 + Pillow 12.3.0；2026-09-22；奇幻兄弟·QA |
| 1×定义 | 装配包解析后的战场逻辑像素（头约 28.52×48.12，绗缝约 84.01×81.42），不是源 PNG 1:1 |
| 未运行项 | 游戏一致性、保存重载、动作时间轴、发须压发、衣领三层、8 套整人预设；见矩阵 BLOCKED |

Pilot 资产：`head_001`、`padded_001_intact`、`padded_001_damaged`、`sword_001`、`headgear_metal_001`（back/main/front）。

## 2. 结果口径

- `PASS`：该项真实执行，证据、资产与装配版本对应。
- `FAIL`：执行且不满足期望，记录缺陷编号。
- `NOT_RUN`：未执行，不能折算为通过。
- `BLOCKED`：由于依赖或能力缺失不能执行，写明阻塞。
- `NOT_APPLICABLE`：该项确实不适用，必须写理由；不能用于跳过本批强制检查。

每个逻辑资产单独通过技术、装配视觉、保存重载，以及适用的领口/头口/动作检查后，才可写 `qa_pass`。游戏检查真实通过后才能写 `game_verified`。用户批准单列，不由自动脚本修改。本轮没有写这三项完成状态。

## 3. 通用检查表

| 编号 | 检查 | 通过条件 | 状态 | 证据 |
|---|---|---|---|---|
| T01 | 文件和来源 | 真实图像存在；可追溯参考、提示词和原始输出；未知模型如实写unknown | PASS | `previews/qa-pilot5-v0.1.0/HASHES.md`；五件卡片与 `parts/`、`sources/`、`prompts/` |
| T02 | 透明和边缘 | alpha真实；无烘焙棋盘格、黑白背景、跨格污染；实体不整体半透明 | FAIL | ISS-02；`iss02_helmet_opening_rgb_noalpha.png`、`iss02_*_flatten_magenta.jpg`。头/完好甲/剑洋红底干净 |
| T03 | 源矩形与配准 | rect合法；图像与逻辑尺寸分开；不非等比拉伸，不单独按可见外框重缩放配对图 | PASS | `analysis.json` aspects 全部 uniform；padded 与头盔族共用 source_rect |
| T04 | 装配几何 | 共同模板、锚点、父子变换、裁取正确；健康和损坏切换不跳位 | PASS | padded 完好/破损同一 position/size/pivot；头盔三片同一变换；`padded_intact_damaged_pair_checker.png` |
| T05 | 层序与开口 | 前片开口透出实际内层；实体遮挡合理；不是固定黑腔或预画脸/衬甲 | FAIL | ISS-01、ISS-02；`iss01_helmet_opening_low.png`、`hgw01_resolved_full_combo.png` |
| T06 | 1×/2×可读性 | 同批准母版对照；浅深底边缘正常；小尺寸身份与状态可辨 | FAIL | `t06_1x_dark_nn8.png`、`t06_1x_damaged_nn8.png`：盔/甲/剑可辨，脸不可读，破口发白 |
| T07 | 保存与版本 | 持久保存稳定ID和装配版本；重载不变化；扩库不导致旧人换脸 | BLOCKED | 无纸娃娃装配台/Godot，不能保存关闭重载 |
| T08 | 动作 | 适用武器沿冻结路径实际检查；箭与弓连接、尖端与结果位置正确 | BLOCKED | 无动作运行时。静态 `sword_source_vs_flipy.png` 只证明 flip_y，不是动作 PASS |
| T09 | 装配/游戏一致 | 同包同版本同原点同尺度同时间；没有额外槽位修正或重复套用edits | BLOCKED | 无 Godot，未跑游戏 |
| T10 | 原基线回归 | 原my_test-v2与原资源保护；空头盔槽不改变既有渲染 | PASS | HASHES.md 中受保护文件全部 match。空盔槽实机画面未跑（无 Godot），记在 PIPE-02 |

## 4. 头部装备专项

脸口应是含开口前片的真实透明窗口。本轮 `headgear_metal_001`：

- 拆片存在：back / main / front，共用矩形与变换，`parent_binding=head`，层关系分开声明。
- **HGW-01 FAIL**：隔离 main（隐藏后片）后窗口可见，但窗口内有烘焙棋盘（ISS-02）；完整组合里最近内层是脸，却被放在口鼻带，眼睛被帽檐盖住（ISS-01）。
- **HGC-01 BLOCKED**：缺 `linen_001`、`mail_001_intact`，不能做亚麻/绗缝/链甲衣领关系。
- **发/须压发 BLOCKED**：`hair_*`、`beard_*` 均未交付。`HG-01-01`–`04` 已写 missing assets。
- 装配器说明盔可以比脸框大，本轮确认盔宽于脸；问题是开口位置和 alpha，不是「盔比脸大」本身。

## 5. 组合测试矩阵

`qa_matrix.json` 126 条均已填状态、理由、证据路径、`tested_revision`、`reviewer=奇幻兄弟·QA`。

| 家族 | 用例数 | 本轮 |
|---|---:|---|
| `pipeline` | 6 | PIPE-01 PASS；PIPE-02…06 BLOCKED（无 Godot/装配台） |
| `face_hair` / `face_beard` | 32 | 全部 BLOCKED（缺发/须，多数还缺其它头） |
| `head_overlay` | 8 | BLOCKED（无装配台开 baseline 伤痕/绷带；head_002–004 缺资产） |
| `headgear_pairwise` | 24 | 全部 BLOCKED（缺发须或其它盔） |
| `headgear_opening_isolation` | 6 | HGW-01 FAIL；HGW-02…06 BLOCKED |
| `headgear_collar` | 6 | 全部 BLOCKED（缺亚麻/链甲或其它盔） |
| `wear_opening` | 24 | intact-NONE PASS；damaged-NONE FAIL；其余 BLOCKED |
| `preset` | 8 | 全部 BLOCKED（每套都缺 pilot 以外资产） |
| `motion` | 12 | 全部 BLOCKED（无动作运行时；矛弓盾还缺资产） |

## 6. 8套整人预设

仍不能加载。`SET-preset_01` 已因缺 hair/beard/linen/shield 标 BLOCKED，不是 NOT_RUN。

## 7. 缺陷登记

| issue_id | 资产/预设 | 实测版本 | 问题与复现步骤 | 严重度 | 返修对象 | 状态 | 证据 |
|---|---|---|---|---|---|---|---|
| ISS-01 | headgear_metal_001 | assembly-v0.1.0-pilot5 / 3170da1 | 叠 head+back+main+front（解析变换或现有 pilot5-head-helmet.jpg）。帽檐盖眼，窗口在口鼻/下颌。像素未改。 | MAJOR | 装配 / 原画 | OPEN | `previews/qa-pilot5-v0.1.0/iss01_helmet_opening_low.png` |
| ISS-02 | headgear_metal_001.main, padded_001_damaged | 同上 | 读 PNG 开口/破口像素；RGBA 铺洋红后存 JPEG。盔口为不透明灰白格；破损甲破口有不透明近白。 | MAJOR | 原画 | OPEN | `previews/qa-pilot5-v0.1.0/iss02_helmet_opening_rgb_noalpha.png`、`iss02_padded_damaged_flatten_magenta.jpg` |

严重度：BLOCKER 用于基线破坏、无法加载或错误规则绑定；MAJOR 用于可见穿插、错误开口、配对跳位或装配/游戏不一致；MINOR 用于不影响结构的局部材质问题。正式用户审核仍可因美术问题退回。

## 8. 汇总

| 指标 | 本轮实测 |
|---|---:|
| 计划逻辑资产 | 30 |
| 实际生成（pilot） | 5 |
| 装配QA通过（qa_pass） | 0 |
| 游戏一致性通过 | 0 |
| 用户批准 | 0 |
| PNG实际数量 | 7 张 part（头/完好甲/破损甲/剑/盔三片）+ 对应 sources |
| 用例 PASS | 2 |
| 用例 FAIL | 2 |
| 用例 BLOCKED | 122 |
| 用例 NOT_RUN | 0 |
| `--gate plan` | 退出 0（静态计划门） |
| `--gate assembled` | 退出 1，795 个错误；其余约 25 件仍 planned |

汇总以 manifest 和用例结果为准。QA 脚本没有把 `NOT_RUN` 改成 `PASS`。`user_approved` 未填。

## 9. 最终交给用户看的内容

- 本文件 + `previews/qa-pilot5-v0.1.0/SUMMARY.md`、`ISSUES.md`
- 盔口偏低与烘焙棋盘证据图
- `validate_plan.log` / `validate_assembled.log`
- 8 套人物总览、发须压发、衣领三层、武器动作、游戏同屏：本环境不能做，已 BLOCKED
