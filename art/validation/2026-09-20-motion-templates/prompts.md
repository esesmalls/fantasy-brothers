# 动作模板图集生成提示词

日期：2026-09-20。所有图片均使用 Codex 内置 `image_gen`；没有调用 CLI 或外部 API。工具未返回可核实的模型名，因此模型记为未知。B 的首次生成提示词没有成功保存，以下只记录已知任务要求，不反推或伪造原文。

## B 部件母版（既有）

- 编辑目标：无；首次生成。
- 已知要求：H 主导的同一名佣兵，透明部件图集；普通头、衬甲躯干、链甲躯干、左右握拳前臂、竖剑、圆盾、低底座、受击头共九件。
- 原始工具输出：`C:/Users/esmalls/.codex/generated_images/01a0bd16-21c4-7440-9916-972303f52565/exec-df98f1cd-3ac5-4009-9bd7-f7dd15cbb954.png`
- 工作区源文件：`sources/b-atlas-source.png`
- 运行文件：`game/assets/art/motion/b-atlas.png`

## A 清晰简练图集

编辑目标：`sources/b-atlas-source.png`

```text
Use case: precise-object-edit
Asset type: transparent 2D game character component atlas, A clarity template
Primary request: Edit the supplied B atlas in place into the clearer, simpler A rendition. Preserve the exact same nine isolated components, character identity, H-style compact proportions, silhouettes, orientation, relative scale, and approximate positions: normal head; padded torso; mail torso; two clenched forearms; vertical sword; round shield; low metal base; injured grimacing head.
Style/medium: hand-painted medieval fantasy game art, H visual standard, firm dark-brown outline, clean readable painted color masses.
Materials/textures: simplify small scratches, pores, chain highlights, wood grain, and quilt noise; use calmer grouped values and fewer tiny marks while keeping each material recognizable.
Composition/framing: do not redesign or rearrange the atlas; keep every component fully separated with generous transparent gaps and no cropping.
Constraints: same man, face, hair, beard, armor shapes, weapons, base, poses, handedness and view direction as the input. All nine components must remain complete. Actual transparent background with clean RGBA edges.
Avoid: new objects, missing hands, merged components, labels, grid lines, text, watermark, opaque or checkerboard background, glow, drop shadow, pixel art, vector-flat style, photorealism, changing anatomy or layout.
```

## C 细腻笔触图集

编辑目标：`sources/b-atlas-source.png`。第一次相同调用因网络错误退出且无输出，随后原样重试成功。

```text
Use case: precise-object-edit
Asset type: transparent 2D game character component atlas, C detailed-painterly template
Primary request: Edit the supplied B atlas in place into the refined C rendition. Preserve the exact same nine isolated components, same character identity, H-style compact proportions, silhouettes, orientation, relative scale, and approximate positions: normal head; padded torso; mail torso; two clenched forearms; vertical sword; round shield; low metal base; injured grimacing head.
Style/medium: hand-painted medieval fantasy game art led by the approved H standard, with only a restrained touch of E/G realism and old-master tempera/oil brush character. Keep the firm dark-brown H outline and small-size readability.
Materials/textures: add selective natural brush variation, subtle age, irregular warmth, and material-specific wear to skin, cloth, leather, chainmail, wood and steel. Concentrate fine detail around face, seams, edges and focal material changes; keep broad shapes calm and readable.
Composition/framing: do not redesign or rearrange the atlas; keep every component fully separated with generous transparent gaps and no cropping.
Constraints: same man, face, hair, beard, armor shapes, weapons, base, poses, handedness and view direction as the input. All nine components complete. Preserve H head/body ratio and short torso. Actual transparent background with clean RGBA edges.
Avoid: new objects or ornament, missing hands, merged components, labels, grid lines, text, watermark, opaque or checkerboard background, glow, drop shadow, noisy micro-detail everywhere, photorealism, longer realistic anatomy, changing layout.
```

## 共享终态图集首稿

