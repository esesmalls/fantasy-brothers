# 0.1.5.1 悬浮信息交付验证

2026-09-19，基线5f80529，Godot4.7.2，Windows/NVIDIA RTX4080 Laptop/OpenGL。本次只改表现和交互，战斗规则仍prototype-0.1.5、存档格式不变，没有重跑无关经济/规则全套。

- 只读详情投影：32/0，builds/qa/0151-inspection.log。生命、护甲、行动点条取真实状态，保留完整详细文本与旧版兼容。
- 源码UI：301/0，builds/qa/ui-0151-source.log。
- 最终实际EXE：340/0（301项界面场景+39张渲染截图），builds/qa/export-0151/smoke-report.json，exported:true。图形日志export-0151.log，无脚本错误。
- 新检查：默认3色条且完整正文隐藏；4状态+5专长+火区的卡片宽≤265、高≤310；Alt切换完整说明、滚轮访问溢出，宽≤381、高≤445；小窗口不越界或侵入底栏；弹窗/无卡不切换；两次切换不改变campaign/RNG/AP；卡片覆盖一个经Battle.preview验证合法的移动目标时真实点击不执行动作。
- 防穿透用例只临时固定UI位置并暂停控制器的跟随布局，直到Input队列派发完；规则状态未改。否则浮动卡会在测试点击到达前移开，无法验证遮挡命中。测试恢复正常布局后继续原始战斗循环。
- 第一轮滚轮合成输入因使用了不在悬浮单位上的坐标而隐藏卡片；改成实际Input motion到角色，再复用其屏幕投影点，确认滚动有效。此前失败记录不作为真人滚轮故障。
- 保留原地图、人物培养、装备、真实动作、动画速度/跳过、存读与三远征流程。此轮不改变伤亡和升级数值。

主AI负责实现/实际导出，两名Sol分别整理四步计划、只读检查输入风险；独立QA运行详情32/0并发现点击穿透与无卡Alt预展开，最终已修复并纳入上述回归。未覆盖其他电脑、不同系统缩放/多显示器组合及真人图标辨识。

SHA256：EXE `865C198191CCAB251D24F29E1A22A2D8069D31D7172B2622BB0CE8ED9DA52DDE`；ZIP `C3B1E53F7DDC7864C13F6BDA347BF961AF826E0D70FD4C78A99164F55EC005DB`。构建日志builds/qa/build-0151.log。以下为历史记录。

---
# 0.1.5 交付验证记录

2026-09-19，基线02a9ef2，Godot 4.7.2.stable.official.ed1daf0bf，Windows/NVIDIA RTX 4080 Laptop/OpenGL Compatibility。新战斗prototype-0.1.5，旧0.1.4/0.1.1战场保留完整快照。

| 检查 | 检查/失败 | 证据 |
| --- | --- | --- |
| 战斗 / 战役 / 世界 | 129/0、72/0、126/0 | builds/qa/verify-015.log |
| 存档 | 53/0 | builds/qa/015-save-final.log |
| 完整流程 | 1730/0 | builds/qa/015-flow-final.log，20种子×2团×3远征，110胜/10其他 |
| 装备 / 详情 / 人物分层 | 66/0、30/0、7/0 | builds/qa/verify-015.log |
| 人物属性与培养 | 67/0 | builds/qa/015-characters-final.log |
| 独立旧档与成长回归 | 491/0 | QA代理实际执行test_progression_regression.gd；verify-015.log同步覆盖491/0 |
| 源码界面 | 289/0 | builds/qa/verify-015.log，user://qa/screens/smoke-report.json |
| 最终Windows导出 | 326/0 | builds/qa/export-015/smoke-report.json，exported:true；289项场景+37张实际渲染截图 |

全套verify通过后，因恢复战犬同猎候选与修正最老0.1迁移，局部重跑人物、存档、战役、独立回归及完整流程；最后重新导出并运行实际EXE的全部UI场景。未在无新风险时反复跑所有规则。源码/导出覆盖重复，不能相加为独立质量指标；自动胜率不代表玩家胜率。

新增规则验证：有效属性直接影响预览和命中结算；1–8级累计经验与点数；死亡/重复领奖；基础训练完整扣费、非营地/无粮无钱无额度时无状态变化；装备加减值不改变永久培养上限；跨出身学习驯兽、唯一犬绑定和真实动作；战犬不获不可消费的人类点数。移动、等待、仅发犬指令即逃跑不发经验。

