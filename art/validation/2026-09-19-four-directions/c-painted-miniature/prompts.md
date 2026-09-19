# C 套生成提示与来源

生成日期：2026-09-19。工具：Codex 内置 `image_gen`，逐张单独生成/参考编辑；没有使用 CLI、API、程序绘图或 Python 修图。

## 共用锁定项

- 同一名约 38 岁成年男性佣兵：宽方脸、轻微向本人右侧偏的断鼻、榛色眼、发际线后移的深棕短发、短方胡，下唇下方一绺窄灰胡；左眉有一处自然缺口。
- 头脸为重点的半身战棋角色，面向画面左侧的 3/4 角度，镜头略高；软光来自画面左上。
- C 方向为手绘 2D 的精绘立体棋子感：圆润雕塑体积、精密边缘高光、微缩工艺笔触和可见颜料纹理。明确排除塑料、树脂、微缩模型照片与 3D 渲染。
- 第一层为苔藓橄榄色厚绗缝衬甲；第二层为圆润枪灰胸背甲、三片式肩部护片、棕皮带和黄铜铆钉；武器为方锤面、短四棱喙的单手战锤。
- 合成状态图使用不透明暖中灰底；独立部件要求真实透明 alpha。

## 01-bare-character.png

参考：无。初始生成源：`C:\Users\esmalls\.codex\generated_images\01a0ba4b-7895-71d1-be18-da721100e524\exec-08dce188-8fa3-467f-8736-4842439d86a7.png`。初稿意外为透明底，因此以它作为身份编辑目标，最终源：`C:\Users\esmalls\.codex\generated_images\01a0ba4b-7895-71d1-be18-da721100e524\exec-f07c5cf2-674b-4793-b631-c8eac6035677.png`。

初始提示词：

> Use case: stylized-concept. Asset type: modular 2D tactical game character identity master. Create exactly one adult male mercenary, about 38, broad compact build and large readable head, cropped bare chest-up so no genitals can appear. Mature square face, slightly broken nose leaning subtly to his right, close-cropped dark-brown hair with receding temple, short boxed beard with one narrow gray streak below the lower lip, hazel eyes, thick left eyebrow with a natural notch, calm alert expression. Original hand-painted 2D game illustration evoking an exquisitely painted tabletop miniature through rounded sculptural volumes, fine edge highlights and artisan brush accents, but not a photographed miniature, plastic, resin, 3D render or photoreal. Three-quarter view facing screen-left, camera slightly above eye level, full head and shoulders inside canvas. No clothing, armor, weapon, jewelry, wound, text, watermark, UI, frame, base or extra object.

最终背景修正提示词：

> Use case: precise-object-edit. Image 1 is the approved identity and pose. Replace only the transparent/black-looking backdrop with a completely opaque flat warm neutral mid-gray background. Keep the painted man fully visible exactly as in Image 1. Preserve face, age, broken nose, eyebrow notch, hazel eyes, hairline, beard and gray streak, bare shoulders, anatomy, pose, crop, scale, lighting, hand-painted 2D brushwork, sculptural volume, silhouette and all edges. Avoid transparency, black background, colored fringe, halo, plastic, resin, 3D render, text or watermark.

## 02-armor-one.png

参考：`01-bare-character.png`。生成源：`C:\Users\esmalls\.codex\generated_images\01a0ba4b-7895-71d1-be18-da721100e524\exec-20854a57-e0cf-464a-a764-75a4566cbccb.png`。

> Use case: identity-preserve. Dress only the same man in the first armor layer: a historically plausible heavy muted moss-olive linen/canvas padded arming coat with closely spaced vertical quilting, slightly open round collar, integrated padded shoulder caps, full sleeves, horn toggles and narrow worn brown belt. No plate, mail, helmet, weapon or gloves. Preserve exact face, body, pose, crop, warm-gray background and upper-left light. Same hand-painted 2D painted-miniature style with rounded volume, precise stitched highlights, woven detail and visible brush texture; no plastic, resin, 3D render, clipping, collage seam or white fringe.

## 03-armor-layered.png

参考：`02-armor-one.png`。生成源：`C:\Users\esmalls\.codex\generated_images\01a0ba4b-7895-71d1-be18-da721100e524\exec-d2ba60bb-6d38-4665-a864-29163e84ce6d.png`。

