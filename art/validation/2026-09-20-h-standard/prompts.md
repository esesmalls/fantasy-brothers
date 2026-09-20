# H 标准修订生成记录

2026-09-20。使用内置 image_gen，未使用CLI/API或外购服务。6次调用均返回图像，选用3张。经PIL像素与浏览器浅底复核，三张最终图和07所有尝试均已有真实透明alpha。生成工具预览显示了隐藏RGB底色，主代理误判为不透明，造成第三次多余提取；此处保留真实尝试记录，不写成工具拒绝或背景清理失败。

输入：第二轮H04/H06保留比例和姿态，E04/G04仅参考少量材质；E07为用户明确认可的死亡图。所有输入来源均在项目内，第三方设定集仅间接作前轮造型研究，不作游戏资产。

## 04 · 采用

当前修订样板。

Use case: identity-preserve. Asset type: Fantasy Brothers approved standard H v1, 04 armed standing half-body game sprite. Edit target is image 1 (H04). Image 2 (E04) and image 3 (G04) are supporting references only for a VERY SMALL amount of naturalistic skin, worn materials and hand-painted oil/gouache texture. Keep H04 unmistakably dominant: exactly the same middle-aged receding brown-haired greying-bearded man, asymmetrical stern face, dark charcoal gambeson and chainmail, leather edging, two-handed steel sword, both complete hands held above the waist, short compact torso, precise low metal oval base hugging the waist with no exposed flat platter or gap. Preserve H04 pose, head-to-body ratio, silhouette, orientation, sword direction, composition, and bold readable drawn edges. Only subtly enrich face, cloth and steel with controlled natural brushwork and selective wear; do not redesign clothing, add emblems, change the face, elongate torso, lower hands, expand the base, or smooth into a 3D render. Neutral diffuse painted lighting. One single character, centered, entire sword and base in frame with comfortable safe margin. Genuine transparent background, no gray rectangle, no scenery, no lettering, no watermark. This is a restrained refinement of H, not a new style proposal.

原始工具输出：`C:\Users\esmalls\.codex\generated_images\01a0bc98-dd48-7343-8575-b7b4007cc4df\exec-3071807b-5669-46dc-9cac-423c2b708573.png`

## 06 · 采用

当前修订样板。

Use case: precise-object-edit. Asset type: Fantasy Brothers standard H v1, 06 downed but fate not yet determined, a compact half-body tactical game sprite. Image 1 is the H06 edit target: preserve its same convincing limp forward/side collapsed pose, head touching ground independently with no arm used as pillow, both complete relaxed hands lying apart, and sword released on ground. Image 2 is the new approved-direction H armed master for exact face, dark quilted gambeson, chainmail, proportions, and restrained painted finish. Critical correction: REMOVE THE ENTIRE RIGID OVAL METAL DISPLAY BASE AND EVERY PART OF ITS REAR UPRIGHT RIM from the back/top of the collapsed torso. There is absolutely no plinth, pedestal, disc, oval tray, rigid base rim, detached base, stone or platform anywhere in the image. Repaint that rear silhouette as the natural foreshortened soft fabric/chainmail hem of the half-body game token receding against the ground. The waist ends discreetly behind the torso, not as a sliced anatomical opening. Keep the same half-body game abstraction, do not add legs. Keep intact head attached to neck, same man and both hands, visible but nonfatal-looking facial injury and modest damaged chainmail; this is loss of ability to fight, not confirmed death. No supported push-up, no resting/sleep pose. Keep the H drawn contours dominant, with only subtle E/G-like natural material brush texture matching image 2. Genuine transparent background and only a very tight soft contact shadow, no opaque gray backdrop or floor plane. Single character and same sword, entire outline and sword tip comfortably inside canvas. No text.

原始工具输出：`C:\Users\esmalls\.codex\generated_images\01a0bc98-dd48-7343-8575-b7b4007cc4df\exec-9aa0fddd-58a9-4eb3-b525-e192d1d1e919.png`

## 07-a · 未采用

H衣甲/死亡表现初稿；已有透明alpha，尚留E式剑首。

Use case: style-transfer / identity-preserve. Asset type: Fantasy Brothers H standard v1, 07 confirmed-death state, single painted tactical-game half-body sprite. Image 1 (existing E07) is the supplied edit target: preserve its existing collapsed casualty composition and the existing head/body separation and wound treatment, without increasing graphic detail or severity. The user approved this exact E07 depiction. Images 2 and 3 are the H character identity, equipment and restrained painted-style references. Transform only the character identity, equipment and rendering into this SAME H man: receding brown hair with grey temples, short greying beard, broad weathered asymmetrical face; dark charcoal quilted gambeson under steel chainmail with brown leather edge binding, and his straight two-handed steel sword. The E red brigandine, yellow sleeves and emblem should become H's exact chainmail and charcoal cloth, not an alternate costume. Retain both complete relaxed hands and the sword lying released beside him. Keep convincing limp collapse and recognizable actual character, not empty armor or arranged modular clothing pieces. No sleeping pose or push-up pose. H's bold detailed 2D drawn silhouette remains dominant, only light naturalistic painted textures as image 2. Absolutely no base, oval disc, metal base rim, pedestal, platform or detached plinth anywhere, even behind the torso. Keep the half-body game abstraction and discreet garment hem receding behind the torso, no legs. Transparent background with only tight contact shadow. All parts comfortably inside the frame. No text, no additional characters, no scenery.