独立夹具来自旧提交保存器生成的合成QA战役，覆盖0.1.4的camp/event/battle/growth/returning与真实0.1.1 battle。验证旧vigor/precision、51/66伤血、+3/-5武器、11/24甲损、历史、RNG、claim、未领候选及初始阵容完整保留；二次迁移和保存不漂移。另有synthetic prototype-0.1兼容断点：升级到0.1.4快照而不要求不存在的0.1.5元数据。用户个人存档未用于这些夹具。

UI真实第一次胜利后获得经验，再实际点击体魄/防御加点，检查数值、点数、伤血和手动存读；训练与驯兽通过真实按钮扣资源、绑定犬并进入战斗。新增人物/装备同人往返、履历只读、标题小窗口布局。保留原三远征、地图、装备、元素、动画速度/跳过和HUD测试。QA存档位于user://qa；不覆盖campaign.json/manual.json。

本轮修复：等级镜像在升级后不同步；负XP未拒绝；临时装备修正参与培养上限；非营地加点缺少规则拦截；空犬指令可获得撤退经验；犬产生不可使用点数；人物标题竖排；最老快照错误标为新规则；战犬同猎候选被误移除。最终图形日志无脚本错误。

导出命令：tools/build.ps1 -SkipTests。实际EXE参数：`-- --smoke-test --smoke-dir="S:/fantasy brothers/builds/qa/export-015"`。构建日志builds/qa/build-015.log，图形日志builds/qa/export-015.log。

SHA256：
- EXE：C39FE1CFAAF98FBA73762D72A7EABB806E2C05CA55A3B47DDD2EEC3ED494A633
- ZIP：EF6F2C78CE4963AF1FB6169E2B00ADAA0AC7F61D3E9F5D16738963805FB035C7

未覆盖另两台电脑/显卡、每份真实用户旧档、长线经济与真人手感。没有实现招聘工资、天赋抽选、伤残性格、繁衍或自由走图。下方保留历史记录。

---
# 0.1.4 交付验证记录

日期：2026-09-19，基线63ed359，Godot 4.7.2.stable.official.ed1daf0bf，Windows/NVIDIA RTX 4080 Laptop/OpenGL Compatibility。新战斗prototype-0.1.4；旧0.1.1进行中战斗保留快照和版本，以kind回退既有动作。

| 检查 | 检查/失败 | 证据 |
| --- | --- | --- |
| 战斗 | 129/0 | builds/qa/014-test_battle.log |
| 战役 | 72/0 | builds/qa/014-test_campaign.log |
| 存档 | 53/0 | builds/qa/014-test_save.log |
| 世界 | 126/0 | builds/qa/014-test_world.log |
| 完整流程 | 1725/0 | builds/qa/014-test_flow.log，20种子×2团×3远征，105胜/15其他 |
| 装备 | 66/0 | builds/qa/014-test_equipment.log |
| 只读详情 | 30/0 | builds/qa/014-inspection.log |
| 共享人物分层 | 7/0 | builds/qa/014-character-layers.log |
| 源码界面 | 251/0 | builds/qa/014-ui-source/smoke-report.json，独立QA |
| 最终Windows导出界面 | 283/0 | builds/qa/export-014.log；251项场景+32张真实渲染截图 |

工具 tools/verify.ps1 已接入equipment/character_layers，build.ps1导出0.1.4。规则与UI源码测试重定向APPDATA至工作区隔离目录；导出运行实际EXE，测试保存user://qa而非玩家档。环境证书/日志权限提示不等同产品故障；早期源码UI存读失败确认是默认AppData沙箱拒写，改隔离目录后最终251/0。最终图形导出正常退出、无脚本错误。旧按岗位限制方案235/0不是本版最终结论。

新增验证：物品实例唯一、不可双持/重复售卖、已装备和配发品不可出售、购买资金与售价、换装差量与成长保留、护甲损耗回写、死亡丢装和补员、修理预算与战犬。跨人物武器改变动作和射程，kind与猎人指令保留；装备和显示快照进入新战斗。旧0.1.1没有style的战斗仍有原盾击/长枪行为，既有快照、RNG、成长候选保存。最后补旧0.1.3 camp/returning迁移用例，位置/资源/RNG/claim保留、返营不重复领奖，迁移后可购买换装；仅新增测试，生产代码未变。

