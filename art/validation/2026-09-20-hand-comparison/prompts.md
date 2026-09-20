# 本轮生成提示词

内置 image_gen 编辑模式，输入项目已有 B v2 图集；2 次输出。原输出复制保存，未进行代码绘画、抠图或栅格修改。部件在 Godot 中按原图 UV 裁区与锚点绘制。

输入：`../2026-09-20-motion-templates/sources/b-atlas-v2-source.png`

输出：`sources/arm-poses-shield.png`，运行副本 `game/assets/art/motion/hand-style-parts.png`。

第二次输出：`sources/closed-shoulder-body-atlas.png`，运行副本 `game/assets/art/motion/hand-style-body.png`；只采用其右上角闭合肩袖链甲，其他八部件继续用旧B图集以避免身份漂移。A/B共用这一躯干，无手版本不留下空洞或截断臂。

第二次提示：

```text
Use case: precise-object-edit. This is an existing 3x3 transparent game sprite atlas. Edit ONLY the TOP RIGHT chainmail sleeveless torso. Keep its exact chainmail ring size and color, brown quilted padded undergarment, brown leather collar and belt, brass buckle, proportions, same shape/short waist. Replace the two BLACK EMPTY ARMHOLES with natural CLOSED rounded padded shoulder caps covered in chainmail, as a complete compact Battle Brothers half-body bust costume. The top and sides must flow from chest to shoulders, no black circular socket, no open cut tube, no exposed skin, no hand or arm. Both shoulders are part of the continuous torso silhouette, slightly rounded; nothing sticks up separately. This modified torso will be shared by two variants; separate full arms are added at runtime over it when desired. Do not add head, hands, weapons or base to this torso cell. Keep the OTHER EIGHT objects and exact 3x3 arrangement and transparent background unchanged. No labels or grid or scenery, actual RGBA transparency. Production-ready H fine medieval painted game asset, keep original restrained realistic brushwork, no larger body, no new costume.
```

第一次提示：

```text
Use case: identity-preserve / production sprite parts. Input image is the existing Fantasy Brothers H/B v2 atlas, reference for exact padded brown leather sleeve material, linework, skin tone, lighting and shield design. Generate ONE transparent RGBA 2x2 sprite-part sheet, four evenly spaced cells, no labels, no grid, no scenery, no shadows beyond each object's edge. Same art scale and identical anatomy/material in all three arm cells. Upper-left cell: ONE complete rear sword arm from shoulder to curled gripping hand, seen on the SCREEN LEFT side of a compact bust facing screen right; shoulder high at upper left, elbow down-left, forearm travels right and slightly up to fist, a relaxed open L bend with fist well away from the chest. Upper-right cell: SAME arm, same shoulder position relative cell and same bone lengths, modest preparation pose, elbow a little bent and hand drawn back and higher. Lower-left cell: SAME arm contact pose, shoulder same position, elbow OPENED outward toward SCREEN RIGHT, forearm reaches right, fist farther right and a little higher than relaxed pose, wrist straight/neutral, no inward hook. These are three alternative complete arm cutouts for one arm; show no torso/head/base or weapon attached, no duplicate arms. Keep sleeve silhouette compact, clear shoulder attachment overlap; arm short and stout like the reference. Closed curled fingers to wrap a separately layered sword grip; preserve distinct fingers and thumb, avoid open palm. Lower-right cell: ONLY the reference's round wood shield with weathered steel rim/boss, shown in a slight THREE-QUARTER view appropriate for protection towards SCREEN RIGHT (right rim leading, shield still broad/readable, no spikes, no hand). All four components isolated and FULLY within their cell, generous transparent spacing. Fine dark contour, restrained painterly realistic medieval miniature texture matching reference; not cartoon simplified, not glossy3D. Transparency real alpha, no checkerboard baked. Large square sheet.
```