参考图：`sources/b-atlas-source.png`（脸、装备与武器）和 `../2026-09-20-h-standard/04-armed.png`（H 身份、比例与装备连续性）。

```text
Use case: compositing
Asset type: transparent 2D game terminal-state atlas shared by A/B/C templates
Input images: Image 1 is the authoritative B component atlas for the man's face, padded armor, mail armor, sword and shield; Image 2 is the approved H armed reference for identity, compact proportions and equipment continuity.
Primary request: Create one new two-frame atlas with two coherent terminal death poses of this exact same medieval mercenary. Left frame: full body collapsed under gravity wearing the dark padded armor. Right frame: full body collapsed under gravity wearing the same chainmail over padding. In both frames the eyes are closed, limbs and torso lie with convincing weight and ground contact, and the complete body remains anatomically connected. The sword and round shield have fallen nearby within each frame and read as part of one coherent aftermath composition.
Style/medium: approved H hand-painted medieval fantasy game art, compact large-head proportions, firm dark-brown contour, restrained B-level painterly material detail, clear at normal game scale.
Composition/framing: two distinct side-by-side frames, left and right, with generous transparent separation; each frame contains one complete horizontal collapsed body plus its nearby sword and shield. Keep both figures at matching scale, fully inside canvas, no standing base.
Constraints: same face, hair, beard, clothing colors, armor design, sword and shield identity as the references. This is current HP 0 confirmed death with no specific death type: show stillness and closed eyes only, with at most subtle non-graphic battle wear. True transparent RGBA background and clean edges.
Avoid: decapitation, dismemberment, severed parts, extra severe wounds, gore focus, separate modular body parts, armor displayed without a body, sleeping pose, head resting on an arm, pillow-like arm, propping up on elbows, kneeling, rising, standing base, text, frame borders, labels, watermark, opaque or checkerboard background, drop shadow halo.
```

## 共享终态图集第一次修正

编辑目标：`sources/terminal-atlas-v1-source.png`。首稿两格都把头放在前臂上，像睡姿，因此仅修正头与手臂落地关系。

```text
Use case: precise-object-edit
Asset type: transparent two-frame 2D game terminal-state atlas
Primary request: Correct only the death-pose readability in both frames. In both the left padded-armor frame and right chainmail frame, move the head off the forearm so the side of the face rests directly on the ground. Move both arms away from under the head: let them lie slack, asymmetrically extended beside or slightly forward of the torso, with elbows and wrists fully supported by gravity. The pose must unmistakably read as lifeless collapse rather than sleep.
Constraints: preserve the same two-frame layout, exact same man and closed-eye identity, armor, colors, body scale, complete connected anatomy, sword and shield positions, transparent background, rendering style, and clean outline. No standing base. Keep each frame fully inside the canvas.
Avoid: head resting on any arm or hand, pillow arm, folded sleeping arms, propping up, bent elbow supporting the chest, kneeling, rising, decapitation, dismemberment, severe wounds, gore, added objects, labels, borders, opaque background, watermark.
```

首稿和第一次修正都误补了长腿全身，与已经确定的 H 半身棋子比例不符；两稿均只作为失败来源保存在 `sources/`，没有冒充合格运行资源。

## 共享终态图集结构修正（采用）

参考图：`sources/b-atlas-source.png`（身份、两甲、剑盾）和 `../2026-09-20-h-standard/06-downed.png`（经批准的 H 半身倒伏构图）。这次追加修正由主代理在发现长腿结构偏差后批准。

