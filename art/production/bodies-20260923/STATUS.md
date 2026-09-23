# 身体 02–04 原图尝试记录

2026-09-23。用户随后明确修改设计为“模糊化身体胸部位置，再尝试制作”。按新要求生成了可用原始透明 PNG：`body_02.png` 深棕、`body_03.png` 浅肤年长、`body_04.png` 暖棕。三张均为平滑中性人偶式胸前，不含乳头、乳晕或胸肌沟线；沿用头身分离的短颈开口及共同胸肩外轮廓。最终源图、完整提示、SHA 与预览另见 `manifest.json`、`qa-report.json`、`qa-preview.png`。这些是供后续规范化和用户精调的原图，未改 foundation 工程或发布版本。

检查：三张均为约 1698×926 RGBA、四角 alpha=0，`qa-preview.png` 实际展示深绿与浅土地色上的 64px/256px 对照。三种基础肤色与短颈胸肩形状可辨，未见头、手、额外物件或整片不透明背景。`body_04` 首稿偏深，已保存在 `rejected/body_04-v1.png`；最终图只做过一次肤色修订，与 `face_04` 基础色接近。此批未完成 Godot 头身叠合、衣甲开口、装备遮挡、动作或最终锚点检查，需由主代理集成与用户精调。导出保留原始 RGBA PNG；规范化、图集和运行配置由 `production_assets` 负责。

旧设计下的首次尝试记录保留如下，以区分阻拦与后来的用户改版成功。

生成前目视检查了 `art/production/foundation-20260923/assets/body_01.png`、`face_02.png`、`face_03.png`、`face_04.png`，并读了 foundation `manifest.json`。既有 `body_01` 为约 647×353 的头身分离、短颈开口、无手静态胸肩组件；面容 02/03/04 分别对应深棕、浅肤年长、暖棕角色。拟按同一胸肩轮廓制作。

首次调用 Codex 内置 `image_gen`：`body_01.png` 为编辑目标，`face_02.png` 仅为肤色参考，请求旧设计的 `body_02`。工具在输出审核阶段返回 `HTTP 400 moderation_blocked`，类别 `sexual`，请求 ID `2ccc4a7c-b042-4620-8722-b241069cd16f`。这是主代理所述先前同类输出阻拦之后的再次拒绝；遵照当时“不规避、持续拒绝则报告”的要求，停止旧设计的生成。此后的成功输出依据用户新提出的平滑低细节设计，所用生成提示均见 manifest。

完整调用提示：

```text
Use case: identity-preserve
Asset type: neutral adult male upper-torso anatomy component for a hand-painted 2D medieval fantasy paperdoll game, body_02.
Input image 1 is the EDIT TARGET for exact anatomy framing and assembly shape: keep its shoulder width, chest crop, shallow side-facing three-quarter view toward viewer's right, short open neck recess, lower curved bust cut, arm stumps ending at the current cropped edge, and light direction. Input image 2 is a supporting skin-tone reference only for face_02. Transform the torso to a deep warm-brown skin tone matching face_02, with modest natural skin texture, slightly leaner pectoral definition and collarbones while retaining the same broad silhouette. This is a nonsexual game anatomy/armor-fit asset. Render as a single neckless, headless, handless bust component, without clothing, jewelry, props, text or scenic ground. Match the existing refined H static-bust oil/gouache painterly realism. Preserve true transparent alpha outside the body, including the neck opening; no black matte. Do not add a face, head, neck column, hands, forearms, extra anatomy, or alter shoulder span. Full component in frame.
```
