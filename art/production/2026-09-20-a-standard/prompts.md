# A标准生产提示词

## 最后补充：terminal-damaged

```text
Edit target: the attached transparent 8-piece medieval reclining CLOTHING atlas. Keep EXACT canvas size, positions, two columns by four rows, pose, scale, empty neck garment openings, gloves, trousers, boots and ALL silhouettes. These are modular clothes display pieces, receive separate heads later. Make the DAMAGED CLOTHING versions of all eight garments. Row1 padded cloth MUST gain 2-3 clearly readable diagonal tears showing light inner linen stuffing, scraped leather shoulder caps, frayed lower hem. Row2 leather has slashes through leather showing the same padded fabric underneath. Row3 blue-gray brigandine has torn fabric and a few dented exposed metal plates; preserve the rivet pattern and belts. Row4 silver chainmail has visibly broken rings and 2-3 gaps exposing padded underclothing. ALL rows get restrained dark red dried battlefield stains concentrated beside one chest tear and cuffs, painted realistically with uneven edges, without changing the armor identity. Clothing damage only: do NOT add exposed anatomy, dismemberment, bones, flesh, neck wounds, blood pools or spectacle. The stains and damage will serve either an injured fallen character or a confirmed casualty, so do not invent narrative identity. Preserve original fine realistic medieval gouache/ink style, natural wear, not uniform red tint. Keep background fully transparent alpha. No labels, bases, faces, weapons, shadow discs, scene. Exact layout/scale preservation is the highest priority so existing neck/head/weapon anchors remain valid.
```

最终共 12 张成功原始输出，另有 2 次初始连接失败。新增受损倒伏图保留四甲外观和领口锚点，同时补足衬甲破损。

以下后补提示在本文件末尾保存：弓弦完整臂姿势、完好倒伏衣甲、独立亚麻内衣。本批最终共 12 次成功输出，另有最初 2 次连接失败。原始图均保留，提示要求不代表视觉验收已通过。

工具：内置 image_gen。主AI亲自生成与装配；精确模型信息未提供。

两次最初的护甲参考编辑调用因连接失败无输出；随后成功生成的原始文件全部保留。以下记录实际使用提示，不代表所有生成要求自动通过。

## 1. armor-states

```text
Use case: precise-object-edit. Production game sprite atlas for Fantasy Brothers, transparent background. Use the approved refined medieval mercenary H visual language with charcoal outlines, finely painted metal/leather, warm browns, cool grey chainmail, top-left lighting. Make a NEW torso-only atlas with exactly 16 separate bust torso cutouts, arranged in an evenly spaced 4 columns by 4 rows grid on a square transparent canvas, generous transparent gutters. No heads, hands, forearms, weapons, bases, labels or other objects.
CRITICAL posture: each torso has a natural forward lean toward SCREEN RIGHT, waist planted centered, chest and neck about 8% torso width to the right of waist. All chests are turned THREE-QUARTER RIGHT, not front-facing symmetrical: screen-left near shoulder prominent, far screen-right shoulder receding; collar is an angled ellipse, belt wraps around volume. Short stocky half-body proportions, complete waist/belt, small closed shoulder caps ready for separate arm layers, no dark open sockets. SAME collar/shoulder/waist positions, silhouette scale and pose in all 16 cells.
Rows specify FOUR DIFFERENT armors: row1 brown quilted padded gambeson with diagonal stitching, row2 dark chestnut leather armor with diagonal crossing straps and buckles, row3 muted slate blue brigandine with regular brass rivets over cloth, row4 steel chainmail over brown padding with leather edging and same belt as reference.
Columns specify the SAME armor through FOUR damage states: col1 intact maintained gear; col2 moderately worn with two small material-specific tears; col3 heavily damaged with clear irregular frayed areas/loose links or exposed inner plates; col4 exhausted armor badly torn yet still recognizable as the SAME clothing, identical collar belt buckles color and dimensions. Chainmail damage must be broken rings and exposed padding, NOT cracks in plate. Padded tears expose cotton, leather splits at seams, brigandine reveals overlapping metal plates. No blood. Damage must read in small game sprites. Preserve transparent holes and true RGBA alpha. Each sprite fully inside its own cell, no overlap, exactly 16 torso assets. High detail hand-painted 2D illustration, only slight oil brush texture, NOT pixel art, NOT photoreal 3D.
```