```text
Use case: compositing
Asset type: transparent two-frame 2D game terminal-state atlas, structural correction
Input images: Image 1 is authoritative for the same man's face, padded armor, chainmail, sword and shield. Image 2 is authoritative for the approved H half-body game-piece proportions and gravity-collapsed pose.
Primary request: Create a side-by-side two-frame terminal atlas using the approved H HALF-BODY GAME PIECE anatomy. Left frame wears the dark padded armor; right frame wears the chainmail over padding. Each frame shows the same man's complete head, very short torso from shoulders through the naturally finished waist/armor hem, and two complete arms and hands collapsed under gravity. Eyes closed, cheek directly on the ground, arms slack and spread away from the face. Sword and round shield lie nearby as coherent dropped equipment.
Critical anatomy rule: DO NOT DRAW ANY BODY BELOW THE WAIST. No hips, thighs, knees, lower legs, trousers, shoes or boots. This character is intentionally a waist-up chess-piece-like game unit, not a realistic full-body human. The lower edge must be a clean natural rounded garment/armor waist hem tucked under the short torso, matching the approved H standing unit language. It must not look cut off, amputated or wounded.
Style/medium: approved H hand-painted medieval fantasy art, compact large-head silhouette, firm dark-brown contour, restrained B-level texture, readable when reduced.
Composition/framing: exactly two distinct horizontal collapsed half-body figures, left and right, equal scale, fully inside canvas with transparent separation; no standing base.
Constraints: same face, hair, beard, colors, armor design, sword and shield as Image 1. Confirmed HP 0 death with no special death type: stillness and closed eyes, no added severe injuries. True transparent RGBA.
Avoid: legs, boots, trousers, hips, full-body anatomy, visible anatomical stump, gore at waist, head on arm, pillow pose, propping up, kneeling, rising, standing base, decapitation, dismemberment, extra blood, modular pieces, labels, borders, text, watermark, opaque background, shadow halo.
```

## B v2 完整结构母版

版本：`b-assembled-v2`。参考 `../2026-09-20-h-standard/04-armed.png` 与 `sources/b-atlas-source.png`。用途是先固定完整颈口、肩肘腕、握柄和腰底遮挡，再从完整结构拆层；这张图是技术拆层参考，不代表用户批准。

```text
Use case: compositing
Asset type: single complete transparent 2D game character structure master, normal idle/ready pose
Input images: Image 1 is authoritative for the exact H character identity, large-head compact half-body proportions, short waist, hand-painted contour language, and low base contact. Image 2 is authoritative for this character's heavy chainmail, company one-handed sword, round wooden shield, and low metal base design.
Primary request: Draw ONE fully assembled coherent character, not an atlas and not separate parts. The same H mercenary wears the heavy chainmail over dark padded armor and stands in a calm ready stance on the low metal base, holding the company one-handed sword in his right hand on the image-right side and the round shield in his left hand on the image-left side.
Critical body structure: preserve the original H large head and very short compact waist-up chess-piece proportion. The neck must sit naturally deep inside the padded collar and chainmail neckline, with no floating ring or empty gap. The belt, chainmail hem and lower garment must meet and overlap the top surface of the base directly, making a clear weight-bearing contact; no hovering waist, no dark air gap, no hard cut line above the base.
Right sword arm: the image-right upper arm descends naturally from the image-right shoulder; elbow remains beside the torso; forearm rises in a relaxed ready angle; wrist neutral. The fist is at waist height. Sword blade points diagonally outward to the upper right, fully away from the face. Show enough grip length: crossguard clearly above the fist and round pommel clearly below the fist. The hand, grip, wrist, sleeve, elbow and shoulder must read as one continuous anatomical chain.
Left shield arm: the image-left shoulder, upper arm, elbow, forearm and wrist form one continuous believable chain behind and into the round shield grip. Shield sits on the image-left side in a practical guarding angle without swallowing the shoulder.
Style/medium: approved H hand-painted medieval fantasy game art, firm dark-brown outline, restrained B-level material texture, readable at normal game scale.
Composition/framing: one centered complete assembled half-body character and base, all edges fully inside the square canvas, transparent background, no other objects.
Constraints: both complete hands remain at the waist line; each arm emerges from its own shoulder. Preserve the same face, hair, beard, chainmail, padding, sword, shield and base identity. Keep natural overlap and depth between shield, arm, torso, sword hand and base.
Avoid: atlas layout, isolated components, duplicated limbs, two long forearms crossed across the abdomen, two-handed sword grip, hands stacked together, sword through face, sword leaning on shoulder, broken or hidden grip, crossguard inside fist, missing pommel, floating head, exposed neck peg, floating torso, gap above base, legs, text, watermark, opaque or checkerboard background, drop shadow halo.
```