> Use case: identity-preserve. Add a credible late-medieval steel breast-and-back cuirass over the existing gambeson: rounded gunmetal breastplate with shallow central keel and rolled edge, narrow backplate edge and leather side straps, three compact overlapping shoulder lames per shoulder, dark-brown straps and small warm-brass rivets. Keep the moss quilted gambeson visible at collar, both sleeves, armpit gaps and lower edge. No helmet, gloves, weapon, shield or cape. Preserve exact identity, head location, pose, crop, background and lighting. Same hand-painted 2D miniature-painting language; avoid oversized fantasy pauldrons, spikes, mirror chrome, toy shine, gothic blackening or manuscript flatness.

## 04-armed.png

参考：`03-armor-layered.png`。生成源：`C:\Users\esmalls\.codex\generated_images\01a0ba4b-7895-71d1-be18-da721100e524\exec-8d410e72-67df-4f34-921b-dcf59c9901c5.png`。

> Use case: identity-preserve. Add exactly one historically credible compact one-handed horseman's warhammer: dark walnut straight haft, brown leather grip wrap, small gunmetal head with square hammer face toward screen-left and short four-sided beak toward screen-right, small brass collar. The near bare hand must grip the lower haft with coherent fingers; the haft rises beside the screen-left torso; the entire head and grip remain visible without covering the face or intersecting armor. Preserve identity, armor layers, background, lighting and hand-painted 2D painted-miniature style. Avoid oversized maul, mace ball, spikes, glow, duplicate weapon, malformed fingers, clipped head, plastic or 3D rendering.

## 05-wounded.png

参考：`04-armed.png`。生成源：`C:\Users\esmalls\.codex\generated_images\01a0ba4b-7895-71d1-be18-da721100e524\exec-be897dfa-e2b6-4edd-b4d4-a3b9571827e2.png`。

> Use case: identity-preserve. Depict the same equipped man newly wounded: small split and dried dark-red blood near the screen-right eyebrow/temple, purple-brown swelling under that eye, shallow cheek scrape and tightened tired expression. Add one fresh shallow diagonal breastplate scrape, tiny dent, faint smear and a scuffed adjacent shoulder edge. Keep the eye open and identity readable. Retain exact gambeson, cuirass, shoulder plates, warhammer and grip. Alter only injury, expression tension and localized wear. Avoid bandages, identity drift, blood covering the face, dismemberment, exposed bone, heavy gore, broken weapon, rusted whole armor or extra fingers.

## 06-downed.png

参考：`05-wounded.png`。生成源：`C:\Users\esmalls\.codex\generated_images\01a0ba4b-7895-71d1-be18-da721100e524\exec-9d43b719-9797-46af-8b95-eb56d0237082.png`。

> Use case: identity-preserve. Reposition the same intact equipped man into a clearly downed, unconscious or stunned pose without declaring death. Upper body lies diagonally on screen-right side on a warm-gray ground plane; head and neck stay fully attached and supported, face turned to camera enough to keep the broken nose, eyebrow notch, beard gray streak and injuries recognizable. Eyes closed, mouth relaxed, one forearm bent before the torso, same warhammer loosely held with its full head resting beside him. Preserve exact armor, wear, identity and painterly style. No new pool, death symbol, severed part, corpse stiffness, exposed anatomy, impossible limbs or clipped silhouette.

## 07-decapitated.png

参考：`06-downed.png`。成功生成源：`C:\Users\esmalls\.codex\generated_images\01a0ba4b-7895-71d1-be18-da721100e524\exec-0afc8f0e-efc3-4408-8522-975150d35f41.png`。一次更直白的受伤表述被内置工具以 violence 拒绝，没有产物；最终改为无伤口细节的模块化确认死亡表达。

> Use case: identity-preserve. Create a restrained symbolic confirmed-death game state made of two clean modular illustration components: the fallen armored body without its head, plus the same recognizable head module resting beside the shoulder. Exactly one head total. Hide both connection surfaces completely using the raised moss padded collar, viewing angle, beard and ground shadow, with no visible wound, blood, anatomy, bone or internal detail. The head lies peacefully beside the shoulder, eyes closed, same broken nose, eyebrow notch, hair and gray-streaked beard. Body remains in the same natural lying pose and layered equipment; same warhammer lies along the foreground. Same hand-painted 2D painted-miniature style. No extra person, duplicate head, horror mood, photorealism, text or UI.

## 08-armor-one-isolated.png

参考：`02-armor-one.png`。生成源：`C:\Users\esmalls\.codex\generated_images\01a0ba4b-7895-71d1-be18-da721100e524\exec-084d068e-590f-4507-a212-381b2a04ab13.png`。

