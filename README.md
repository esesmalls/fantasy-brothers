# Fantasy Brothers · 灰烬誓约原型

一款以战术战斗、佣兵命运和魔幻中世纪美术为重点的原创 2D 单机游戏，目标平台为 Steam。

当前阶段：最小可玩验证 v0.1.5.1，战场悬浮默认色条与图标、Alt切详细；人物帐接通四项属性、个人升级、营地训练和跨出身学习驯兽；营地军需帐接通装备、库存与交易，人类自由组合武器，营地与战场共用可见装备和伤势的分层人物；六处地点接通地图接约、逐站旅行、途中事件、契约战斗、清点成长与返营生活；保留上一版战场优先的底部HUD与悬浮信息。当前优先搭完整框架与功能，再逐步丰富内容；以下规划仍不代表最终平衡、预算或发售承诺。

更新日期：2026-09-20。

双击根目录 `Play.cmd`，或解压 `builds/FantasyBrothers-0.1.5.1-windows.zip` 后运行 `FantasyBrothers.exe`。建议自由佣兵团、种子 `1709`、渡口旧道。完整玩法与边界见 [试玩说明](docs/PLAYTEST.md)，接续顺序见 [框架计划](docs/10-framework-roadmap.md)；当前地图范围见 [大地图闭环](docs/11-world-map-framework.md)。