## B v2 九格拆层图集

版本：`b-atlas-v2`。以 `sources/b-assembled-v2.png` 为结构和重叠关系唯一母版，`../2026-09-20-h-standard/04-armed.png` 只支持 H 身份、比例和笔触。v1 被退回的原因是独立部件拼装造成头身与领口脱节、腰部悬在底座上、手臂缺少连续肩肘腕结构，并使持械姿态别扭；v2 改为先完整成图再拆层。

```text
Use case: compositing
Asset type: transparent 2D game character rig atlas, B version 2
Input images: Image 1 is the authoritative fully assembled B v2 character. Derive every component from its overlapping anatomy, armor, pose, sword, shield and base rather than independently redesigning parts. Image 2 is supporting reference for the same H identity, large-head short-waist proportions and hand-painted contour.
Primary request: Produce exactly NINE isolated transparent components in a clean 3-by-3 atlas, ordered left-to-right:
Top row: (1) normal head with short neck for insertion into the collar; (2) padded-armor torso with NO arms and NO sleeves extending beyond the shoulder sockets; (3) chainmail-over-padding torso with NO arms and NO sleeves extending beyond the shoulder sockets.
Middle row: (4) the complete image-right bent sword arm copied from Image 1, from shoulder cap through upper arm, elbow, forearm, wrist and naturally clenched gripping fist, but WITHOUT the sword baked in; (5) the complete image-left bent shield arm copied from Image 1, from shoulder cap through upper arm, elbow, forearm, wrist and naturally clenched gripping fist, but WITHOUT shield or weapon baked in; (6) the one-handed sword alone, vertical, with a grip long enough to slide behind/inside the fist, visible crossguard and pommel.
Bottom row: (7) round shield alone, approximately 15 percent smaller than Image 1 but same design; (8) low metal base alone, same design; (9) same face injured/grimacing head with short neck, but NO new blood, cuts, bruises or wounds.
Rig structure is the priority: both torso variants must be genuinely armless chest pieces. Do not repeat upper arms, sleeve cylinders, hands or shoulder limbs on the torso. Retain only rounded padded/chainmail armhole edges where the separate arms overlap.
Image-right arm geometry: shoulder attachment at the component's upper-right, upper arm descends along the right side, elbow bends at the outer lower-right, forearm rises and reaches inward toward the left, fist at lower-left/center. Preserve Image 1's neutral wrist and one-handed ready pose.
Image-left arm geometry: shoulder attachment at the component's upper-left, upper arm descends along the left side, elbow bends at the outer lower-left, forearm reaches inward toward the right, fist at lower-right/center, preserving Image 1's shield-arm pose.
Each arm shoulder end needs a generous rounded dark padded overlap extension for insertion beneath the torso armhole, never a flat cut stump. Fingers form a natural gripping fist with an open palm channel for inserting the separate sword grip or shield handle; no weapon fragment inside either fist.
Torso/base structure: keep the original compact short torso. Padded and mail torso bottoms include the belt and short garment/armor below it so they can touch and overlap the base top directly, with no floating waist gap.
Style/medium: exact approved H hand-painted medieval fantasy style and same B v2 identity; firm dark-brown contours, restrained readable material texture.
Composition/framing: exact 3x3 spatial arrangement with large transparent gutters; every item fully visible, mutually separated, no overlap, no cropping; square transparent RGBA canvas.
Constraints: sword blade may be about 15 percent shorter than Image 1 while preserving shape. Preserve the same face, hair, beard, padding, mail, leather, steel, wood and base design.
Avoid: a complete assembled person, extra components, fewer than nine components, atlas labels, text, numbers, grid lines, opaque or checkerboard background, repeated arms on torso, detached forearm-only pieces, flat shoulder cuts, anatomical stumps, baked sword or shield in fists, crossed arms, straight hanging arms, duplicated hands, blood on the injured head, watermark, glow, drop shadows connecting parts.
```