> Use case: background-extraction. Reconstruct exactly the approved heavy moss-olive padded gambeson as one empty wearable object on genuinely transparent alpha. Keep vertical quilting, open high collar, padded shoulder caps, full upper sleeves, horn toggles, leather loop tabs and narrow brown belt. Show empty collar and both empty sleeve openings with hollow interior shadow. No body, head, skin, hands, armor plates, weapon, stand, hanger or mannequin. Center the full three-quarter garment with generous transparent padding. Preserve hand-painted 2D sculptural padding, precise stitched highlights and woven pigment texture; avoid gray background, checkerboard, cast shadow, white halo, colored fringe, clipping, plastic or 3D render.

## 09-armor-two-isolated.png

参考：`03-armor-layered.png`。生成源：`C:\Users\esmalls\.codex\generated_images\01a0ba4b-7895-71d1-be18-da721100e524\exec-1617a5f0-73e0-491e-af19-7843259ea27a.png`。

> Use case: background-extraction. Reconstruct exactly the approved second armor layer alone as one empty connected assembly on genuinely transparent alpha: rounded gunmetal breast/back cuirass, shallow central keel, rolled top edge, narrow backplate edge, dark-brown shoulder and side straps, small brass rivets, three compact overlapping shoulder lames each side. Show empty neck opening, arm gaps and interior shadow. No gambeson, cloth, body, head, skin, weapon, stand, hanger or mannequin. Center complete silhouette with padding. Preserve hand-painted 2D brushed metal and artisan edge highlights; avoid extra parts, oversized pauldrons, spikes, mirror chrome, white halo, clipping, plastic or 3D render.

## 10-weapon-isolated.png

参考：`04-armed.png`。生成源：`C:\Users\esmalls\.codex\generated_images\01a0ba4b-7895-71d1-be18-da721100e524\exec-d4743fc3-5810-46b6-a3ad-f5fb4064606a.png`。

> Use case: background-extraction. Reconstruct exactly the approved complete warhammer alone on genuinely transparent alpha: straight dark-walnut haft, lower brown leather grip wrap, small brass pommel cap, forged gunmetal head, broad square hammer face, short four-sided beak and warm-brass collar. No hand, fingers, arm, person, armor, stand or second object. Center diagonally with full head, beak, haft, grip and pommel visible. Preserve hand-painted 2D precision highlights, wood grain and leather volume. Avoid mace ball, axe blade, long two-handed proportions, spikes, glow, clipping, halo, plastic or 3D render.

## 11-head-isolated.png

参考：`01-bare-character.png`。生成源：`C:\Users\esmalls\.codex\generated_images\01a0ba4b-7895-71d1-be18-da721100e524\exec-a1cfc6ed-cb8d-4cfe-a1b7-af988d6b73a1.png`。

> Use case: background-extraction. Isolate the same man's normal unwounded head and short upper-neck module alone on genuinely transparent alpha. Preserve mature square face, broken nose, hazel eyes, receding dark-brown hair, boxed beard and narrow gray streak, left-eyebrow notch, calm alert expression and screen-left gaze. End the short neck in a smooth softly shadowed oval connection interface. This is a normal interchangeable module, not an injured head. No shoulders, torso, clothing, armor, wound, blood, pedestal or mannequin. Preserve exact 3/4 angle, scale, hand-painted 2D sculptural volume and micro-brush texture; avoid identity drift, closed eyes, gore, halo, plastic or 3D render.

## 12-body-isolated.png

参考：`01-bare-character.png`。生成源：`C:\Users\esmalls\.codex\generated_images\01a0ba4b-7895-71d1-be18-da721100e524\exec-f96e896b-15e5-4459-9f90-5ce967267ed5.png`。

> Use case: background-extraction. Reconstruct the same man's normal bare upper-body module alone on genuinely transparent alpha, head absent at a clean modular interface. Preserve broad compact adult shoulders, trapezius, chest, upper arms, skin tone, natural chest hair and believable anatomy; crop at upper abdomen so no genitals can appear. Neck rises to a short smooth oval mounting interface with intact softly shaded skin for the normal head module to overlap. Healthy game sprite part, not an injured body. No head, face, hair, beard, wound, clothing, armor, weapon, stand or mannequin. Same 3/4 orientation and hand-painted 2D sculptural style; avoid gore, corpse cues, extra limbs, exaggerated anatomy, halo, plastic or 3D render.
