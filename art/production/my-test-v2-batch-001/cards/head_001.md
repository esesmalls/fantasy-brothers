# 单件资产任务卡 — head_001

> 真实状态以 manifest 为准。本卡为 pilot-5 执行填写。

## 基本信息

| 字段 | 填写 |
|---|---|
| asset_id / design_id | head_001 / head_001 |
| 类别 / 槽位 / 状态 | head / head.face / registered |
| 批次 / 模板版本 | my-test-v2-batch-001 / h-static-bust-my-test-v2 |
| 制作负责人 / 集成负责人 | 奇幻兄弟·资产生产 / 装配器待定 |
| 上游依赖 | 无 |
| 真实参考图路径与用途 | ref_crops/face_ref.png（骨相风格）；refs/modular-proof.png（共同朝向光照） |
| 允许改变 | 骨相与五官（轻瘦长脸方向） |
| 禁止改变 | 共同轻侧、短颈、装配边界、非目标层 |

## 生成任务正文

# head_001 · 轻瘦长脸

## GenerateImage brief
Fantasy Brothers H-static bust modular FACE ONLY. Lean elongated bald male head, three-quarter view facing viewer's right, short neck kept, compact silhouette. Clear dark brown-black outline, hand-painted brush strokes, fixed top-left key light. Transparent background. No hair, beard props, body, clothing, hands, pedestal, scene, or labels. Only change bone structure and features toward a lighter leaner longer face; keep shared slight-side pose, short neck, assembly bounds.

## References (must load)
- /workspace/pilot-batch001/ref_crops/face_ref.png (structure/style)
- /workspace/pilot-batch001/refs/modular-proof.png (shared pose/light)

## Aspect
3:4

## Actual production note
2026-09-22T10:21:39+08:00: Cursor GenerateImage tool NOT available to executor subagent. Provisional part = face_ref crop with black-bg keyed to alpha. Needs GenerateImage regen for true lean-longer redesign.




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
| 武器动作（适用时） | NOT_APPLICABLE | |
| 保存重载 | NOT_RUN | |
| 游戏同包一致性 | NOT_RUN | |
| 用户批准 | PENDING | |

