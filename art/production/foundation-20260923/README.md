# 基础素材库 · 2026-09-23

本批已登记60个可替换基础项、1个统一底座、8件对应衣甲损坏图。`manifest.json` 中 `ready` 的61项包含底座，`ready_damage` 为8项，两个 pending 列表均为空。损坏图不计入每类四种的数量。

15类为：身体、脸、发型、胡须、内衣、衬甲、外甲、盾、剑/刀、斧、矛、弓、伤痕、绷带、血迹。文件位于 `assets/`，稳定ID见清单。四身体共用装配规格；新增身体依用户补充使用平滑低细节胸部，不改变肩颈和衣甲接口。

## 来源与加工

现有合格01素材及两件01损坏图从已认可图集裁取；其他变体由 Codex 内置 image_gen 独立生成或编辑。`manifest.json` 逐项记录原图路径、完整提示、工具和裁切范围，`sources/` 保留可重导母稿。生成记录不是第三方录音的许可说明；本目录没有外购素材。

相关原图批次保留各自的完整过程与来源：

- `../bodies-20260923/`：新增身体三件；保留首次审核拒绝与用户修改设计后的成功记录，04完成一次肤色修正。
- `../weapons-20260923/`：九件剑、矛、弓的新增原图与缩小预览。
- `../garment-openings-20260923/`：五件衣甲真实透明领腔修订。后领自身材料和横扣保留，不预画固定内层。
- `../terminal-20260923/`：另两件倒地/死亡地面覆盖，由发布工具合并，不计入基础60项。
- `../audio-20260923/`：独立记录录音作者、CC0许可、原地址及加工关系。

`tools/prepare_foundation_assets.py` 只裁切、整理透明边和缩放至装配画布，不用同图改名或改色凑变体。重导生产草案的命令为仓库根目录下 `python tools/prepare_foundation_assets.py`。这会更新 `foundation.asset.json`；不要用它覆盖用户已精调的 ready 工程。

## 装配与发布

生产草案：`art/workbench/projects/foundation.asset.json`。交接工程：`art/workbench/projects/foundation-ready.asset.json`，由根目录 `Foundation.cmd` 打开。动作模板与终局覆盖由 `game/tools/prepare_foundation_release.gd` 加入，发布仍使用现有资产版本及回退接口。已有 `current.asset.json` 和 `my_test` 保留。

此批提供基础对位；生成编辑带来少量轮廓和纹理变化，用户负责精确位置、比例、层序、武器握点、终局倒姿及动作观感。匹配损坏图保留母件结构；不要求逐像素轮廓重合。皮甲损坏图已目视与领口/前襟透明采样确认，未因抗锯齿和小幅轮廓差异追加迭代。

## 验证与交接

发布后基础库检查182项通过，覆盖60项独立文件、透明导入、全员组合、实际装备映射、动作以及损坏/终局素材。最终 Windows 包在工作区外使用包内资源完成148项流程检查，零失败；包含换斧、战斗、结算、返营与读档。截图及报告在 `builds/foundation/qa/`，版本与文件摘要在 `builds/foundation/release.json`。

这是自动化规则与界面验证，不等于用户最终美术/主观声音验收。具体装备对应素材及动作ID见 `docs/31-foundation-handoff.md`，完整项目状态见 `docs/STATUS.md`。
