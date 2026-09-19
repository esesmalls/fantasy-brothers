# 人物成长、个性与伤残：开发日志研究

研究日期：2026-09-19。对应用户 U22、U23。主 AI 阅读官方日志，Sol 分别完成现有工程只读审查和原创内容评议；没有运行参考游戏，也没有移植其代码或素材。

## 资料范围

用户指定的 [2014 年 1 月归档](https://battlebrothersgame.com/2014/01/) 确实包含两篇：1 月 18 日的游戏介绍和 1 月 29 日的角色属性介绍。另选读七篇与背景、士气、伤残、专长、训练及随军人员有关的日志。以下是**历史开发设计**，不作为当前发行版或 PTR 的规则说明；不把论坛玩家留言当成作者结论。

| 官方资料 | 文中设计事实的简述 | 对本项目的启发（我们的判断） |
| --- | --- | --- |
| [What is Battle Brothers?](https://battlebrothersgame.com/what-is-battle-brothers/) | 开篇把战术、佣兵团经营、装备与成长、人物死亡联系起来；装备外观是人物识别的一部分 | 人物成长应贯穿旅行、工作和战斗，不能独立成战后抽奖页 |
| [Game Mechanics 101: Character Stats](https://battlebrothersgame.com/character-stats/) | 属性参与命中、生存、行动及士气；角色没有严格职业限制；升级取得专长 | 属性必须改变玩家决策。保留自由组合，避免只增加面板数字 |
| [#18 Character Traits and Backgrounds](https://battlebrothersgame.com/dev-blog-18-character-traits-and-backgrounds/) | 背景表现从军前经历，影响起始条件；特质可以有利、不利或兼具两面，强调人物差异 | 借鉴背景与特质分离；本项目进一步要求每个人都存在可靠培养路径 |
| [#20 Bravery & Morale](https://battlebrothersgame.com/dev-blog-20-bravery-morale/) | 可培养的勇气与战斗中变化的士气分开；士气反馈要让行动后果可理解 | 区分意志、当场士气和长期性格，不能把三个东西合成“心理值” |
| [#49 Character Backgrounds…](https://battlebrothersgame.com/dev-blog-49-progress-update-character-backgrounds-visual-makeover-continued/) | 作者指出旧背景加值使贵族战士全面强于农夫，于是改用背景各自的属性生成区间，保证专业者的基本能力，也容许普通人出现优秀个体 | 单靠招募随机性仍不足以满足“每个人都能养成”；需要后天训练保证基础能力可达 |
| [#79 Injury Mechanics](https://battlebrothersgame.com/dev-blog-79-progress-update-injury-mechanics/) | 区分暂时与永久伤势；伤势影响战斗和轮换；部分倒地者带伤幸存，永久死亡仍存在 | 伤残上线必须同时提供救助、休养与替补的决策，不能只叠惩罚 |
| [#80 New Perk System](https://battlebrothersgame.com/dev-blog-80-progress-update-new-perk-system/) | 移除过强的类别限制；评估专长能否支持策略、要求玩家运用且不使基本机制失效 | 强技能应改变站位、时机或协作；避免无限行动、全队无条件免疫等覆盖其他选择的解法 |
| [#96 Wrapping Things Up](https://battlebrothersgame.com/dev-blog-96-wrapping-things/) | 训练帮助补入新兵；纪念册留存阵亡记录；高等级仍可有受限成长 | 新兵追赶、老兵继续发展、逝者被记住，分别服务不同体验，不宜共用无限属性增长 |
| [#128 The Retinue, Part II](https://battlebrothersgame.com/dev-blog-128-the-retinue-part-ii/) | 随军医生为倒地生还与治疗提供帮助；随军职位本身存在名额取舍 | 后续医疗、导师、伤退岗位可成为经营选择，但不要先扩成另一套复杂管理游戏 |

## 研究结论

1. **可培养性需要制度保证。** 所有常规人类角色都应能经可预测训练达到一种以上实战岗位的基本要求。背景可影响准备程度、事件知识和初期投资，不能成为永久学习禁令。优秀开局仍能节省时间与风险。
2. **随机应制造机遇和经历。** 保留已保存的事件/成长候选，但保证玩家选择的基础路线不会因缺少某张卡而中断。天赋影响学习顺畅程度，不决定低出身的终身上限。
3. **损失与适应分开。** 伤残本身是真实代价；玩家通过装备、站位、训练和队伍支持继续使用该角色。无需给每种残疾附送一个超能力，也不能使受伤成为刷强度的最优路线。
4. **人的经历要回到战场。** 经历不能只给履历加句文字；但也不必每件小事都发属性。少量重大经历带来可选训练、关系变化或特定战术机会，普通经历负责建立记忆。
5. **先做好承载关系，再扩数量。** 现有装备自由组合已提供基础。下一步应先把基础属性、后天增长、装备、伤势和短期状态分开，随后验证普通人成材，再扩伤残与个性。

以上为原创方案推导，不是上述作者对 Fantasy Brothers 的建议。具体方案、工程现状、试验参数与实施边界见 [人物成长与命运设计](../13-character-progression.md)。