## 2. weapons

```text
Production sprite atlas for an original medieval fantasy tactical game. Detailed hand painted 2D equipment in a refined illustrated mercenary style, precise dark brown outlines, restrained realistic oil paint texture, worn grey iron, brown wood and leather, top-left lighting. True transparent RGBA background. Exactly 12 ISOLATED objects, even 4 columns by 3 rows, generous blank gutters, full objects inside each cell, no shadows outside objects, no text.
Read row by row: row1 a straight single-handed arming sword, a broad heavy cleaver sword, a compact narrow dagger, a sturdy notched hand axe; row2 a long simple leaf-tipped spear, a long hooked spear with a clear side hook, a short plain bow, a tall longbow; row3 a leather-wrapped hunting bow with small tied cord detail, a compact recurved bow, an iron-rimmed round wooden shield with round boss, a heavier oval dark red wooden shield with iron edging.
All swords knives axes spears vertical with blade/head up and grip/butt down. Blades clear against transparency, realistic attached hilts. Spears fit same tile height through design scale only, not cut off. Bows viewed from side with wood curving toward screen RIGHT, open concave side on the LEFT. Four bows have visibly different limb silhouettes. Do NOT draw bowstrings or arrows (dynamic strings are added in engine). Shields viewed three-quarter right, visible wood panels and rim thickness. Original designs, no copied logos, no decorative lettering, no scenery, no people, no hands. Small-size readable silhouettes, not pixel art or 3D render.
```

## 3. armor-shells

```text
Use case: precise-object-edit. This is a production LAYER EXTRACTION of the attached 4x4 armor atlas, NOT a redesign. Retain the exact 16 grid positions, canvas proportions, torso scales, three-quarter right perspective, silhouettes and original grey/brown/blue painting.
For ALL 16 torsos: output ONLY the OUTER CHEST ARMOR layer, with its original damage state. Remove the waist belt including buckle/straps from every torso; remove shoulder caps and the small inner sleeves; remove the raised neck collar. Those will be separate engine layers. Preserve the main chest material shape and lower hem of the vest, with transparent neck and arm holes. For damage openings: make the interior holes genuinely TRANSPARENT instead of painting the underlying tunic/padding; preserve the ripped/frayed/broken-ring edge. Brigandine's exposed metal plates are part of the outer armor and MUST remain. For padded armor, some exposed cotton along the torn edge should remain but center holes should be alpha-transparent.
Do not fill holes black or brown, use true transparency. No heads, weapons, hands, belts, buckles, shoulder caps, inner sleeves or written labels. Exactly 16 separate outer chest armor cutouts in the SAME 4x4 positions and SAME pose. Keep the diagonally attached strap on LEATHER chest because it is part of that armor, but remove the horizontal waist belt. No new adornment. Actual RGBA alpha.
```

## 4. faces-01-06

```text
Production game HEAD sprite atlas. Refined hand-painted medieval fantasy mercenaries, realistic anatomy with bold charcoal outlines and restrained oil-paint brushwork, warm natural skin tones, readable brows/noses/jaws, consistent top-left light. NOT 3D, NOT anime, NOT pixel art.
A tall transparent canvas, EXACTLY 4 columns x 6 rows, 24 separate isolated heads, no text, frames, scenery or shadows. Each row is ONE person with identical face, hair, age, proportions, scale and neck position across its four cells; all face THREE-QUARTER SCREEN RIGHT. Same head silhouette size across rows, shoulders and clothes excluded, short bare neck with clean soft anatomical end. Do not stretch heads to fit.
COLUMN1 focused neutral; COLUMN2 effort/gritted teeth/brows lowered during action; COLUMN3 same person persistently wounded with restrained cheek abrasions and bruising, strained expression (no missing features); COLUMN4 relaxed closed eyes and slack expression for lying-down/death state, no new wound, same person, no gore.
ROW1: rugged pale male veteran about45, short tousled brown hair with gray at temples, thick salt-pepper short beard, angular long nose, dark intense eyes, exactly a grounded experienced sword mercenary.
ROW2: weathered woman about38, olive skin, strong square jaw, dark shoulder-length hair tied back, no beard.
ROW3: young woman about25, fair freckled skin, auburn hair in a low braid, narrow angular face, green eyes.
ROW4: stocky man about32, medium brown skin, wide nose, short tight black curls, clean-shaven, broad face.
ROW5: lean male woodsman about50, sun-browned skin, swept-back dark hair and thin brown mustache, long high cheekbones.
ROW6: older woman about60, gray hair in a practical bun, lined angular face, pale gray eyes and slightly hooked nose.
Precisely 6 different identities x 4 states. Do NOT swap identities between columns. Heads do not touch cell edges or each other. Real transparent alpha, no background color, no collars or helmets. Detailed but suited to readable 35-pixel game head display.
```

