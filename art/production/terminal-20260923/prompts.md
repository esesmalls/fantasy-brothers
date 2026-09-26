# 终局覆盖层完整生成提示

工具：Codex 内置 `image_gen`。生成日：2026-09-23。两张最终 PNG 保留工具输出的 1254×1254 RGBA 原始像素；没有手工重绘或去背。参考来源为项目 `art/workbench/projects/current.asset.json` 所用的 `game/assets/art/static-bust/body-mild-proof.png`，以及已认可画风的 `art/validation/2026-09-20-h-standard/06-downed.png`、`07-dead.png`；这些参考只用于目视定调，未合成到最终图。`state_down.png` 是以下编辑提示从本批 `state_dead.png` 产生，因此两层阴影相近，且没有借用现有角色像素。

## state_dead.png：采用稿

原始工具文件：`C:/Users/esmalls/.codex/generated_images/01a0ce08-9705-77d3-ba97-d137d4943b37/exec-1557cab1-320a-4727-a43c-fe052d6e68b1.png`

```text
Use case: stylized-concept
Asset type: single transparent ground-contact overlay for CONFIRMED DEAD state of a 2D medieval fantasy tactical game.
Draw ONLY a low flat dark umber contact shadow beneath a separate fallen character sprite, plus one small irregular deep wine-red dried blood seep near the left-center and two tiny restrained flecks. The blood area should be less than 15% of the whole effect width, not a dramatic pool. The whole effect is a flattened oval about 75% of canvas width and 12% of canvas height, centered horizontally near y=70% of a square canvas. Most canvas truly transparent. Keep a hint of rough hand-painted brush edge, warm dark brown and muted burgundy, fine realism with restrained oil/gouache texture matching the H static-bust game art. This signifies only a rule-confirmed final state. No person, face, head, hands, torso, clothing, weapons, detached anatomy, wounds, gore, soil slab, scenery, base, stones, text, border, checkerboard or opaque background. Isolated transparent alpha PNG; seamless to place underneath separately drawn same-identity fallen body.
```

## state_down.png：采用稿

工具编辑目标：本批 `state_dead.png`，仅用于保留相同的影子占地。原始工具文件：`C:/Users/esmalls/.codex/generated_images/01a0ce08-9705-77d3-ba97-d137d4943b37/exec-932d9dc6-5f19-4063-8b28-0603f8e36114.png`

```text
Use case: precise-object-edit
Asset type: transparent ground-contact sprite for a downed but potentially surviving medieval fantasy tactical unit.
Input image 1 is the EDIT TARGET and shadow-footprint reference. Preserve its exact canvas, oval shadow position, flattened scale, overall oil/gouache brush character, soft irregular edge, and genuinely transparent background. Remove ALL red blood and flecks completely. Darken the charcoal-brown contact shadow slightly so that at a 90-pixel whole-sprite display it still reads on both dark olive grass and tan soil. Add only three or four very restrained warm ochre dust scuffs outside the contact patch to indicate recent impact; keep them low and close to the shadow, no upward curling waves. Do not add any ground plane, dirt mound, body, face, person, hands, weapons, clothing, insignia, letters, base, red injury marks, or gore. This state may survive, so no death cue. Preserve alpha and output a single transparent PNG.
```

## state_down 未采用初稿

保存在 `rejected/state_down-v1.png`，没有进入定义片段；于 90 像素预览时影子较淡，尘土形状像地块。完整提示如下：

```text
Use case: stylized-concept
Asset type: single transparent ground-contact overlay for the DOWNED, possibly surviving state of a 2D medieval fantasy tactical game.
Draw ONLY one soft irregular flattened oval contact shadow and a handful of very subtle ochre dust wisps/scrapes. It is a visual effect, not a mound or terrain tile. About 75% width, only 12% canvas height, centered horizontally at y=70% on a square transparent canvas. Semi-transparent charcoal-brown central shade, feathered edges, a few fine hand-painted dust marks that dissolve into true alpha. Keep the vast remainder of the canvas transparent. Restrained refined oil/gouache illustration, warm muted browns, readable at miniature game size. No inner hole/ring. No gravel, soil slab, crater, ground plane, stones, objects, character, face, body, clothing, weapon, base, blood pool, gore, text, border, checkerboard, or baked matte. Explicitly this down state does not imply death. Output genuine alpha PNG.
```
