# 单件资产任务卡 — sword_001

> 真实状态以 manifest 为准。本卡为 pilot-5 执行填写。

## 基本信息

| 字段 | 填写 |
|---|---|
| asset_id / design_id | sword_001 / sword_001 |
| 类别 / 槽位 / 状态 | weapon / weapon.main / registered |
| 批次 / 模板版本 | my-test-v2-batch-001 / h-static-bust-my-test-v2 |
| 制作负责人 / 集成负责人 | 奇幻兄弟·资产生产 / 装配器待定 |
| 上游依赖 | 无 |
| 真实参考图路径与用途 | ref_crops/sword_ref.png；refs/weapons.png |
| 允许改变 | 旧铁磨损细节 |
| 禁止改变 | 无手；风格对齐现有剑；透明底 |

## 生成任务正文

# sword_001 · 旧铁直剑

## GenerateImage brief
Old iron straight sword alone, no hand. Vertical, weathered blade with fuller, simple crossguard, leather grip, disc pommel. Match existing sword style. Top-left light, dark outline, hand-painted. Transparent background. No hand/body/scene.

## References
- /workspace/pilot-batch001/ref_crops/sword_ref.png
- /workspace/pilot-batch001/refs/weapons.png

## Aspect
9:16 or 3:4

## Actual production note
2026-09-22T10:21:39+08:00: GenerateImage unavailable. Provisional = sword_ref with black bg keyed.




## 装配交接

logical_size/position/assembly_fit 保持 unresolved / NOT_RUN，留给装配器。
已记录 image_size_px、source_rect_px、parts file+sha256。

## 单件验收

| 检查 | 状态 | 实测证据 / 例外 |
|---|---|---|
| 来源与真实输出 | PASS_PROVISIONAL | provenance 已填；GenerateImage 不可用 |
| 透明、源矩形与边缘 | PASS_PROVISIONAL | Pillow key+punch；magenta preview 本地可查 |
| 1×/2×、浅深底实际装配 | NOT_RUN | 留给装配器 |
| 适用的领口/破口/脸口 | NOT_APPLICABLE | 见 parts alpha |
| 父级、片层、兼容及状态配对 | NOT_RUN | |
| 武器动作（适用时） | NOT_RUN | |
| 保存重载 | NOT_RUN | |
| 游戏同包一致性 | NOT_RUN | |
| 用户批准 | PENDING | |

