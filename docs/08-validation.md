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
