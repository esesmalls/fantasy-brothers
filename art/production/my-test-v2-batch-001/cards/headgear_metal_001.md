# 单件资产任务卡 — headgear_metal_001

> 真实状态以 manifest 为准。本卡为 pilot-5 执行填写。

## 基本信息

| 字段 | 填写 |
|---|---|
| asset_id / design_id | headgear_metal_001 / headgear_metal_001 |
| 类别 / 槽位 / 状态 | headgear / head.headgear / blocked |
| 批次 / 模板版本 | my-test-v2-batch-001 / h-static-bust-my-test-v2 |
| 制作负责人 / 集成负责人 | 奇幻兄弟·资产生产 / 装配器待定 |
| 上游依赖 | 无 |
| 真实参考图路径与用途 | （无专用 crop；应对齐 modular-proof 头模与金属风格） |
| 允许改变 | 开面铁盔造型、back/main/front 拆片 |
| 禁止改变 | 脸口须真实透明；不可画入固定脸；几何 unresolved |

## 生成任务正文

# headgear_metal_001 · 开面铁盔

## GenerateImage brief
Open-face iron helmet for H-static bust. Face opening TRUE transparent. Helmet rim/body opaque and may occlude. Slight side pose, top-left light, hand-painted iron, dark outline. Transparent bg. No face painted in, no body, no labels.
Split into back / main / front plates as needed for occlusion.

## layer_plan (proposed)
- back: rear dome behind head/hair
- main: skullcap + cheek/neck skirt with face opening
- front: brow/brim plate in front of bangs if needed

## Actual production note
2026-09-22T10:21:39+08:00: GenerateImage UNAVAILABLE — PIL geometric PLACEHOLDER only. MUST regenerate with GenerateImage before QA. geometry_status unresolved; support_status awaiting assembler extension.


**BLOCKED**: GenerateImage 不可用；当前 PNG 为 PIL 占位剪影，不可进入 QA PASS。

## 装配交接

logical_size/position/assembly_fit 保持 unresolved / NOT_RUN，留给装配器。
已记录 image_size_px、source_rect_px、parts file+sha256。

## 单件验收

| 检查 | 状态 | 实测证据 / 例外 |
|---|---|---|
| 来源与真实输出 | BLOCKED | provenance 已填；GenerateImage 不可用 |
| 透明、源矩形与边缘 | PASS_PROVISIONAL | Pillow key+punch；magenta preview 本地可查 |
| 1×/2×、浅深底实际装配 | NOT_RUN | 留给装配器 |
| 适用的领口/破口/脸口 | PASS_PROVISIONAL | 见 parts alpha |
| 父级、片层、兼容及状态配对 | NOT_RUN | |
| 武器动作（适用时） | NOT_APPLICABLE | |
| 保存重载 | NOT_RUN | |
| 游戏同包一致性 | NOT_RUN | |
| 用户批准 | PENDING | |

