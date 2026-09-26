# 基础素材与动作交接

此批是 AI 基础对位，最终位置、比例、层序、接触节奏和声音力度由用户调整。原来的 `current.asset.json` 和 `my_test` 工程保留。

新增身体采用用户确认的低细节胸部方案：胸前平滑处理，保留共同肩颈轮廓及肤色、年龄差异。首次生成阻拦及后续新设计的记录见 [身体制作记录](../art/production/bodies-20260923/STATUS.md)，最终可用数量以基础库清单及 STATUS 为准。

## 打开与调整

- `Foundation.cmd` 现打开独立的 `art/workbench/projects/foundation-review.asset.json`；旧 `foundation-ready.asset.json` 保留。新副本修正三款单刃斧及两款盾面的左右方向，其余位置、比例和动作参数保留。
- 新件稳定 ID 为 `body_01..04`、`face_01..04` 等。15 类各四件；`padded_01_damaged..04_damaged` 和 `outer_01_damaged..04_damaged` 是额外配套状态，不计入四种。
- 工程保留原共同装配参照。勾选要评审的新件、隐藏同位置旧件；身体与脸按同编号配对。角色外观由存档保存，调整素材不会重新抽脸。
- 保存精调工程后，继续沿用资产编辑器的差异预览与应用流程。AI 再接手时读取这份已保存工程，不从生产草案覆盖用户修改。
- `foundation.asset.json` 是生产记录入口；`foundation-ready.asset.json` 是加上动作与终局覆盖后的交接工程；`foundation-publish-diff.json` 保留初次接入差异。

## 实际装备映射

装配评审时，顶部“界面”可自动缩放或手动选100%–250%；资产库的评审筛选可只看未处理、存疑或已处理。选中资产，在属性顶部勾选“已处理”或“存疑”，两者可同时存在并随工程保存。仅查看不会自动变成已处理。

“装入待处理／存疑”尽量将当前参考组合换为同功能槽未处理/存疑素材，存疑优先；“随机装配”随机换同类。没有候选或已锁定的部分保持不动，两者均可一次撤销。评审完当前组合，可用“选择整个装配”后统一标记；需要进一步检查的资产保留存疑标签。批量换装不改变游戏人物的外观ID。

单件“水平翻转”只镜像图像，不移动校准位置及锚点；游戏中的敌我朝向及向左/向右攻击由运行时处理，无须为敌人重复制作一套图片。

| 游戏装备 | 素材 | 动作 ID |
| --- | --- | --- |
| 营团剑盾 | sword_01 + 角色的盾 | attack_weapon_guard_sword |
| 重刃盾 | sword_02 + 角色的盾 | attack_weapon_guard_cleaver |
| 营团短刃 | sword_03 | attack_weapon_skirmisher_blade |
| 缺口手斧 | axe_01 | attack_weapon_skirmisher_axe |
| 营团长枪 | spear_01 | attack_weapon_spear_long |
| 钩刃长枪 | spear_02 | attack_weapon_spear_hooked |
| 营团短弓 | bow_01 | attack_weapon_archer_bow |
| 硬弦长弓 | bow_02 | attack_weapon_archer_longbow |
| 猎团弓 | bow_03 | attack_weapon_hunter_bow |
| 林地反曲弓 | bow_04 | attack_weapon_hunter_recurve |

盾击使用两个 `shield_bash_weapon_guard_*` 模板，戒备用 `defend_shield`。动作轨道指向实际新武器；游戏在选装时映射到共用装配位置，不把斧头当旧剑图片。出手与接触标记同步音效，改变时间轴不会改变伤害、行动点或抽样。

| 游戏衣甲 | 衬甲 | 外层 |
| --- | --- | --- |
| 轻型衬甲 | padded_01 | 无 |
| 中型皮甲 | padded_02 | outer_03 |
| 中型钉甲 | padded_03 | outer_02 |
| 重型链甲 | padded_04 | outer_01 |

其他剑、斧、矛、盾和钢鳞甲样式保留在库中，未强行各增加一件数值物品。甲损按同编号选对应损坏件；血迹依据当前负伤，绷带依据未结束的临时伤势，旧伤痕依据永久伤损。

## 终局与声音

`state_down` 与 `state_dead` 是两张独立地面覆盖。人物倒地仍保留同一张脸、衣甲和武器，不改成另一人物。终局整体旋转、位置、缩放保存在工程 `game.terminal.incapacitated` / `game.terminal.dead`，当前是可调整的基础姿态；战中倒地仍可能幸存，只有已确定死亡才用死亡状态。

录音、作者、许可与加工关系见 [音源记录](../art/production/audio-20260923/README.md)。武器操作采用真实录音；接触声采用许可明确的材质拟音，盾木及箭矢飞行尤其需要实际试听判断。默认倍速不升调，跳过清理过程声并保留结果提示。

建议优先评审：头颈与衣领配合、不同外甲的真实开口、长枪/长弓握持与轮廓、重刃接触停顿和回收、盾格挡反冲、倒地身份是否可辨。无需在开始玩法试玩前精调所有可能组合。
