# G 套：旅团民俗蛋彩生成记录

日期：2026-09-20
工具：Codex 内置 `image_gen` 逐张调用
目录：`art/validation/2026-09-20-refined-directions/g-roadside-tempera/`

没有使用 CLI/API、程序绘图、拼版、裁图或程序抠图。04 先生成并检查，动作一次成立，未使用允许的姿势修正次数；其余状态由本地参考图逐张编辑。生成原件保留于内置工具目录，项目文件为原样复制。

## 固定角色与风格

同一名约 36 岁的市井佣兵：宽而略歪的鼻、鼻梁与双颊雀斑、一高一低的浓眉、带眼袋的小号榛色眼睛、宽下颌、参差暗赤褐短发、斑驳胡茬、下唇旧豁口。面容稍夸张但可信，非俊美英雄。

G 风格融合 B 与 D：清楚、哑光的民俗蛋彩色面，克制深色轮廓，只在关节和脸部选择性刻线；保留不对称市井气质。第一层为褪色靛蓝绗缝衬甲，第二层为赭黄旧皮鳞片甲；只有右胸一处褪色铁锈红八瓣花纹。禁止密集分形、结晶、马赛克纹理和靠随机破洞制造细节。

## 逐张提示与来源

### 04-armed.png（母版）

- 模式：新生成。
- 提示要点：固定角色穿靛蓝衬甲和不对称赭黄旧皮鳞片甲，右胸一处八瓣花纹；双手在腰线和底托上缘之上持一支实用短矛，后手靠画面左下、前手靠中右，矛杆从左下斜向右上，矛头朝画面右前方空处；不倚肩、不穿脸/躯干。短半身落入低矮铁边木/皮椭圆托，底托约总高八分之一；透明背景。
- 输出源：`C:/Users/esmalls/.codex/generated_images/01a0ba4d-65fd-7ae0-9776-e6330ff170fb/exec-cad10437-aa5a-405a-81d0-61c37b41572b.png`

### 01-bare-character.png

- 参考：`04-armed.png`。
- 提示要点：去除短矛、两层甲、衣物和束带，保留同一脸、方向、比例及低底托；正常裸露肩胸，非情色，不含腰以下；双手分开自然放在底托上缘附近。
- 输出源：`C:/Users/esmalls/.codex/generated_images/01a0ba4d-65fd-7ae0-9776-e6330ff170fb/exec-aa46ce0c-a4f4-494e-a782-57c18b4ec444.png`

### 02-armor-one.png

- 参考：`01-bare-character.png`。
- 提示要点：只增加褪色靛蓝绗缝衬甲；翻折开领、宽竖绗线、长袖、手缝补丁和克制旧损；双手空置，底托保留；不含外甲或武器。
- 输出源：`C:/Users/esmalls/.codex/generated_images/01a0ba4d-65fd-7ae0-9776-e6330ff170fb/exec-786965a5-8b5b-4b3f-b7e1-047f4be038bb.png`

### 03-armor-layered.png

- 参考：`02-armor-one.png`。
- 提示要点：增加不对称赭黄旧皮鳞片外甲，鳞片集中于画面左肩/胸，画面右肋为较窄束带片；只保留一处八瓣花纹。靛蓝衬甲在领、双袖、中缝和腰部继续清楚可见；双手和底托保持。
- 输出源：`C:/Users/esmalls/.codex/generated_images/01a0ba4d-65fd-7ae0-9776-e6330ff170fb/exec-a6468450-1434-4136-bc44-c5883363c891.png`

### 05-wounded.png

- 参考：`04-armed.png`。
- 提示要点：同身份、手臂、握持、短矛方向、两层甲和底托；增加画面左眉浅切伤、眼下淤青、左颊擦伤；左上胸相邻鳞片出现划痕和一处裂边，下面靛蓝袖对应磨损。血迹局部克制，脸仍可辨。
- 输出源：`C:/Users/esmalls/.codex/generated_images/01a0ba4d-65fd-7ae0-9776-e6330ff170fb/exec-02bc13f2-9eca-4e34-bc20-68c8f085d77d.png`

### 06-downed.png

