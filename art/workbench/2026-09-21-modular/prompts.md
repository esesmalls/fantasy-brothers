# U51 拆件试样生成记录

## 最后角度回调：以用户新胸肩参考为准

用户指出上一版侧过，提供轻侧胸肩参考。目标调整为轻微右侧向，双侧胸肩可见，远肩仅略收窄。用户参考只用于角度与轮廓，不作为游戏像素资产。

追加：用户明确“不留这么多脖子”。移除明显颈柱，改为肩线之间的浅连接口，头部低落覆盖。实际追加英文提示：DO NOT leave a visible long neck. Remove the tall neck column. Use a shallow dark neck socket sitting directly between the shoulders like the reference; only a tiny connecting collar area remains. No exposed vertical neck stalk.

成功输出 `exec-0a449ca2-306d-453b-a664-e297ac0b322f.png`，存为 `body-mild-proof.png`。只接入右上身体；上一版明显侧身被用户退回，保留为历史，不作为当前身体。项目不裁改PNG像素，使用源矩形和运行时固定盘面显示。

```text
Precise local correction to image1 body-turn-proof.png, a medieval 2D paperdoll atlas. ONLY redraw the upper-right chest-and-shoulder component, leave both faces and bottom-left base untouched. Preserve transparent background,1254x1254 dimensions, same warm skin and H handpainted line/material style.
User says the torso in image1 is turned TOO FAR. Image2 is the user's desired angle reference, use its torso orientation and silhouette ONLY, not its low resolution or coloring. Turn the existing torso BACK TOWARDS THE VIEWER, to a mild three-quarter turn toward screen right (approximately 15-20 degrees instead of 40). BOTH chest halves and BOTH shoulders clearly visible, with only slight foreshortening of the far right shoulder. Front chest centerline just right of center, nearly frontal. Near left shoulder modestly rounded, not a dominant oversized side-arm. Match the relaxed compact shoulder/chest mound in image2, no strong deep side profile. Keep the very short neck attachment and broad softly rounded lower chest edge.
Keep the torso contained in the same upper-right sprite footprint, approx x595..1193 y270..655. No enlargement, no added arms/hands or clothing. This is ordinary nonsexual adult upper-chest game artwork. Change only body orientation, retain fixed token proportions and crisp small-scale readable H detail. Do not add labels, props, extra parts or background.
```

## 用户追加肩胸朝向修订

用户复看缩小版后指出身体朝向仍有问题，要求再倾斜一点。按肩胸更向右侧转理解，单独编辑现有身体区域；保持已确认的衣物、头部与底座尺寸。此次成功输出 `exec-5a1f1d23-6d7f-4f9d-871e-c44be25e841a.png`，项目存为 `body-turn-proof.png`，只采用右上身体区域，其余区域不接入。

```text
Precise edit of an existing medieval paperdoll sprite sheet, for character equipment fitting. Edit ONLY the UPPER-RIGHT adult male chest-and-shoulder sprite in the supplied body-head.png. Keep the two face sprites and the bottom-left base unchanged. Preserve transparent background, canvas dimensions, the same warm skin palette, outlined H handpainted detail and lighting.
The required correction is ORIENTATION, not increased body size: turn the shoulder girdle and chest farther toward SCREEN RIGHT to match the attached shirt reference. The near shoulder on image LEFT is prominent and rounded, the far shoulder on image RIGHT visibly foreshortened and narrower; chest centerline shifted right, collarbones in believable perspective. About 40 degrees of three-quarter turn toward screen right. Do not keep a symmetrical frontal chest. Maintain the compact stocky but not bulky proportions and a very short neck attachment hidden under the face in final assembly.
Keep the body sprite within the existing upper-right placement (approximately x583..1247, y287..650 on1254x1254 canvas). Its lower edge remains a broad curved bust cut suitable for a circular token. No arms or hands added, no clothing painted into this base body component, no changes to other sheet components, no new text or props. This is ordinary nonsexual adult upper-torso game character artwork.
```

## 身体朝向补样

本次调用未成功：输出阶段被工具安全系统以 sexual 拦截（请求ID `64fac7d4-c4ca-491b-8fd6-01214449ff91`）。没有输出图片。中间版曾用现有 `body-head.png` 的裸身原画缩至宽52。之后用户追加身体朝向反馈，采用上节现有图集局部编辑成功的新版身体；此失败记录保留，不作为可用资产。

