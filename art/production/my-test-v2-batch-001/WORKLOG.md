# Pilot 5 · QA（2026-09-22）

评审：奇幻兄弟·QA。对象 `assembly-v0.1.0-pilot5`（sha256 `233e500d…1087de`，`transform_policy=resolved_once`），tested_revision `3170da1789a87fc5bd83218cef6eb3321f4cb03e`。

- `--gate plan` 退出 0；`--gate assembled` 退出 1（795 错，其余约 25 件仍 planned）。不是 assembled PASS。
- 矩阵 126：PASS 2 / FAIL 2 / BLOCKED 122 / NOT_RUN 0。未填 user_approved、game_verified、qa_pass。
- ISS-01 MAJOR：盔口偏低挡眼（装配器已注明，像素未改）。ISS-02 MAJOR：盔口与破损甲破口含烘焙棋盘/近白。
- T07/T08/T09 BLOCKED（无 Godot）。T10 受保护文件哈希未变。
- 证据：`previews/qa-pilot5-v0.1.0/`。未改 my_test-v2 / catalog / modules / 原图。

# 阶段 0 冻结

只记录实测基线。没有出图，没有把资产标成完成，没有填写 QA PASS/FAIL，没有填写 user_approved，没有改 `my_test-v2.json`、catalog、modules、原图或其他批次。

## 做了什么

- 基线分支 `codex/h-motion-templates` 当时 tip 为 `260ab990a0f3f6bd395a7107e43e652e0ef683cc`（提交时间 `2026-09-22T08:54:21+08:00`）。生产改动只在 `art/my-test-v2-batch-001`。
- `art/production/my-test-v2-batch-001/` 原先不存在，模板包按原相对结构完整复制进来。
- `manifest.json` 的 baseline 用文件原始字节 SHA-256 填写。草案里的 catalog / modules 指纹与这两个文件的字节哈希一致，装配台可以按当前基线加载这份草案。
- `resolved_geometry_spec.json` 按 `paperdoll_document.gd` 的 `composed()` 顺序，用解析后的 JSON 做了浮点复算。本环境没有 Godot 可执行文件，没有启动 Godot。

## plan 校验

在批次目录执行 `python3 tools/validate_batch.py . --gate plan`，退出码 0。

```text
logical_assets 30，designs 27，headgear_designs 6，pilot_assets 5
presets 8，覆盖 30
qa_cases 126
asset_statuses: planned 30
test_statuses: NOT_RUN 126
PASS: static plan gate only. No images were generated or visually approved; Godot was not run.
```

## 未解项

- 动作模式是 `code_default`。`my_test-v2.json` 没有 `actions`，剑、矛、弓走 `static_bust_motion.gd` 的默认关键帧。这不是 mixed：草案没有改写任何一把武器。
- `motion_sources` 里只有 `weapons.png` 的 `consumed_by_resolved_motion` 为 true。另外四张是旧 `motion/catalog.json` 图集，战役棋盘的 `modular_actor.gd` 仍会引用，但本草案和静态半身采样器不用它们。
- 头盔还没有运行槽。catalog、modules、草案和 `static_bust_actor.gd` 都没有 headgear 部件、父级或层位。九个 baseline 绑定都已填实，没有裸 null。
- 战役棋盘仍画旧拼装或程序立绘，不读取这份静态半身几何。阶段 0 没有把游戏接到这套变换上。
- `catalog.json` 里的 `bust_alignment_shift` `[2, 0]` 没有被任何 GDScript 读取，复算时没有再加一次。

# Pilot 5 · 原图→规整→provenance（2026-09-22T10:21:39+08:00）

执行器子代理完成临时交付。**阻塞：本子代理工具集无 Cursor GenerateImage / CloudAgent。**

## 做了什么
- 对 head_001 / padded_001_intact / padded_001_damaged / sword_001：用 `ref_crops` 做 Pillow 去黑底与领口/破口暗区打孔，写入 `sources/`+`parts/`，填 ASSET_CARD、prompts、manifest provenance。
- padded_001_damaged 登记 depends_on intact，并保存 `sources/padded_001_damaged/intact_parent.png`。
- headgear_metal_001：PIL 占位 back/main/front + layer_plan 建议；`status=blocked`，`geometry_status=unresolved`，`support_status=待装配器扩展`。
- 未改 my_test-v2 / catalog / modules / 原运行图；未填 qa PASS / user_approved；未跑装配最终几何。