- 参考：`05-wounded.png`。
- 提示要点：同一伤员无力向画面右前侧倒伏；近侧脸和肩向下，双臂完全松垂、手指松弛，任何手掌或手肘都不支撑身体；半睁失焦眼、微张嘴。腰部由重叠鳞片和靛蓝衣褶向远处透视收拢，不出现水平切口或腿脚；取消站立底托；短矛脱手放在身旁。
- 输出源：`C:/Users/esmalls/.codex/generated_images/01a0ba4d-65fd-7ae0-9776-e6330ff170fb/exec-9817fbe9-5135-4323-8b9d-e63baa75c91c.png`

### 07-decapitated.png

- 参考 1：`06-downed.png`，负责 G 身份、短半身倒伏、甲和短矛。
- 参考 2：上一轮 `b-illuminated-tempera/07-decapitated.png`，只负责克制、非写实的伤口程度，不采用其角色、全身、剑和背景。
- 提示要点：实心倒伏短躯体和同一分离头部，头放在肩旁且面容可辨、闭眼；高靛蓝领、头发和深色阴影遮住大部分接口，只留窄而暗的红色绘制边；不出现骨、脊柱、肌肉、器官、内脏、飞溅或血泊；双臂仍连接并无力，腰下不生长腿脚，短矛仍在旁。
- 输出源：`C:/Users/esmalls/.codex/generated_images/01a0ba4d-65fd-7ae0-9776-e6330ff170fb/exec-2adde7a5-694b-49da-96c8-426cf64e7059.png`

### 08-armor-one-isolated.png

- 参考：`02-armor-one.png`。
- 提示要点：仅保留同一件空靛蓝衬甲；空领、空袖清楚，无人物、人台、底托、外甲和武器；透明背景。
- 输出源：`C:/Users/esmalls/.codex/generated_images/01a0ba4d-65fd-7ae0-9776-e6330ff170fb/exec-ab245b7e-c3c9-412a-a5fd-2ad059b83721.png`

### 09-armor-two-isolated.png

- 参考：`03-armor-layered.png`。
- 提示要点：仅保留同一套空赭黄皮鳞片外甲及皮革底、束带、扣具、铆钉、修补系带和唯一八瓣花纹；不得保留靛蓝衬甲、人物、人台、底托或武器；透明背景。
- 输出源：`C:/Users/esmalls/.codex/generated_images/01a0ba4d-65fd-7ae0-9776-e6330ff170fb/exec-3028f23f-6be0-49f6-92d8-814aac289a1c.png`

### 10-weapon-isolated.png

- 参考：`04-armed.png`。
- 提示要点：只保留同一支完整短矛：叶形暗铁矛头、短铁套、直白蜡木杆、后段深色皮握和包铁尾帽；左下到右上对角展示，透明背景，无手、人物或底托。
- 输出源：`C:/Users/esmalls/.codex/generated_images/01a0ba4d-65fd-7ae0-9776-e6330ff170fb/exec-54946e9c-6cc6-4656-8fce-12174acba8f5.png`

### 11-head-isolated.png

- 参考：`01-bare-character.png`。
- 提示要点：正常未受伤头部和短颈装配边；保留宽歪鼻、雀斑、高低浓眉、眼袋、暗赤褐发、胡茬和愈合下唇豁口；朝画面右侧，透明背景，无肩胸、装备或死亡暗示。
- 输出源：`C:/Users/esmalls/.codex/generated_images/01a0ba4d-65fd-7ae0-9776-e6330ff170fb/exec-86cd263d-7b4c-4082-a64b-6065321abee4.png`

### 12-body-isolated.png

- 参考：`01-bare-character.png`。
- 唯一一次提示：同一健康成年男性的正常无装备肩胸、上腹和双臂模块；无头无底托，颈部为平滑封闭、非解剖的深棕装配面；非情色，不含骨盆、伤口、血迹或死亡含义，透明背景。
- 状态：内置工具在输出阶段以 `sexual` 拒绝，未生成可复制文件。按任务要求未改写措辞重复尝试，也未用穿衣、程序裁切或空模块代替。

### 13-base-isolated.png

- 参考：`04-armed.png`。
- 提示要点：只保留同一低矮浅椭圆托：手锤暗铁外圈与铆钉、深胡桃木/皮革内面、正确轻俯视角和承重厚度；不得变成高台、墓碑或钱币；请求透明背景。
- 输出源：`C:/Users/esmalls/.codex/generated_images/01a0ba4d-65fd-7ae0-9776-e6330ff170fb/exec-00a41cdb-8b04-4a18-822a-2d590ca4e81c.png`