UI通过真实按钮完成采购/换装/出售、跨背景弓手持枪、猎人持剑盾，小窗口九个招式完整显示；肖像与战场显示相同装备ID，悬停显示武器和护甲名。装备专用战损回写用受控结算夹具，伤势图用仅显示副本夹具，不冒充一次真实敌人命中；既有长流程另有真实自动战斗。所有夹具都还原或使用独立战役。

未覆盖三台电脑的每份真实个人旧档、其他显卡、真人手感与经济平衡。完整装备套层/独立头盔披风副手未实现；当前剑盾是一个组合武器。源码和导出有重复覆盖，计数不累加为独立质量指标，自动战斗结果不代表玩家胜率。

最终产物SHA256：
- EXE：ACD809A5D87C9A8047104556ECC7BE49AB291C66687DFBEAC10D75CA6AF5D085
- ZIP：A525CF447562FCF328509F759B67CBAEE5AD2E6FFD4191C05E1D6C780F19EE52

以下保留上一版历史记录。

---
# 0.1.3 交付验证记录

日期：2026-09-19，基线10161e4，Godot 4.7.2.stable.official.ed1daf0bf。第三台 Windows / NVIDIA RTX 4080 Laptop / OpenGL Compatibility。旧战斗规则不变，增加 world.schema=1 与旧存档迁移。

| 检查 | 检查/失败 | 证据 |
| --- | --- | --- |
| 战斗 | 129/0 | builds/qa/013-test_battle.log |
| 战役 | 72/0 | builds/qa/013-campaign.log |
| 存档 | 53/0 | builds/qa/013-save.log |
| 世界 | 126/0 | builds/qa/013-world.log |
| 完整流程 | 1725/0 | builds/qa/013-flow.log，20种子×2团×3远征，105胜/15其他 |
| 只读详情 | 30/0 | builds/qa/013-test_inspection.log |
| 独立源码界面 | 211/0 | QA以隔离APPDATA运行；临时目录已清除 |
| 最终Windows导出界面 | 237/0 | builds/qa/export-013.log，211项场景检查+26张截图 |

工具入口 tools/verify.ps1 已接入 test_world.gd。导出运行的是 builds/windows/FantasyBrothers.exe，测试使用独立 user://qa/ 路径，不覆盖个人自动/手动档。构建日志 builds/qa/build-013.log。源码和导出检查有重复，不能累加成独立质量指标；自动战斗胜率不代表人类胜率。

新增覆盖：合法阶段迁移；两路线一次扣费；地图浏览只读；保存旅行位置、事件实例、选择和随机状态；第三次桥头绕行存读后到正确地点；旧 event/ready/battle/growth/camp 迁移；胜败撤退返营与零资源恢复；事件和契约防重复；非法调用完整状态不变。图形输入覆盖路线/行军/地图节点/事件浏览/返营，以及原战斗HUD、存档、范围和反馈。

发现并修复：世界存档跨字段校验、空实例列表和Variant类型；ready伪造战果只能原子拒绝，结算必须来自登记的当前战斗；真实点击测试切回地图后过早读取未布局按钮坐标，已等待两帧再点击。首轮导出因此连续失败并异常退出，最终重新导出全程237/0、正常退出，未用headless结果代替真实导出。

规则测试出现Windows根证书读取提示；最终图形导出日志无脚本错误。未覆盖另两台实际设备、每份个人旧档、真人趣味和平衡、商业美术质量。败北返营有规则/完整流程覆盖，未另做败北界面专项截图。

最终产物 SHA256：
- EXE：173F5479028A17A97C26761BEFEB87C33E54B5B7E1B6E2E53EE247F5445FE7F7
- ZIP：BA9B8055ABAECEB30064AA5690D68B5564AEA5A5AB1C4E258984BE2EAD4C0068

以下保留上一版历史记录，不代表本版计数。

---
# 0.1.2 交付验证记录

日期：2026-09-19。基线 Git edb6370，Godot 4.7.2.stable.official.ed1daf0bf。第三台 Windows 电脑，沿用同一引擎和导出模板。战斗规则与存档结构未改版。

## 可重跑检查

`tools/verify.ps1` 已接入 `test_inspection.gd`；测试写入独立 `user://qa/`，不覆盖玩家自动档和手动档。本轮由主 AI 分别执行战斗/战役/存档/流程四套及详情测试，独立 QA 执行界面测试，最终由主 AI 运行真实导出包。