## 5. faces-07-12

```text
Production game HEAD sprite atlas. Refined hand-painted medieval fantasy mercenaries, realistic anatomy with bold charcoal outlines and restrained oil-paint brushwork, warm natural skin tones, readable brows/noses/jaws, consistent top-left light. NOT 3D, NOT anime, NOT pixel art.
A tall transparent canvas, EXACTLY 4 columns x 6 rows, 24 separate isolated heads, no text, frames, scenery or shadows. Each row is ONE person with identical face, hair, age, proportions, scale and neck position across its four cells; all face THREE-QUARTER SCREEN RIGHT. Same head silhouette size across rows, shoulders and clothes excluded, short bare neck with clean soft anatomical end. Do not stretch heads to fit.
COLUMN1 focused neutral; COLUMN2 effort/gritted teeth/brows lowered during action; COLUMN3 same person persistently wounded with restrained cheek abrasions and bruising, strained expression (no missing features); COLUMN4 relaxed closed eyes and slack expression for lying-down/death state, no new wound, same person, no gore.
ROW1: athletic woman about30, tan olive skin, short black side-parted hair, a small old scar on chin, sharp cheekbones.
ROW2: older male about55, copper-red short hair and thick red mustache fading grey, pale freckled face, prominent brows.
ROW3: rugged enemy raider about40, shaved head with short dark stubble beard, broad nose, weathered pale skin.
ROW4: enemy raider about28, shaggy black shoulder-length hair, narrow eyes, thin untrimmed beard, olive skin.
ROW5: enemy archer woman about35, short sandy blonde hair, light skin, square forehead, thin lips.
ROW6: enemy raider man about48, deep brown skin, short greying tight curls, short silver beard and strong jaw.
Precisely 6 different identities x 4 states. Preserve identity strictly across each row. All24 heads same three-quarter right viewpoint, readable hand-painted game illustration, strong warm-dark silhouette outlines. Same neck height and cell placement. Genuinely transparent background with alpha outside each head, no collars, scenery or labels.
```

## 6. grip-arms

```text
Production sprite PARTS atlas for an original refined hand-painted medieval tactics game. Exactly SIX separate complete CLOTHED ARM cutouts in 3 columns x 2 rows, square transparent canvas with wide gutters. All belong to the SAME average human adult wearing dark warm-brown quilted padded sleeves with leather wrist cuffs, light tan bare hands. Dark brown ink outline, restrained oil-paint texture, clear elbow folds, top-left light; not 3D or pixel art. Each arm includes a short shoulder cap, upper arm, elbow, forearm, wrist and anatomically natural full hand. No body, head, weapons, bow, arrows, labels, shadows or background. Solid sleeve edges, no open black sockets. Never make isolated floating hands.
These poses are for a character facing SCREEN RIGHT; shoulder is always towards the LEFT side of each cell:
TOP LEFT: forward support arm for bow, shoulder left, elbow slightly lower in middle, forearm almost horizontal extending right, vertical closed grip fist at far right; gentle bend, wrist straight.
TOP MIDDLE: bow drawing arm at rest, shoulder upper-left, upper arm travels down-left and forearm curves upward-right, hand forward-right in a relaxed three-finger string-hook grip.
TOP RIGHT: bow drawing arm at full draw, elbow strongly pulled back to the LEFT of shoulder, forearm angles up-right toward cheek level, three fingers hooked on an invisible string near the upper-right, wrist aligned. Bent elbow clear, shorter shoulder-to-hand distance than resting draw arm.
BOTTOM LEFT: rear spear gripping arm, shoulder upper-left, elbow low middle, forearm extends right horizontally, closed fist with thumb up grasping invisible horizontal shaft, natural straight wrist.
BOTTOM MIDDLE: front spear supporting arm, shoulder upper-left, elbow lower-left, forearm extends to right slightly upward, palm-up cupped support grip around invisible horizontal shaft.
BOTTOM RIGHT: relaxed command arm, shoulder upper-left, bent elbow, hand raised at right with two fingers pointing right.
All6 occupy similar scale, same sleeve details and skin tone, fingers clear and physically plausible. Entire forms inside slots. True alpha-transparent background, no color wash.
```

