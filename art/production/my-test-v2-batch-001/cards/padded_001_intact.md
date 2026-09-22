# 单件资产任务卡 — padded_001_intact

> 真实状态以 manifest 为准。本卡为 pilot-5 执行填写。

## 基本信息

| 字段 | 填写 |
|---|---|
| asset_id / design_id | padded_001_intact / padded_001 |
| 类别 / 槽位 / 状态 | armor / body.armor / registered |
| 批次 / 模板版本 | my-test-v2-batch-001 / h-static-bust-my-test-v2 |
| 制作负责人 / 集成负责人 | 奇幻兄弟·资产生产 / 装配器待定 |
| 上游依赖 | 无 |
| 真实参考图路径与用途 | ref_crops/padded_intact_ref.png；refs/full-garments-nested.png |
| 允许改变 | 绗缝材质细节、完好态衣甲 |
| 禁止改变 | 朝向、共同标尺、领口须真实透明、不附带身体脸手 |

## 生成任务正文

# padded_001_intact · 纵线绗缝甲·完好

## GenerateImage brief
Standalone padded armor torso+sleeves only for H-static bust. Vertical-line quilted gambeson (or match ref quilting), complete intact state. Shared body scale, slight side facing right, top-left light, hand-painted, dark outline. TRUE transparent collar opening (alpha=0) showing underlayer when assembled. Transparent background. No face/body/inner clothes/hands/scene/labels.

## References
- /workspace/pilot-batch001/ref_crops/padded_intact_ref.png
- /workspace/pilot-batch001/refs/full-garments-nested.png

## Aspect
3:4

## Actual production note
2026-09-22T10:21:39+08:00: GenerateImage unavailable. Provisional = padded_intact_ref with bg keyed + interior dark collar punched to alpha=0.




## 装配交接

logical_size/position/assembly_fit 保持 unresolved / NOT_RUN，留给装配器。
已记录 image_size_px、source_rect_px、parts file+sha256。

## 单件验收

| 检查 | 状态 | 实测证据 / 例外 |
|---|---|---|
| 来源与真实输出 | PASS_PROVISIONAL | provenance 已填；GenerateImage 不可用 |
| 透明、源矩形与边缘 | PASS_PROVISIONAL | Pillow key+punch；magenta preview 本地可查 |
| 1×/2×、浅深底实际装配 | NOT_RUN | 留给装配器 |
| 适用的领口/破口/脸口 | PASS_PROVISIONAL | 见 parts alpha |
| 父级、片层、兼容及状态配对 | NOT_RUN | |
| 武器动作（适用时） | NOT_APPLICABLE | |
| 保存重载 | NOT_RUN | |
| 游戏同包一致性 | NOT_RUN | |
| 用户批准 | PENDING | |

