# 假设、决定与资料来源

更新：2026-09-18。此文件区分用户要求、设计提案和外部事实。

## 用户已确认

| 编号 | 内容 | 来源 |
| --- | --- | --- |
| U01 | 原创 2D 战棋 + 佣兵团经营，参考《Battle Brothers》的体验，目标未来在 Steam 上架 | 用户初始要求 |
| U02 | 战斗、故事、魔幻中世纪画风都是长期重点 | 用户初始要求 |
| U03 | 真人目前只有用户一人，所说的小团队是 AI 开发团队 | 用户补充 |
| U04 | 战斗与剧情兼顾，提高视觉与动画表现 | 用户补充 |
| U05 | 希望逐步增加技能、机制、成长复杂度、佣兵团类型与发展特性，可参考驯兽等模组思路 | 用户补充 |
| U06 | 先小而精地打磨机制，再扩充内容量 | 用户补充 |
| U07 | 每周可稳定投入 10–20 小时 | 用户补充 |
| U08 | 事件与角色成长加入肉鸽元素，借鉴 PTR 增强联动，增加元素反应与场景互动 | 本次用户要求 |
| U09 | 佣兵团在战役内持续成长，每次远征随机事件与奖励，失败承担伤亡和损失 | 本次选项明确回复 |
| U10 | 认可当前方向，接续另一台电脑未完成的最小可行性验证；先完成代表机制的可玩闭环，再扩内容和复杂度 | 2026-09-17 本任务 |
| U11 | 按复杂度选择子代理模型，不轻易使用最强模型；同步至 esesmalls 的 GitHub | 2026-09-17 本任务；2026-09-18 确认其他对话已同步 |

## 当前提案与验证时点

| 编号 | 提案 | 状态 | 验证时点 |
| --- | --- | --- | --- |
| D01 | Godot 4.7.2 stable + 类型标注 GDScript，Windows x86_64 | 本地既有工具和工程已核验；完成导出，锁定原型版本 | 跨机器试玩后再评估，不另建第二引擎工程 |
| D02 | 六边格、固定斜俯视、个体回合、6 行动点 | 原型假设 | 第 3–6 周战斗测试 |
| D03 | 每回合 4–6 个常用主动技能，复杂度主要来自组合 | 设计方向 | 原型与成长测试 |
| D04 | “誓约影响任务”与《渡桥的钟声》 | 原创叙事提案 | 第 9–12 周短故事测试 |
| D05 | 长期完整身体剪影仍为提案；本轮按最小接口采用原创程序绘制半身棋子 | 半身原型已实现；不代表长期画风定案 | 真人试玩可读性与后续正式样板评审 |
| D06 | 自由佣兵团 + 驯兽猎团作为小规模 1.0 两类队伍 | 范围建议 | 战犬机制实验通过后确认 |
| D07 | 1.0 单战役 6–10 小时，30–42 个月修订情景，取代 v0.2 的 24–36 个月 | 低置信度估算 | 第 6、12 周重估，此后每阶段更新 |
| D08 | 单机买断，Windows 优先，中文先行并准备英文 | 发行提案 | 品质试玩后评估范围 |
| D09 | AI 统筹 + 四类专项角色，最多 3 个子代理并发 | 项目配置已写入，当前工具列表可见四类角色，逐个启动验证待做 | 首次实际调用对应角色 |
| D10 | 36 个月现金预算算例 21.97 万元，取代旧算例；12 周算例仍 9,750 元 | 参数占位，非已批准预算 | 实际用量与报价产生后 |
| D11 | 基础岗位可规划，关键成长节点受约束抽选；首版不跨战役累积永久属性 | 设计提案，持续战役结构已确认 | 第 9–12 周与品质试玩 |
| D12 | 先盾枪破绽联动，后驯兽追猎与元素控场；统一状态、根行动与触发上限 | 设计提案 | 第 3–6 周起逐条验证 |
| D13 | 地表／区域／单位状态分层，原型 R01 油火、R02 水火转蒸汽与三类物件；1.0 至多六条反应 | 范围提案 | 第 5–6 周；成本超标时简化 R02 |
| D14 | 用新增联动与环境取代原型疲劳、士气、高低差扩展；六事件总额不增加 | 排期提案 | 第 6、12 周按实际负担重估 |
| D15 | 以 docs/05-prototype-contract.md 为本轮实施边界：两团四出战位、盾枪、两条元素反应、战犬、六事件、成长、存档与三次远征收束 | 代表机制闭环已集成；三次远征复用一张战场，不是三个完整剧情关卡 | 0.1 导出试玩，先收集可理解性与趣味反馈 |
| D16 | GitHub 复用用户创建的 esesmalls/fantasy-brothers，保留公开设置；源码和文档入库，工具二进制、导出包与个人进度不入库 | 首次提交与推送已完成；本轮核对本地远端一致 | 每次交付同步并核对提交；不自动发布 Release |