## A v2 清晰简练图集

编辑目标：`sources/b-atlas-v2-source.png`。只改变表面画法，沿用 B v2 的格位、轮廓和完整手臂结构。

```text
Use case: precise-object-edit
Asset type: transparent 2D game rig atlas, A version 2 clarity variant
Primary request: Edit the supplied B v2 atlas in place into A v2 by changing ONLY the surface rendering toward clearer, simpler color grouping. Preserve the exact same nine components, exact 3x3 cell positions, bounding shapes, silhouettes, sizes, spacing, arm bends, shoulder overlap ends, fists, face framing, torso armholes, sword, shield and base geometry.
Required invariants: both full arms must keep precisely the same shoulder-to-upper-arm-to-elbow-to-forearm-to-wrist-to-fist pose as the source. Both torsos remain truly armless. Normal head and grimacing hit head remain the same face at the same scale and framing. Do not move, rotate, resize, crop, redraw or exchange any component.
A rendering change only: reduce tiny scratches, small pores, scattered quilt marks, excessive chain highlights, dense wood grain and metal speckle. Consolidate them into calmer hand-painted value groups and cleaner material shapes while keeping chainmail, padding, leather, wood, skin and steel immediately recognizable at normal game scale. Retain the approved H dark-brown outer contour and a modest handcrafted brush feel.
Injury rule: the grimacing head changes expression only and must not gain blood, cuts, bruises, swelling, scars or other new wounds.
Background/export: preserve true transparent RGBA with clean isolated gutters. No labels, numbers, text, grid lines, shadow bridges or opaque/checkerboard background.
Avoid: redesign, new clothing, removed clothing, new trim, new armor pieces, altered face or hair, altered hand anatomy, opened or closed fist changes, changing sword length, changing shield size, changing base, duplicated limbs, missing components, merged components, photorealism, vector-flat rendering, watermark.
```

## C v2 细腻笔触图集

编辑目标：`sources/b-atlas-v2-source.png`。只改变表面画法，沿用 B v2 的格位、轮廓和完整手臂结构。

```text
Use case: precise-object-edit
Asset type: transparent 2D game rig atlas, C version 2 refined painterly variant
Primary request: Edit the supplied B v2 atlas in place into C v2 by changing ONLY the surface rendering toward more refined but restrained hand-painted material texture. Preserve the exact same nine components, exact 3x3 cell positions, bounding shapes, silhouettes, sizes, spacing, arm bends, shoulder overlap ends, fists, face framing, torso armholes, sword, shield and base geometry.
Required invariants: both full arms must keep precisely the same shoulder-to-upper-arm-to-elbow-to-forearm-to-wrist-to-fist pose as the source. Both torsos remain truly armless. Normal head and grimacing hit head remain the same face at the same scale and framing. Do not move, rotate, resize, crop, redraw or exchange any component.
C rendering change only: add selective fine brush variation, subtle age, restrained edge wear, gentle warm/cool shifts and material-specific texture to skin, padding, chainmail, leather, wood and steel. Concentrate detail at the face, seams, contact edges and key material transitions while keeping broad color groups calm. Preserve small-size readability, the approved H dark-brown outer contour and the B v2 identity. Do not increase texture density uniformly.
Injury rule: the grimacing head changes expression only and must not gain blood, cuts, bruises, swelling, scars or other new wounds.
Background/export: preserve true transparent RGBA with clean isolated gutters. No labels, numbers, text, grid lines, shadow bridges or opaque/checkerboard background.
Avoid: redesign, new clothing, removed clothing, new trim, new armor pieces, altered face or hair, altered hand anatomy, opened or closed fist changes, changing sword length, changing shield size, changing base, duplicated limbs, missing components, merged components, new wounds, gore, noisy micro-detail everywhere, photorealism, longer anatomy, watermark.
```