源码仓库：[esesmalls/fantasy-brothers](https://github.com/esesmalls/fantasy-brothers)。源码不包含本地构建包；另一台 Windows 电脑按下方步骤重新准备工具和构建。

## 阅读顺序

1. [总体设计与长期规划](docs/00-product-and-roadmap.md)：游戏定位、玩法、剧情、美术、范围、里程碑、预算与发行。
2. [AI 小团队与协作方式](docs/01-team-and-delivery.md)：你与 AI 的分工、角色配置、工作节奏和交付标准。
3. [首个 12 周执行计划](docs/02-first-12-weeks.md)：每两周交付什么、如何试玩、何时继续或缩减。
4. [假设、决策与官方资料](docs/03-decisions-and-sources.md)：哪些已由用户提出，哪些仍是建议，以及 Steam、Godot 资料来源。
5. [肉鸽、技能与场景扩展](docs/04-systems-expansion.md)：持续战役、随机成长、技能联动、元素反应、结算与验证。
6. 研究依据：[PTR](docs/research/ptr-findings.md)、[肉鸽叙事](docs/research/roguelite-findings.md)、[元素与场景](docs/research/elements-findings.md)。
7. 最新人物方案：[属性、培养与命运](docs/13-character-progression.md)、[开发日志研究](docs/research/character-development-findings.md)、[家庭与代际传承](docs/14-family-and-legacy.md)。已实现部分见[0.1.5人物属性](docs/15-character-attributes.md)；伤残性格仍为后续方案，繁衍先作长期预留。

下一批四步范围与整批测试见 [招聘、契约、部署与人物后果](docs/16-next-four-steps.md)，尚未实现。

用户已确认 [美术生产方式](docs/17-art-pipeline-selection.md)、[详细美术计划](docs/18-art-production-plan.md)与 **[H主导标准风格](docs/19-art-style-standard.md)**：保留H人物大小、完整双手和腰底贴合，少量融合E/G写实与油画；倒地/死亡不带底座。[最新三状态修订对照页](art/validation/2026-09-20-h-standard/index.html)可离线打开，提供武装、倒地、死亡新图及旧稿对照；三张均有真实透明alpha，边缘、装备精确对应、像素装配与动画仍待校准。[第二轮E–H](art/validation/2026-09-20-refined-directions/index.html)及[第一轮A–D](art/validation/2026-09-19-four-directions/index.html)保留供回看；[艺术设定集](references/battle-brothers/README.md)继续作为第三方参考。正式可玩版仍为0.1.5.1；本轮另有独立动作评审包。

最新为[有手／无手同步比较页](art/validation/2026-09-20-hand-comparison/index.html)，可离线打开并播放普攻、盾击与声音示意，或双击 `Review-Hands.cmd` 启动独立Windows评审。A自然握持与少量局部换姿势，B无手抽象；人物、链甲、剑盾、底座、时长与反馈共用。腰底、迎敌盾位与袖口已重做，原“完整双手”进入用户授权的比较范围。当前只评审右向链甲剑盾，不自动替换正常战斗资产。见[说明与验证边界](art/validation/2026-09-20-hand-comparison/README.md)。

旧三套H动作v2仍可双击 `Review-Motion.cmd` 回看，用户复评指出腰底、盾位和锁肘动作问题，三套未通过用户视觉验收。见[复评意见](docs/21-motion-design-review.md)、[本批说明](art/validation/2026-09-20-motion-templates/README.md)与[装配生产规范](docs/20-motion-template-production.md)。

## 当前建议

- 产品方向：有角色故事的佣兵团战术游戏；持续战役中随机远征，用人物经历、技能联动和场景变化连接战斗与剧情后果。
- 团队基线：你作为唯一真人制作人，加一个 AI 统筹与四类 AI 专项角色，按需轮换。
- 时间基线：按已确认的每周 10–20 小时人工投入规划，暂按 30–42 个月情景完成小规模 1.0；第 6、12 周用实际产能重估。
- 第一个目标：12 周内做出粗糙完整闭环，验证一条物理联动、两条地表反应与一次有保底的成长抽选。
- 第一次扩大投入：约第 6–9 个月，一段 45–60 分钟的高品质试玩通过外部验证之后。
- 原型技术栈：已锁定 Godot 4.7.2 stable、带类型标注的 GDScript，规则与画面分开。

用户已确认：佣兵团在战役内持续成长，远征随机事件与奖励，失败承担伤亡和损失。长期扩展包含更丰富的技能、人物成长、佣兵团发展特性与驯兽；首版不以跨战役永久属性堆叠推动重玩。优先完成少量机制之间的有效组合，再增加内容量。

这些建议的详细前提、替代路径与退出条件见各文档。游戏名、美术样式与具体数值均可在原型阶段调整。

## 运行与验证

- Windows 试玩：构建目录中的 `FantasyBrothers.exe`；根目录 `Play.cmd` 可直接启动已导出的版本。
- 重新准备 Godot：`tools/setup.ps1`；运行回归：`tools/verify.ps1`；导出打包：`tools/build.ps1`。
- 完整试玩步骤、已知边界和反馈问题见 [试玩说明](docs/PLAYTEST.md)。
- 工程主场景是 `game/main.tscn`，规则代码和棋盘表现分别位于 `game/core/` 与 `game/presentation/`。

在 Windows PowerShell 中，从项目根目录依次运行：

```powershell
.\tools\setup.ps1
.\tools\verify.ps1
.\tools\build.ps1 -SkipTests
```

准备工具需要网络，以及 Python 3（用于取得 Windows 导出模板）。Godot 固定版本从官方发布下载，编辑器归档做 SHA-512 校验；已有工具会复用。源码包无需安装额外插件。原型多数素材仍为程序绘图，H样板使用生成的模块PNG；系统中文字体运行时调用；引擎及第三方许可随导出包提供。

## 下一次项目接力

先阅读 [项目约定](AGENTS.md)、[当前状态](docs/STATUS.md)和相关设计文档，明确当前里程碑，再领取一个有完成标准的任务。长期进度依靠版本、任务卡和测试证据记录；不依靠聊天记忆。

项目内提供 `.codex/agents/` 专项角色定义与 `.codex/config.toml` 并发设置，用于按需分工。此前实现阶段使用战斗、内容、视觉与QA角色；本次0.1.5由主AI负责人物UI与集成、两个Sol子代理负责核心规则和独立QA。