2026-09-18 接续决定：接纳另一对话已提交的存档键／数字规范化与 AI 射程内遮挡绕行修复，基于同一 main 继续补回归和交付，不回退已验证更改。数值与自动玩家胜率不作为最终平衡结论。

未决变量：用户对引擎与美术工具的熟悉程度、阶段预算上限、具体画风样板选择。没有证据时保留这些未知项，不默认用户会编程或能够承担某个支出。

## 官方资料

以下内容于 2026-09-17 核对。发布前重新检查平台规则；这些来源不为项目工期、成本或销售预测背书。

| 资料 | 本次用于确认 |
| --- | --- |
| [Steam Direct](https://partner.steamgames.com/steamdirect) | 每款产品 100 美元费用、收回条件、等待期与 Coming Soon 要求 |
| [Steam 审核流程](https://partner.steamgames.com/doc/store/review_process) | 商店与包审核时间、为修改预留时间 |
| [Steam Next Fest](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest) | 每款作品仅一次、未发售资格、Demo 与公开商店页要求 |
| [Steam Early Access](https://partner.steamgames.com/doc/store/earlyaccess) | 当前可玩内容的价值、对未来承诺与资金依赖的限制 |
| [Steam Playtest](https://partner.steamgames.com/doc/features/playtest) | 关联主游戏的测试应用、访问控制 |
| [Steam 内容调查](https://partner.steamgames.com/doc/gettingstarted/contentsurvey) | 玩家会消费的生成式 AI 内容、预生成与实时生成的区别 |
| [Godot 许可](https://godotengine.org/license/) | MIT 商业使用与许可声明 |
| [Godot Windows 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html) | 桌面交付路径 |
| [Godot 类型标注](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html) | 规则代码的类型检查能力 |
| [项目 AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md) | 项目指令发现与加载方式 |
| [Codex 子代理](https://learn.chatgpt.com/docs/agent-configuration/subagents) | 项目角色文件、必需字段、并发设置与继承行为 |

## 本次机制研究资料

本轮已研究以下官方／作者资料；属于文献调研，未运行参考游戏或审计模组完整源码。参考事实与本项目规则分开，具体数值与备选方案以 [系统扩展设计](04-systems-expansion.md) 为准。

| 资料 | 参考点与边界 |
| --- | --- |
| [PTR 作者页](https://www.nexusmods.com/battlebrothers/mods/438)、[作者仓库](https://github.com/LordMidas/LegendsPerkTreeRework)、[版本记录](https://www.nexusmods.com/battlebrothers/mods/438?tab=docs) | 加权分配、联动条件与历史触发故障；旧版、发行版与 Reforged 不混为一谈 |
| [Battle Brothers 开发日志](https://battlebrothersgame.com/dev-blog-80-progress-update-new-perk-system/) | 专长服务不同策略、避免破坏基础规则的设计标准 |
| [Wildermyth 官方](https://www.wildermyth.com/)、[编写指南](https://wildermyth.com/wiki/Writer%27s_Guide) | 经历与后果、条件事件；Wiki 含早期开发说明，不等同当前完整规则 |
| [Hades FAQ](https://www.supergiantgames.com/blog/hades-faq/) | 重复游玩中的构筑变化与叙事连续，不照搬永久属性和重开结构 |
| [DOS2 官方帮助手册](https://dlassets-ssl.xboxlive.com/public/content/6778dff3-8d6c-4615-a8a3-1f1770057d09/GameManual/9e540603-b9bb-44a0-83cd-bb98f1d40b32/nb-NO/index.html)、[Larian 引擎文档](https://docs.larian.game/AI_grid_panel) | 地表反应、Ground／Cloud 分层与空间约束；工具文档不是完整发行规则 |
| [Into the Breach 官方](https://subsetgames.com/itb.html) | 攻击预告、保护场景目标与己方火力约束 |

完整研究：[PTR](research/ptr-findings.md)、[肉鸽事件与成长](research/roguelite-findings.md)、[元素与场景](research/elements-findings.md)。未导入任何模组代码、文本或美术，也未将参考关系视为使用授权。

## 本次修订依据

2026-09-17：按 U08、U09 将原方案修订至 v0.3。核心选择是持续战役容纳随机远征；事件、成长、联动、环境与故事后果形成同一循环。保持原型内容数量，以推迟疲劳、士气、高低差换取核心辨识点。长期窗口因组合测试、AI、预览与动画工作增加而放宽，预算仅同步提供可替换参数的情景；并未批准支出、锁定规则数值或发售日期。

## 决定记录模板

```text
编号 / 日期：
问题：
决定：
依据（试玩、测量或明确偏好）：
影响的机制、资产与排期：
仍不确定的内容：
何时重新评估：
```