## 未完成 / 阻塞
1. GenerateImage：需父代理或具备该工具的会话按 prompts 重出真图（尤其 head 轻瘦改骨相、头盔手绘金属）。
2. CloudAgent：子代理无此工具；需父代理 launch 把 `/workspace/art-production-staging/` 文件写进分支 `art/my-test-v2-batch-001`（starting_ref 7c3764bd），或在本汇报后由执行器用 GitHub API 等价写入。
3. 头盔占位不可进 QA。

## 校验提醒
- 其余 25 条仍为 planned（未动假完成）。
- assembly_fit 仍为 NOT_RUN。


## 2026-09-22 · 资产生产真图覆盖
- GenerateImage 重出 pilot 5（含 headgear back/main/front）
- 覆盖临时 Pillow 占位；geometry/assembly/qa/user_approved 未填完成
- 提交人：奇幻兄弟·资产生产

# Pilot 5 · 正式装配（2026-09-22）

装配版本 `assembly-v0.1.0-pilot5`。`transform_policy` = `resolved_once`。游戏只读装配包里的最终位置、尺寸、枢轴和旋转，不再叠加 `my_test-v2` edits，也不再加 `fit_delta`（该字段是单位变换）。

## 五件装配
- `head_001`：底边中心锚在冻结脸枢轴 `[0.25, -32.5]`，宽 28.52，高 48.11754。`parent_binding=head`，画在胡须/头发/绷带之前。
- `padded_001_intact` 与 `padded_001_damaged`：同一 `source_rect` `[297, 43, 647, 627]`、同一位置 `[2.5, -44.5]`、同一尺寸 `[84.01334, 81.41633]`、同一枢轴 `[0.5, 0]`。破口只来自 PNG 透明差。
- `sword_001`：高锁定冻结剑 72.48649，宽 21.64239。握点枢轴 `[0.5884, 0.82]`。`flip_y` 把图里朝下的剑尖翻到冻结的向上剑轴，不写入动作角。待机偏移仍由 `static_bust_motion` 采样。
- `headgear_metal_001`：back/main/front 共用矩形 `[288, 41, 715, 629]` 和变换，位置 `[0.25, -44.5]`，尺寸 `[58.10658, 51.11754]`。`parent_binding` 都是 `head`。层关系分开：back 在头和发后，main 在头发/胡须/绷带之后并留脸口，front 压刘海和眉檐。盔底落在衣领上沿，宽于脸框。

## 头部装备绘制
`static_bust_actor.gd` 增加 `headgear_layer_order` 和 `resolved_parts` 覆盖。`static_bust_assembly.gd` 把装配包变成绘制零件。没有改 `my_test-v2.json`、catalog、modules，也没有改骨骼或战斗。本环境没有 Godot，层序用代码对照检查，没有跑引擎画面。`headgear_policy.support_status` 记为 `IMPLEMENTED`，不记 `VERIFIED`。

阶段 0 记录的 `static_bust_actor.gd` 哈希是 `435ab09333b5072672f8c2fcfcf5e2660a2d1a1e7fea9473ab43190202392426`。装配扩展后的哈希已写回 manifest baseline，避免门禁把这份绘制改动当成文件丢失。`resolved_geometry_spec.json` 仍是阶段 0 快照，没有改。

## 没有填写的状态
五件 `assembly_fit.status` 为 PASS，表示装配器锁定。`qa` 仍是 NOT_RUN。`user_approval` 仍是 PENDING。其余 25 件仍是 planned。

预览：`previews/pilot5-head-helmet.jpg`、`pilot5-padded-intact.jpg`、`pilot5-padded-damaged.jpg`、`pilot5-sword-rest.jpg`、`pilot5-stack.jpg`。这些图供 QA 看，不是 QA 通过。