| 检查 | 结果（检查/失败） | 覆盖 |
| --- | --- | --- |
| test_battle.gd | 129/0 | 既有移动、友军穿行、致死移动、攻击/范围、控制区与元素规则 |
| test_campaign.gd | 68/0 | 两路线、成本、生成保存、防重复、结算和失败恢复 |
| test_save.gd | 53/0 | 完整保存/备份/旧状态迁移、路线和 RNG 一致 |
| test_flow.gd | 1105/0 | 20种子×2团×3远征，共120场；105胜/15其他结局，均结算继续 |
| test_inspection.gd | 30/0 | 敌我、战犬、死亡、物件、地表、状态/来源/期限、专长、顺序、越界回退；读取不改规则/RNG |
| headless ui_smoke.gd | 143/0 | 新 HUD 布局/交互与既有三远征流程；独立 Sol QA 执行 |
| Windows 导出 ui_smoke.gd | 164/0 | 143项场景检查 + 21张真实渲染截图；图形模式真实按钮点击 |

自动流程不是人类胜率，不证明最终平衡。源码与导出有重复覆盖，不能累加为独立质量指标。源码 headless 的按钮测试使用按钮信号，图形模式改用真实 Input 事件；两种模式的人物悬停均走 Input 分发。小窗口测试需用 viewport screen transform 转换原生输入坐标，避免把缩放测试错误误报为游戏命中错误。

## 新增界面验收

- 全视口棋盘；底栏、顶栏和行动队列高度受控，所有有效格锚点仍对应原坐标。
- 当前单位开始的存活队列、敌我/战犬详情、物件耐久、油地、敌人回合悬停、同格刷新及离开清理。
- HUD 战报按钮真实展开/收起，点击不穿透战场；详情/队列/日志读取均不改状态与 RNG。
- 1180×740请求窗口（实际截图1180×737）下，猎人7个招式和3个共享工具完整可用；上身真实鼠标悬停仍定位猎人本人。
- 五专长、多状态与火区的长卡 fixture 显示全部详情且不侵入底栏，验证后恢复完整原状态。fixture 不代表盾卫能自然获得全部专长或新增了牵制规则。
- 读档离场释放旧 HUD/tooltip，再入场无残留；延迟布局不得访问已移除节点。
- 继续覆盖路线保存、弓手范围/遮挡、元素波及、实际动作、速度只改表现、伤亡/成长与三次远征收束。

## 发现并修正

1. 默认自动换行在缺少宽度时把顶栏/队列/信息卡撑成高条：短标签禁用换行，长文本显式给宽度。
2. 人物宽矩形把相邻空格误判为长枪手：改为头部/躯干/底座轮廓，保留前后绘制优先级。
3. 旧 HUD 移除后延迟 layout 仍访问 viewport：加在树检查，离场无错误。
4. 长信息卡文本重排后保留旧高度，侵入底栏：卡按内容加宽，并在布局完成后重设最小尺寸；最终长卡实拍与边界检查通过。
5. 猎人指令图标 ID 与图形表不一致：补齐牵制、撤回别名；保留调用方设置的图标尺寸。

## 导出与证据

`tools/build.ps1 -SkipTests` 导出 builds/windows/FantasyBrothers.exe，打包 builds/FantasyBrothers-0.1.2-windows.zip；附 PLAYTEST.md 与 Godot 完整许可。直接运行导出 exe，使用 `-- --smoke-test --smoke-dir="S:/fantasy brothers/builds/qa/export-012"`，报告 `exported: true`。

设备 NVIDIA GeForce RTX 4080 Laptop GPU / OpenGL 3.3。报告 `builds/qa/export-012/smoke-report.json`；图形日志 `builds/qa/export-012.log`；构建日志 `builds/qa/build-012.log`；规则日志 `builds/qa/012-test_*.log`；详情日志 `builds/qa/012-inspection.log`。沙箱解析/详情运行时出现系统证书读取警告，测试仍通过；最终导出运行日志没有该警告或游戏脚本错误。

SHA-256：
- exe：`F1E77EAFE02E953050A891991EC8FCD1593FE3920D64008AD8D9A7467B4C0882`
- zip：`48FAFCF08153CCAEE3BAEFCC806F1D56CF8B3403C4FE35D00F55617E56B4B57D`

## 未覆盖

未验证另两台电脑/显卡、干净系统、真实断电/磁盘耗尽、外部玩家或长期经济平衡。本轮未新增旧档迁移；既有构造旧档回归通过，但未取得其他电脑的真实个人旧档。新 UI 的密集角色、长期游玩与手感仍需用户试玩。大地图只有设计，不能把本轮验证记为地图功能通过。
