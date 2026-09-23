# 武器反馈音源小样（2026-09-23）

本目录保存可再加工的原录音及许可凭据。游戏用短音在 `game/assets/audio/weapon/`，处理脚本是 `tools/audio_weapon_forge.py`。这批声音服务一个角色的一套完整动作反馈；目前与动作模板一起覆盖轻剑、重刃斧、矛、弓和盾格挡。它们只读表现时间与已结算结果，不承担命中、伤害或资源判定。

## 来源与授权

| 原包 | 制作者、地址与许可 | 本地保留 |
| --- | --- | --- |
| Medieval sound effects — Weapon Textures | Ben Jaszczak 与 Brian Nelson 录制；[OpenGameArt 页面](https://opengameart.org/content/medieval-sound-effects-weapon-textures)，CC0。原始 7z 归档 SHA-256：第 1 包 `b5e2b2c86d811d983d15dbf8453df6a25275a2a0dc4e88e0dc5e1cb3046fd4ae`；第 2 包 `5181e1ea63714cd954bd5972b39ac095c8bdfea88a7abe1dea41fb272de0480f`。 | `sources/recordings/` 中 7 份原始 192 kHz PCM 录音：Axe Swing、Dagger Draw Fast、Dagger Swing、English Longbow Draw／Nock Arrow／Shoot、Spear Swing。|
| RPG Audio | Kenney Vleugels；[Kenney 原页](https://kenney.nl/assets/rpg-audio)，CC0。原包 SHA-256 `6dbeaf8544da958d8f2adcb4a4a4b76c1ade34a05f8ab9edccd327da7375f38b`。 | `sources/kenney-rpg/Audio/` 中 4 份使用的 OGG；原包许可文本保存在 `sources/KENNEY-LICENSE.txt`。|
| Impact Sounds | Kenney Vleugels；[Kenney 原页](https://kenney.nl/assets/impact-sounds)，CC0。原包 SHA-256 `029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8`。 | `sources/kenney-impact/Audio/` 中 5 份使用的 OGG。|

原录音包是公开免费商用的 CC0 素材，未采购。下载归档仅用于抽取和核对，未保留整包以免使工程增加约 177 MB；保留的原片段可直接重跑导出脚本。署名并非许可条件，但应在最终制作人员表中保留以上作者。

## 加工与运行映射

用 `python tools/audio_weapon_forge.py` 在仓库根目录重导。脚本以 SciPy／NumPy 截取真实录音，192 kHz 下采样为 48 kHz、16-bit、单声道 WAV，做直流去除、轻度峰值限制和两端 8 ms 渐隐；没有合成波形、生成式声音或倍速变调。Kenney OGG 按原样复制。所有切片起止秒数和导出名在脚本 `CUTS`／`KENNEY` 表内，脚本即唯一加工配方。

| 动作阶段 | 录音与导出名 | 用途 |
| --- | --- | --- |
| 轻剑出手／回收 | Dagger Swing → `blade_light_release.wav`；Dagger Draw Fast → `blade_light_recover.wav` | 短促切入与收势。 |
| 重刃斧出手 | Axe Swing → `blade_heavy_release.wav` | 蓄势后更宽、更沉的划风。 |
| 矛出手 | Spear Swing → `spear_release.wav` | 直刺风声；需要与轨道方向一起评审。 |
| 弓预备／瞄准／离弦 | English Longbow Nock Arrow／Draw／Shoot → `bow_prepare.wav`、`bow_draw.wav`、`bow_release.wav` | 离弦与目标接触是不同时间点。 |
| 箭矢飞行 | Spear Swing → 复用 `spear_release.wav`，独立 flight 事件，−20 dB | 真实破风录音的低音量拟音，不宣称专门的箭矢飞行实录；可独立替换。 |
| 闪避／未中 | Dagger Swing → `miss_result.wav` | 短划空，不混用皮肉命中音。 |
| 手持与收势 | Kenney RPG Audio → `blade_prepare.ogg`、`cloth_prepare.ogg`、`cloth_recover.ogg`、`metal_recover.ogg` | 动作两端小音量。 |
| 皮肉／护甲／盾接触 | Kenney Impact Sounds → `flesh_light.ogg`、`flesh_heavy.ogg`、`armor_light.ogg`、`armor_heavy.ogg`、`shield_contact.ogg` | 接触材质由规则事件的已结算结果或调用方快照决定；盾音用木质冲击拟音。 |

`weapon_feedback.gd` 的 `action_template()` 给出五种动作的时长和预备／出手／接触／回收节点；旧已发布动作的显式标记优先。`authored_action()` 可对尚未手调的新武器从旧 schema 5 动作派生时间轴，盾击只生成盾自身 x／rotation 轨道。主棋盘接入由主代理负责。`play_cue()` 在 2 倍速保留离弦和接触的原音高、略去部分细小收势声；`skip_to_result()` 停止过程声并播放一次结果提示。

## 已查验及待复审

Godot 4.7.2 `--headless --path game --script res://tests/test_weapon_feedback.gd`：42 项通过，覆盖 17 个可导入音源、五类时序、未中／护甲／格挡路由、倍速不改音高、跳过结果以及 schema 5 派生动作有序和不改原本数据。游戏音频导出合计约 0.51 MB，保留的原录音约 33.4 MB。没有在可听设备上做主观混音，也没有在 Windows 战场导出包内试听；最终音量、声像、重复频率、盾木拟音与实际盾材质是否相称仍需实际试玩复听。源库未提供专门的真实盾格挡录音，当前这层是明确的临时拟音。