原始工具输出：`C:\Users\esmalls\.codex\generated_images\01a0bc98-dd48-7343-8575-b7b4007cc4df\exec-7d465c58-03fe-4507-be05-75858ed00ec6.png`

## 07-b · 未采用

改为H式圆形剑首；真实透明alpha已复核。独立QA发现E式面容/束带/剑形残留，此稿不作为最终图。

Use case: background-extraction / precise-object-edit. Image 1 is the exact existing finished H game casualty sprite to edit; image 2 is its standing equipment reference. Keep ALL of image 1's character, existing pose, facial identity, hand anatomy, head/body arrangement, clothing, existing injury depiction and painted H contours unchanged. Do not increase injury detail or severity. Two small production corrections only: (1) Fully remove the brown and black vignette background and ground rectangle; return a real transparent alpha background right up to the character, sword and tight contact shadow, with no vignette or opaque floor. Preserve delicate hair, chainmail edges and all existing subject pixels wherever possible. (2) Make the sword pommel the plain circular steel disk with a simple central round boss from image 2, replacing its decorative diamond/star engraving. Keep the sword shape, natural placement, blade and grip otherwise unchanged. This is an existing image cleanup, not a new scene. Never add a base, pedestal, platform, legs, text or extra objects.

原始工具输出：`C:\Users\esmalls\.codex\generated_images\01a0bc98-dd48-7343-8575-b7b4007cc4df\exec-5a790673-6828-4d7d-9b26-773ab6b0e7a1.png`

## 07-c · 未采用

主代理根据工具预览错误判断透明效果而进行了多余提取；此图也有alpha，但面容与细节进一步漂移，不采用。

Remove the background from this supplied existing image. This is a background extraction task ONLY. Return a cutout PNG with TRUE TRANSPARENT ALPHA outside the already-painted character and sword. The entire brown gradient, tan glow, dark black vignette and continuous floor MUST disappear, including the open area between the hand and sword and the blank corners. Preserve the original character, existing appearance and all subject details without alteration. Do not repaint the injuries or add any detail. Do not add any objects or pedestal. No colored background, no checkerboard baked into the image, no solid black/white fill. Transparent isolated game sprite.

原始工具输出：`C:\Users\esmalls\.codex\generated_images\01a0bc98-dd48-7343-8575-b7b4007cc4df\exec-a88c7ab4-d761-4582-8cd8-7cd1a8d616ea.png`

最终文件见本目录04-armed.png、06-downed.png、07-dead.png。未采用输出保留于生成工具目录；本仓库只交接所选原始PNG及记录。


## 07-d · 采用

依据独立QA从H06重新派生，锁H脸型与原配装，去除E式扣带及剑形漂移。

Use case: identity-preserve. Asset type: Fantasy Brothers H standard 07, confirmed-death variant. IMAGE 1 is the PRIMARY EDIT TARGET, the already finished H06 collapsed character. IMAGE 2 is H04, exact identity and equipment reference. IMAGE 3 is the previous death treatment reference only, NOT an identity, clothing, weapon or body-proportion reference. Create the confirmed-death variant of IMAGE 1. Preserve IMAGE 1's exact man, receding brown hair with swept wisps and grey temples, broad forehead, heavy asymmetrical brows, long angular nose, short greying beard and relatively compact head. Preserve its exact chainmail draped mantle over charcoal padded gambeson, simple brown leather edging, no added harness straps or extra chest belt buckles, both existing complete hands in their same positions, torso size, arm positions and foreshortening. Preserve the EXACT same grounded sword of image 1: straight blade, straight crossguard with rounded terminal, simple flat round pommel and wrapped grip. The ONLY narrative change from image 1 is confirmed death using the same head-separation treatment and existing injury intensity from image 3, without any increased graphic detail: head now relaxed with closed eyes, detached and lying separately a short distance beside the right shoulder; torso limp against ground. It must clearly be the SAME H man and gear, not the E character redressed as H. Do not copy image 3's face, high fluffy hairstyle, pointy full beard, sleeve seams, harness buckles or sword. H outline and lightly painted textures as images1/2. Keep exactly the compact half-body abstraction, no legs and absolutely no pedestal, ring, disc or base. Genuine transparent alpha background, only small contact shadow. Single sprite, whole head, hands, torso and sword inside square canvas, no text.

原始工具输出：`C:\Users\esmalls\.codex\generated_images\01a0bc98-dd48-7343-8575-b7b4007cc4df\exec-d12218dd-94c2-4dcd-93d9-1fe33298763f.png`
