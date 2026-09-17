# 最小可玩接口 v0.1

2026-09-17：用户已授权进入最小验证。Godot 4 单一工程；原创程序绘制半身棋子与底座。每类特点先做代表样本，不把长期全部设想塞入本轮。

文件所有权：战斗角色 game/core/battle_rules.gd 与 game/tests/test_battle.gd；内容角色 game/core/campaign_rules.gd 与 game/tests/test_campaign.gd；视觉角色 game/presentation/battle_board.gd 与 docs/06-art-prototype.md；主 AI 负责项目、UI、存档、导出及其他文档。使用显式 preload，不依赖 class_name 缓存；不可覆盖他人文件。

## 战斗
battle_rules.gd extends RefCounted，方法全部 static。state 可 JSON 序列化；q/r 为整数，不存 Vector2。
- create_battle(roster:Array, seed:int, mission:Dictionary={}) -> Dictionary
- active_unit(state:Dictionary) -> Dictionary，空时返回 {}
- get_actions(state, unit_id:String) -> Array，元素 {id,name,cost,range,description,target}
- preview(state, unit_id:String, action_id:String, target:Dictionary) -> Dictionary，target={q,r}，返回 {ok,reason,summary,chance,damage,cost,path:Array,affected:Array}；不得改状态或随机数
- apply_action(state, unit_id:String, action_id:String, target:Dictionary) -> Dictionary，原地改 state，返回 {ok,reason,events:Array}
- end_turn(state) -> Array，推进并返回事件
- ai_step(state) -> Dictionary，执行当前敌人或受指令战犬的一步，或结束回合
- retreat(state) -> void

state 字段 schema,seed,rng_state,id,width=9,height=7,round,units,cells,props,order,turn_index,outcome,log,supplies,action_seq。
units 字段 id,name,kind,team(player/enemy),q,r,hp,max_hp,armor,max_armor,ap,max_ap=6,attack,accuracy,range,statuses(Dictionary),perks(Array)。hp<=0为死亡。kind=guard/spear/archer/skirmisher/hunter/dog/raider。战犬可另含 command,command_target,hunter_id。
cells 按字符串 q,r 索引，元素 {surface:dry/oil/water,field:空串/fire/steam,expires:int,blocked:bool}。props 数组元素 {id,kind:oil/water/cover/grain,q,r,hp,max_hp,blocks:bool}。
outcome=空串/victory/defeat/retreat；supplies={oil,fire,water}；order 为单位 ID 数组；turn_index 指当前；日志最近约80条。
轴向六边格 q=0..8,r=0..6。移动每格2AP，攻击通常3AP；盾击破绽、长枪利用。预览共用规则不抽随机。油火、水火蒸汽；火区每单位每轮至多一次，在创建轮N的N+1轮末失效；蒸汽同期限，遮挡远程。工具人人可用，数量+AP成本。破物件改变地表，强制位移不触发脱离反击。
事件格式 {type,actor,target,q,r,text,amount}，type=move/attack/hit/miss/fire/water/status/death/round。表现只读取事件，不结算规则。
猎团4个出战位含战犬；猎人花AP下达跟随、牵制、撤回，战犬自身回合执行，不刷新AP。敌人依同一规则。
mission 至少含 id,title,difficulty,supplies；grain 物件存活作为故事目标，敌人全灭胜利，玩家全灭失败，可撤退。

## 战役
campaign_rules.gd extends RefCounted，方法全部 static。
- create_campaign(origin:String,seed:int)->Dictionary，origin=free/hunters
- camp_action(c,action:String)->Dictionary，rest/resupply/repair/recruit，返回 {ok,reason}
- start_expedition(c)->Dictionary，生成保存条件事件，phase=event
- choose_event(c,choice_id:String)->Dictionary，phase=ready
- battle_config(c)->Dictionary，作为战斗 mission
- resolve_battle(c,battle)->Dictionary，恰好一次结算，phase=growth或camp
- choose_growth(c,offer_id:String)->Dictionary，兑现并phase=camp
c 字段 schema=1,seed,rng_state,company_name,origin,gold,food,day,renown,roster,flags,history,phase,expedition,event,growth_offers,growth_unit_id,last_report,battle,claimed。
event={id,title,body,choices:[{id,title,description}]}；growth_offers=[{id,title,description}]；生成即保存，不重抽。free四人guard/spear/archer/skirmisher；hunters四人guard/spear/hunter/dog。单位字段按战斗约定。补员保持4出战位。死亡不复活，有约束应急补员和低成本恢复通路。
perks 稳定ID：vigor(+8最大生命及当前生命)、precision(+8命中)，战役直接改数值；breacher(盾击+4伤害，利用破绽长枪+6伤害)、firewise(火区伤害减半)、packbond(战犬攻击标记目标+6伤害)，战斗读取perks。候选至少一个适配基础项，不重复学。
随机故事与成长采用小整数随机状态，避免JSON精度问题。每次远征至少一个选择、一个战斗、一个有后果结算；三次远征形成短篇收束后仍可继续佣兵团。六个事件在原额度内，死亡/缺席路径不阻断。
实际数值为原型假设，不能称最终平衡。

## 视图
battle_board.gd extends Control。
signal cell_clicked(q:int,r:int)，signal cell_hovered(q:int,r:int)。
set_battle(state:Dictionary)、set_selected(unit_id:String)、set_preview(info:Dictionary)、play_events(events:Array,speed:float=1.0)、set_animation_speed(speed:float)。
横向布局战场约800×560，可缩放；绘制轴向格、原创半身棋子与底座、武器区别、生命护甲、地表物件、选中预览及浮字。只读状态，动画不改规则。字体用系统Microsoft YaHei，勿复制参考图人物。

## 验证
测试脚本 extends SceneTree，语义检查失败退出非零。主AI最终执行测试、截图检查与导出包验证。存档含battle及生成候选；出征、选择、行动、结算后自动保存。
