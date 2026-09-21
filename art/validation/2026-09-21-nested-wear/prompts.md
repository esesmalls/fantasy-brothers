# U50 原画编辑记录

两次内置 `image_gen.imagegen`，均成功。源图先通过 `view_image` 检查；输出原样复制入项目，未以Python／画笔程序抠图、修改像素或生成伤损。下面为实际提示文本。

## 1. 正常衣甲透明开口

输入：项目 `game/assets/art/static-bust/full-garments.png`。

输出：`game/assets/art/static-bust/full-garments-nested.png`。注册亚麻、绗缝和链甲三块区域，基础内衣继续引用旧图。

```text
Use case: precise-object-edit. Edit target is the supplied original H fantasy medieval clothing sprite atlas. Produce the SAME four garments in the SAME 2 by 2 layout, same pixel size, exact positions, perspective facing screen-right, same fabric detail, colors, shoulder silhouette, arm/hem lengths, folds, stitching and painterly rendering. This is a game PAPERDOLL LAYER TOPOLOGY repair, not a new clothing design. Preserve transparent background with real alpha. No body, mannequin, neck, head, hands, base, text or checkerboard painted in image.
Top-left brown close-neck UNDERSHIRT remains unchanged. Top-right grey flax LINEN OVER-SHIRT: the entire dark cavity INSIDE its bound V-neck neckline must become an actual transparent hole, down to the V lace point. Keep the narrow sewn collar rim and lace, but remove ALL the solid dark/brown cloth painted inside that neckline. The opening must show a separately composited brown undershirt below at runtime, never contain prepainted inner clothing. Make the FRONT V opening 10% wider/deeper if needed so underlying undershirt is readable. Bottom-left golden quilted GAMBESON: open round neckline must be a true transparent cutout, with its FRONT edge slightly lower/larger than the linen's round upper opening to expose the real linen underneath. Keep a thin padded rolled rim, worn texture and all torso unchanged. Bottom-right steel CHAINMAIL: its inside round collar must be true alpha transparency, NOT painted gold padding; move its front collar rim a little lower / enlarge opening approximately 12% relative to the gambeson's round neck so gold gambeson can visibly nest inside. Preserve a narrow leather rim with thickness and rivets, no fixed golden underlayer anywhere inside. In every case keep only each garment's OWN material, not material belonging to lower garments. The three outer garments need ACTUAL interior transparent neck holes continuous to the transparent background, not black holes, not dark opaque shadows and not a painted checkerboard. Thin natural edge shading may remain only right at collar edges. Preserve all four original garment silhouettes and registration so they can be stacked together; maintain same scale and original canvas size.
```

## 2. 破损衣甲真实露底

输入1：第一次输出，作为编辑目标；输入2：旧 `full-damaged.png`，仅参考伤损位置和材质。

输出：`game/assets/art/static-bust/full-damaged-nested.png`。只注册下排两种破损甲，不采用上排的基础内衣／亚麻变动。

```text
Use case: precise-object-edit. IMAGE 1 is the exact edit target, a four-sprite H medieval paperdoll clothing atlas with real transparent neckline holes. IMAGE 2 is ONLY a reference for the type and placement of armor wear. Preserve IMAGE 1 canvas size1254x1254, all four garment positions, silhouettes, folds, materials, perspective, collar shapes and especially real transparent neck holes. Top two shirts entirely unchanged. Only add damage to the lower two armors as separate matched variants. Bottom-left gold quilted gambeson: near the upper front chest, below the front/right side of its neckline (source atlas approx x448 y786), create one clearly readable torn opening with ragged golden cloth edges, stitches and a little of the gambeson's OWN pale stuffing on the ragged perimeter, but with a real transparent center at least25px across. The actual linen garment worn below must be seen dynamically THROUGH the hole, so paint NO white linen or brown undershirt across the center. Bottom-right mail: near upper chest approx x1070 y783 and x880 y811 create two irregular openings in the rings. Twisted/split hanging metal rings and a narrow natural edge shadow around the perimeter. The interior center of each tear must be real alpha0 transparency, no painted gold quilted material (which is wrong in IMAGE2), no black fill and no fake checkerboard. Larger hole around45x38 pixels, smaller one25x20 so observable after bust cropping. Keep worn seam and edge nicks subtle and non-repeating. Damage belongs only to each outer garment. Transparent background and internal apertures with actual alpha. No body, base, mannequin, head, text, weapon or additional items. Very important: keep every undamaged pixel region and the original alignment as closely as possible; this variant must overlay the normal asset without silhouette or collar jumps.
```

实际结果：均为1254×1254 RGBA。提示要求不等于逐像素保持承诺；生成有局部纹理变化。本轮保留完整原图，使用注册区域、透明度读取及实际装配检验；没有把工具输出当作自动通过美术验收。