## 7. warhound

```text
Original medieval fantasy tactical game production sprite atlas, finely painted 2D with strong dark outlines, restrained realistic texture, top-left light, true transparent background. Exactly 6 FULL BODY sprites of ONE SAME gray warhound, arranged 3 columns x 2 rows, large clear transparent gaps. Stocky athletic wolfhound/mastiff mix, short rough dark grey fur with lighter muzzle, dark ears, brown leather harness and simple small iron chest plate. No rider or base. All six sprites identical anatomy, fur marks and harness.
Top-left alert standing idle facing RIGHT, four paws planted. Top-middle attack anticipation facing RIGHT, crouched back with neck drawn in. Top-right attack contact facing RIGHT, front body lunges forward, jaws open for bite, hind paws pushing; full tail and paws included. Bottom-left wounded but standing, lowered head, one subtle shoulder scratch and strained face, same harness. Bottom-middle collapsed on side, whole dog on ground, no base, eyes closed, no gore, uncertain downed state. Bottom-right clearly lifeless slack side-lying pose, closed eyes, a restrained dark wound on flank and a small blood stain, no dismemberment or gore, same animal and harness. Keep complete bodies inside each slot. No text, labels, scenery, rectangles, painted floor or opaque shadows. Genuine transparent alpha.
```

## 8. terminal-bodies

```text
Production RPG sprite asset sheet derived from the supplied armor designs. Exactly EIGHT isolated fallen clothed body cutouts, arranged 2 columns by 4 rows on a tall transparent canvas. Same refined hand-painted dark outlined H style, short stocky adult proportions, top-left illumination. Preserve the four armor designs exactly by row: quilted brown gambeson; chestnut leather cross-strap; slate-blue brass-riveted brigandine; grey chainmail over brown padding. Same belts and buckles.
Each cell is a FULLY CLOTHED RECUMBENT BODY, with both arms, bent trousered legs and boots; no base, no ground rectangle, no standing person. Column1 lying heavily on side, shoulders/neck at SCREEN LEFT, hips and slightly bent knees toward screen RIGHT; bottommost forearm loosely on ground, not propping body up. Column2 lying face-down obliquely, shoulders at SCREEN LEFT, knees to RIGHT, limbs slack, no supportive elbow. Full weight contact and fabric compression. No weapons or shields (assembled separately).
HEADS ARE SEPARATE game modules: leave the small neck attachment concealed within a folded padded collar at the left shoulder end, with no visible neck flesh, wound, gore or severed surface. This is a dressed mannequin-like modular game asset, not decapitation. No blood; both poses can represent downed/uncertain survival. Head will be composited separately at the left collar. Neck area must be a natural narrow attachment, not a large open empty suit.
All eight figures at exactly the same scale and orientation, complete visible anatomy of clothing and boots, quiet heavy collapsed pose. Dark worn brown boots/trousers in all variants. No loose body parts, no skulls, no skeleton, no dismemberment. Transparent RGBA background, generous gutters, no text, labels or cast floor shadows.
```

## 9. bow-string-arm-poses

