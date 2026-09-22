# ISSUES · pilot5 / assembly-v0.1.0-pilot5

tested_revision: `3170da1789a87fc5bd83218cef6eb3321f4cb03e`  
装配包: `assembly-v0.1.0-pilot5` sha256=`233e500d8735fdfac023927b74c33e836d6f6535bb1432b5075aab151a1087de`  
评审: 奇幻兄弟·QA · 2026-09-22  
像素未改。

| issue_id | 资产 | 严重度 | 状态 | 问题 |
|---|---|---|---|---|
| ISS-01 | headgear_metal_001 | MAJOR | OPEN | 脸口偏低：帽檐盖住双眼，开口落在口鼻/下颌 |
| ISS-02 | headgear_metal_001.main, padded_001_damaged | MAJOR | OPEN | 开口/破口含烘焙棋盘或不透明近白，不是干净真透明 |

## ISS-01 MAJOR · 头盔脸口偏低

装配器已知、像素未改。QA 目视 + 解析变换叠图确认。

- 装配包 `known_limits` 写明盔底在绗缝领线上沿 y=-44.5，不是脸枢轴 y=-32.5，主开口会落在颊/颌，眉在前片下。
- 现有预览 `previews/pilot5-head-helmet.jpg`、`previews/pilot5-stack.jpg`：帽檐盖住眼眶，窗口只露出鼻、口、下颌。
- 本轮 8× 解析叠图 `iss01_helmet_opening_low.png`、`hgw01_resolved_full_combo.png` 同一现象。
- 1× 最近邻放大 `t06_1x_dark_nn8.png`：脸部身份不可读，只剩暗洞和嘴。

不是 BLOCKER：能加载，规则绑定没错；QA.md 把「错误开口」定为 MAJOR。未改像素。

证据：`iss01_helmet_opening_low.png`、`iss01_probe_eye_vs_mouth.png`、`hgw01_resolved_full_combo.png`、`../pilot5-head-helmet.jpg`

返修：装配（上移盔/开口对齐眼鼻）或原画（把脸口画在眼带）。不要在 QA 里发明像素。

## ISS-02 MAJOR · 烘焙棋盘 / 非真透明开口

对 PNG 取样，再把 RGBA 铺到洋红并存成 JPEG（无 alpha），避免把查看器棋盘误当成文件内容。

- `headgear_metal_001.main` 源像素在开口带（约 x=710–800, y=300–360）为不透明灰白交替，例如 `(254,254,254,255)` / `(203,203,203,255)`。包围盒约 `(513,109)–(798,408)`。RGB 去 alpha 裁切见 `iss02_helmet_opening_rgb_noalpha.png`。
- 该棋盘在深色预览里仍在（`pilot5-head-helmet.jpg` 的窗洞），真透明在深底上应露出深色或脸，而不是灰白格。
- `padded_001_damaged` 洋红扁平 JPEG 的 near-gray 约 26350，完好件同一指标为 2。破口里有不透明近白，例如源图 `(598,393)=(255,255,255,255)`。`iss02_padded_damaged_flatten_magenta.jpg`。
- 结果：HGW-01 与 WEAR-padded_001_damaged-NONE 不能声明「窗口/破口透出真实内层」。

head / padded_001_intact / sword 的洋红扁平图干净，不并入本缺陷。

证据：`iss02_helmet_opening_rgb_noalpha.png`、`iss02_helmet_main_flatten_magenta.jpg`、`iss02_padded_damaged_flatten_magenta.jpg`、`iss02_padded_damaged_baked_white.png`、`analysis.json`

返修：原画。把开口和破口打成 a=0，去掉烘焙棋盘和填白。

## 未单独立项

- 头盔 main 开口周围有不透明暗腔（盔内壁）。单独看可以接受，但和 ISS-01 叠在一起会进一步挡住上脸。
- 破损甲破口排列很规则。未当结构缺陷；先修 ISS-02。
- `sword_001` 源图剑尖在 max y，装配 `flip_y` 后尖朝上。与装配说明一致，不是缺陷。
- `--gate assembled` 失败是因为其余约 25 件仍是 planned，不是像素故障。
