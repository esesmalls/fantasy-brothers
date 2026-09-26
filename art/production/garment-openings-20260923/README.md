# 衣甲领腔透明编辑（2026-09-23）

这批源图来自 `../foundation-20260923/assets/`，参考了同批 `garment-contact.png`。目标是让领口及确实穿透的前开口露出实际装配的内层，遵循 `docs/26-nested-wear-standard.md`。原图未修改。

## 产物与查看

| ID | 原稿规格 | 状态 |
| --- | --- | --- |
| `padded_02` | 655×736 | `assets/padded_02.png` |
| `padded_03` | 671×736 | `assets/padded_03.png` |
| `padded_04` | 656×736 | `assets/padded_04.png` |
| `outer_02` | 654×736 | `assets/outer_02.png` |
| `outer_04` | 660×736 | `assets/outer_04.png`；第三次内置编辑成功 |

查看 `layer-preview.png`：五件导出分别在约 192 与 128 像素高度下覆于 `../foundation-20260923/assets/linen_02.png`。预览是按同一画布顶端与水平中心叠放的诊断图，并非工作台正式锚点验收。真实领腔 alpha 已清零，领沿保留厚度。前四件正常图的下半身 alpha 轮廓与任务开始时原件的 IoU 分别约为 0.907、0.950、0.934、0.944；生成式编辑会改变局部轮廓、纹理和锚点观感，生产接入须复核，不能称为像素级原样保持。前襟开口在缩小图中可辨认。套层最终验收仍需工作台与实际导出包。

`sources/*-imagegen.png` 是可维护的高分辨率生成母稿；`normalize.py` 仅把整张 RGBA 母稿用预乘 alpha 的 Lanczos 缩回原资产画布，无颜色抠图、遮罩造洞、手绘补边或内容合成。运行 `python normalize.py` 可重导现有成品。生成工具为 Codex 内置 `image_gen` 编辑模式，逐件以自身原稿为编辑目标；没有外购素材、CLI/API 生成或独立授权方。源图与导出 PNG 的来源链为 `../foundation-20260923/assets/<ID>.png` → `sources/<ID>-imagegen.png` → `assets/<ID>.png`。见 `prompts.md` 保存完整原始提示。

## 验证与限制

- 以 Pillow 读取源与导出 RGBA。原件五件中心领腔采样点 alpha 均为 251–253；导出五件的上部领腔范围（y=25–129，x=画宽 30%–70%）各有 7,777、8,793、8,743、13,964、11,732 个 alpha<32 像素。原图与导出图不覆盖彼此。
- 手动目视检查原尺寸五件衣甲、`layer-preview.png` 的 192/128 像素情况。颜色、轮廓、接缝和包边总体可辨，但生成式编辑有局部重绘差异；尤其 `padded_02` 外形差异最大。
- 此处没有正式角色头身与全部内衣选择的工作台定位、动画方向、装备叠层、加速/跳过或 Windows 导出包验证。生产负责人接入时需完成这些场景；本任务只负责指定领腔源图。
- `outer_04` 的前两次内置生成请求分别报错：`image generation failed: connection failed: error sending request`、`image generation failed: network error: error sending request for url (https://chatgpt.com/backend-api/codex/images/edits)`；第三次使用简化提示成功编辑自身原稿。它不是从其他图伪造的缺件。