```text
A transparent production animation PART atlas: exactly THREE full right arms for ONE medieval human archer, side by side in a wide horizontal 3-column strip. SAME physical arm length, sleeve details, hand size, perspective and PIXEL SCALE in all three cells; do not zoom in bent poses. Dark brown diamond-quilted padded sleeve, leather wrist cuff, light tan hand, strong brown ink outlines, hand-painted realistic 2D, top-left light. No head/body/bow/arrow/string/labels or scene.
This is the REAR STRING-DRAWING ARM of a person facing RIGHT, shoulder near the LEFT in each cell and fingers at RIGHT. Hand uses a natural three-finger hook for a bow string, not a fist.
Cell1 RELEASED/REST: arm reaches nearly straight HORIZONTALLY to screen right, shoulder to fingers roughly 3 times shoulder width; elbow has only slight bend. Long horizontal shoulder-to-fingers distance.
Cell2 HALF DRAW: same arm bends at elbow, elbow drops slightly down and back to LEFT, fingers halfway closer to shoulder. Clearly HALF the shoulder-to-hand reach of cell1.
Cell3 FULL DRAW: elbow pulled far back to SCREEN LEFT of the SHOULDER, forearm folds across biceps toward SCREEN RIGHT, fingers beside the shoulder at CHEEK HEIGHT, only about one shoulder-width to right of shoulder. This is strongly folded archery pulling anatomy, with the elbow behind the shoulder, NOT an arm reaching upward. Wrist and forearm aligned, string fingers pointed/right-facing.
Keep all three connected arms complete, relaxed shoulder caps for attaching to torso, no missing wrist or dislocated elbow, enough clear margins. Actual alpha transparency outside arms. Middle and full-draw sprites occupy less horizontal space because of foreshortening, not a larger scale.
```

## 10. terminal-intact

```text
Edit target: the attached 8-pose transparent medieval body-part atlas. Preserve EXACT original image dimensions, 2-column 4-row layout, the neck openings and every body pose, hand, boot, body silhouette and scale. This is a repair-state variation: restore ALL four suits to PERFECT FULL DURABILITY. Row1 diamond-quilted brown padded jacket; row2 brown leather armor with diagonal belt; row3 blue-gray riveted brigandine with brass rivets; row4 silver mail with leather belt. Close every armor tear and missing ring; remove damage holes, cracks, blood and stains; restore intact continuous armor texture naturally. Keep padded sleeves, shoulders, belt, gloves and trousers identical. Keep all eight bodies headless as modular garment assets; the empty neck openings are cloth apertures, no anatomical wound, no blood. The bodies are reclining as wardrobe display cutouts and will receive separate heads. Do not add bases, shadow plates, labels, background, weapons, faces, or heads. Real alpha transparency outside the garments. Precise hand-painted ink contours and restrained realistic gouache, same style as target. Single task: undamaged versions of ALL eight existing poses, no redesign.
```

## 11. inner-linen

```text
Use the attached atlas ONLY as a STYLE AND EXACT SILHOUETTE REFERENCE. Create ONE standalone transparent 2D sprite of the BASE INNER GARMENT underneath those cuirasses, facing three-quarter RIGHT with the same compact short torso, pronounced left shoulder visible at left, small far right shoulder, angled oval open neck and curved tight waist. The garment is a plain warm gray-brown LINEN undershirt, short enough to end at belt height, no legs. NO HEAD, NO HANDS, NO ARMS, no armor, no quilt diamonds, no shoulder plates, no metal, no belts, no straps, no collar hardware. Full opaque woven linen over the chest and belly, subtle fabric folds, a simple rolled low neck edge and capped short shoulder fabric. This is a normal garment asset, not a person or mannequin. Continuous cloth is essential: it will show naturally through holes in separate damaged outer armor layers. Keep the strong dark ink edges and hand-painted restrained realistic gouache style of the reference. Even lighting top-left, compact broad shoulders slightly turned to the RIGHT, proportion corresponding to the reference's top-left padded torso. Center the SINGLE garment with clear transparent margins, actual alpha transparency everywhere outside it; no background color, labels, cast shadow, texture sheet, scenery or decorations. Exact same 3/4 perspective as reference.
```
