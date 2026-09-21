# H · 静态半身穿戴样板

2026-09-20 / U46。主AI独立完成，无子智能体。当前是用户待评审样板，不是全游戏换装完成。

打开 [index.html](index.html) 看实际Windows导出帧；双击仓库根目录 `Review-Static-Bust.cmd` 进行完整交互。界面可检查裸身／内衬／两甲、三武器、甲损、脸伤、分层、三底色、命中／格挡／落空、暂停、慢速和逐帧拖动。音效默认关闭，可开启节奏示意。

本机包：`builds/static-bust/windows/FantasyBrothers-StaticBust.exe`。其他电脑使用 `tools/build_static_bust_review.ps1` 重建，工具准备沿用项目README。构建包不提交Git；源码、原图、提示、锚点和真实截图一起同步现有动作分支。

## 文件与来源

| 文件 | 用途 |
| --- | --- |
| sources/00-master.png | H新构图母版，供对照，不直接装入游戏 |
| sources/01-anatomy.png | 早期拆件；当前只使用其中的亚麻和底座 |
| sources/02-armor-draft.png | 未采用的边缘过紧稿 |
| sources/02-armor.png | 选用两甲、两耐久状态 |
| sources/03-weapons.png | 选用剑、枪、弓、盾、箭和命中效果 |
| sources/04-body-head.png | 过渡稿；头部仍有颈部截线，未采用 |
| sources/04b-body-head.png | 选用独立正常／伤势头及裸肩胸身体 |
| previews/ | 最终Windows独立包实际渲染，不是概念图拼贴 |
| manifest.json、metadata.json | 原图哈希、工具、尺寸／alpha和图集索引 |
| render-invariance.json | 三种动作的脸／底座固定区域像素对比 |
| prompts.md | 七次内置imagegen完整提示词 |

所有原图来自Codex内置imagegen，成功7次，未调用外部CLI/API。选用4张运行图集、15个独立绘制部件；运行文件原样复制，图集索引不重画像素。H旧母版用于画风与身份，用户所给Battle Brothers设定集截图用于头身分离、短胸和底座关系研究，没有把设定集中的部件裁出放进游戏。

原PNG无损保留，运行导入生成mipmap并修正透明边采样。PNGalpha检查不能独自证明视觉合格，结合实际浅底／深底和装配图检查。链甲的衬边及破口内衬是这套固定配套原画，不冒充任意颜色内衬可替换。

[生产方向与后续边界](../../../docs/24-static-bust-standard.md) · [验证记录](QA.md)
