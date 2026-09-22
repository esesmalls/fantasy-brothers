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
