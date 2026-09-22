# 《奇幻兄弟》首批资产生产模板包

批次：`my-test-v2-batch-001` · 基线：用户确认的 `my_test-v2` · 整理日期：2026-09-21。

**这是可放进仓库维护的计划与验收模板，不是已生成的资产。** 没有新PNG，没有运行Godot，也没有修改远端仓库。使用时需先读取实际工作区、配置与规范；本包未重新核验最新仓库提交。

## 重要修正

上一份v2提示词的类别相加为24+6=**30个逻辑资产**，不是26。它们对应27款造型，包含三款护甲各自的正常/破损状态。6件头部装备可能各拆1～多张图，但仍计6件；图集页数和PNG数不作为产量。

## 文件入口

| 文件 | 用途 |
|---|---|
| BATCH_PLAN.md | 30项计划、首轮5项闭环与批次边界 |
| manifest.json | 30项初始台账，稳定ID、配对、来源、几何、兼容和QA；状态是唯一维护来源 |
| MANIFEST_GUIDE.md | 字段语义、尺寸权责、装配包交付与头部层位约束 |
| presets.json | 8套计划组合，静态引用覆盖30项；尚未导出可加载预设 |
| qa_matrix.json | 126条待执行用例，全部NOT_RUN；不等于已支持全组合 |
| QA.md | 检查表、证据、缺陷、用户评审与汇总模板 |
| templates/ASSET_CARD.md | 单件生产/装配/验收任务卡 |
| tools/validate_batch.py | Python 3.9+标准库静态校验器；只读，不生成图、不自动批准 |
| tools/TEMPLATE_SELF_CHECK.json | 本模板的11项校验器自检记录，不是资产QA |

## 放入项目

建议完整放到 `art/production/my-test-v2-batch-001/`，已有同名批次时先检查内容，不覆盖；可使用新后缀目录。不要替换根目录 `my_test-v2.json`、原catalog或modules。

本包三个JSON均为**生产管理/测试计划格式**，不是Godot已有运行格式。执行AI需读取实际代码后将结果导出为现有装配台可支持的候选包，必要时实现最小适配。

生成原始图、规整图、实际候选包和证据时再创建sources、parts、exports、previews等子目录；目录名可以遵循仓库现有惯例，不提前在manifest填假路径。

## 使用顺序

1. 读BATCH_PLAN与MANIFEST_GUIDE，冻结真实基线，补齐哈希、bindings和resolved geometry spec。
2. 按manifest的5个pilot资产完成生成→装配→导出→游戏一致性小闭环，再做25项扩充。
3. 真实执行QA矩阵与8套预设检查，记录版本化证据和异常；未运行保持NOT_RUN。
4. 交付总览与例外清单，由用户批准。自动检查不填user_approved。

## 校验命令

在模板目录运行；若系统Python命令为python3，用python3替换python。

```bash
# 只检查模板结构/计数/引用/组合覆盖，不要求资产已经存在
python tools/validate_batch.py . --gate plan

# 完成装配候选后检查文件、哈希与所声明的装配验收状态
python tools/validate_batch.py . --gate assembled --project-root /你的项目绝对路径

# 游戏一致性也实际完成后，再检查游戏交付门槛
python tools/validate_batch.py . --gate game --project-root /你的项目绝对路径
```

初始模板只应通过plan检查；assembled和game应拒绝未完成数据。校验器发现缺项退出1，结构通过退出0；这不是美术或游戏运行验收。它不会改文件或联网，也不需要额外pip包。

## 直接交给工作AI

```text
继续执行当前已确定的H/my_test-v2资产生产方案，并采用此模板包。
将本批范围更正为30个逻辑资产、27款造型；头部装备拆片不额外计数。
先读BATCH_PLAN.md、MANIFEST_GUIDE.md与仓库当前规范，补齐真实基线和最终几何快照。
manifest.json是生产台账，不是运行schema，不得覆盖原catalog/modules/my_test-v2。
先完成5个pilot资产及头部装备的开口/片层支持，再扩充余下25项。
装配器确定每件最终尺寸、落位、层序和表现，导出同一版本化装配包供游戏读取；不能在游戏端另调一遍或重复套edits。
实际执行qa_matrix.json和presets.json；为真正运行的检查填写证据，其他保留NOT_RUN。
只交模板、PNG或未执行脚本都不算游戏交付；用户批准必须有用户实际反馈来源。
本包中的设计名称和ID是默认计划，参数、路径、哈希及接口支持必须从真实工程取得，不能用占位值冒充完成。
```

## 本包已做的检查

已通过11项模板/校验器自检：初始结构、未完成交付门槛拒绝、重复ID、无效预设引用、错误配对、漏计资产、无证据PASS、缺批准来源、头盔加片不增资产数、无理由不适用等。详见tools/TEMPLATE_SELF_CHECK.json。

**资产生产状态仍是30项planned，126条图像/装配/游戏测试仍是NOT_RUN。** 自检通过不改变这些状态。