```text
Create one isolated headless male torso game sprite on a genuinely transparent background. This is a nonsexual adult anatomical base layer for a medieval tactical paperdoll. Reference image 1 body-head.png establishes the mature weathered character's warm skin and crisp H handpainted texture; reference image 2 full-garments-nested.png establishes the REQUIRED body orientation and shoulder contour of the garments it must fit UNDER.
The body MUST face 3/4 toward SCREEN RIGHT, exactly like the shirts in image2, NOT a symmetrical forward facing bodybuilding chest. Broad nearer left shoulder, strongly foreshortened far right shoulder. Neck socket towards screen right, very short natural neck collar area mostly to be hidden by attached jaw. Natural average strong mercenary physique, no exaggerated breast masses or sculpted six pack. Show upper torso down to lower ribs and short upper arms that continue naturally downward; no forearms, hands, wrist stumps, no cropped cuffs, no head, hair, equipment, pedestal, words, shadows on background or wound. Shape is a smooth unified torso silhouette, side-lit upper-left with organic skin texture and very sparse chest hair, asymmetrical small freckles; match worn handpainted H style, no 3D plastic skin. Underclothing geometry: keep bare shoulders narrower than the shirt shoulders, and oriented the same way so no shoulder sticks out over a shirt. Let the shirt image guide perspective, NOT clothing details.
Use canvas 1024x1024, torso centered with broad margin, shoulders span about 720 pixels, short neck at upper center-right y180, chest/upper arms descending to about y840. No gore, no genitals, just an adult male upper torso. Fully transparent cutout outside silhouette.
```

工具：内置 imagegen。参考：现有 H `body-head.png`；不复用战场兄弟图片作为项目资产。

用途：工具验收试样，尚非批量人物资产质量定稿。原 PNG 和正式目录不覆盖。

```text
Create a production 2D transparent modular paperdoll sprite atlas for Fantasy Brothers, using the attached H head reference for identity, painterly inked medieval material, 3/4 view facing screen RIGHT, lighting and characterfulness. This is a tooling proof set, not a UI or diagram.
Exactly SIX separate components in a precise 3-column by 2-row grid on a 1536x1024 RGBA canvas, each cell 512x512 with margins, genuinely transparent background everywhere outside the component; no labels, no borders, no checkerboard.
Cell1 top left: the same mature weathered male face, but completely bald and clean shaven, no neck stump, closed face bottom at jaw; naturally asymmetrical stern expression, broad nose, rough brows, face visible from front-left side looking right; entire cranium included. Occupy approximate local x90..430 y40..475.
Cell2 top middle: ONLY separate swept-back brown/salt-and-pepper HAIR fitting the exact cranium from cell1, same scale and pose in SAME local cell coordinates. Fine asymmetric loose strands, hollow facial area fully transparent. NO face or scalp skin or ears painted into this hair part.
Cell3 top right: ONLY separate short rough salt-and-pepper BEARD and moustache fitting the exact jaw of cell1 in SAME local cell coordinates. Mouth opening genuinely transparent. NO face, nose, lips or skin.
Cell4 bottom left: ONLY one healed diagonal forehead/temple scar detail with a few fine suture marks, organically irregular, warm pale raised ridge and restrained red-brown edge. Isolated small overlay near local x295 y150, about80x120px, transparent around it, NO underlying face patch or skin rectangle, NO gore.
Cell5 bottom middle: ONLY offwhite worn linen forehead BANDAGE fitting exact cell1 forehead in SAME local cell coordinates, with convincing overlapping cloth wraps, one small dark dried stain, perspective curved around the head. Cover forehead band around y145..215, fromx100..415, little loose end atleft. Empty rest of cell transparent. No head rendered.
Cell6 bottom right: ONLY a restrained irregular dark dried blood stain cluster for a chest/cloth overlay, few fine flecks and two short directional smears, no rigid outline, no skin or fabric under it, approximate center cell260,260 and width180 height150. Avoid uniformly distributed splatter or neon red.
No arms, hands, weapons, bases, torso or extra sprites. Each of the head/hair/beard/bandage assets must share exact view and scale. Crisp but hand-painted contours; strong small-scale readability; no plastic 3D render, no blurry AI textures. Preserve detailed handpainted H quality. Do not reproduce any reference atlas layout beyond the requested six-cell grid.
```
