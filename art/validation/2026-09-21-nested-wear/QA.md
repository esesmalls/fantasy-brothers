# 嵌套穿戴验证

2026-09-21，主AI独立执行，没有子智能体。

| 验证 | 结果 |
| --- | --- |
| 工作台草案／撤销／文件／输入专项 | 61通过 |
| 现有H静态半身与武器回归 | 147通过 |
| 主入口游戏UI回归 | 301通过 |
| 实际Windows工作台输入，1440×960与1180×740 | 29通过 |
| 实际Windows嵌套渲染、坐标与旧草案兼容 | 85通过 |
| 网页7状态切换、完整截图、窄屏及引用 | 21通过 |

Windows导出85项包含60项旧v3几何字段相等检查、底座／裁取、保留用户示例位移(-0.5,-2.3)的旧草案迁移、LF／CRLF两种历史目录摘要、各层损伤相互独立、预览状态不污染候选，以及7张真实离屏渲染与材质采样。采样比较同一件外衣下有／无内层的开口像素，也比较非开口处仍不透明；V领采样放在开口内部，避开自然抗锯齿领边。详见 [渲染报告](render-check/report.json)、[实际输入报告](ui-report.json) 和 [网页报告](browser-report.json)。

程序：`builds/paperdoll/windows/FantasyBrothers-Paperdoll.exe`。Godot 4.7.2 stable ed1daf0bf，OpenGL Compatibility / RTX 4080 Laptop GPU。

导出SHA256：`c49e292bb0d1dda997db3db1e56d21c2806f404f5de2dbf5a1c5f8a625bceed1`。

新目录SHA256：`b411dfd57a4efb9bbf1c866f2d37f8dbfbc351d838431da5403719e1c678123e`。v3归档按Git规定统一LF后：`b5f4c53b71af8c1a95b2c1f1adfe22b373abfb78a2436281f48f76d2e42c9688`；U49本机旧CRLF版为 `862d93ad989f013500b2a28197ad8bba4244e8075b112d68830666ffff16e45d`，两者均兼容。索引输出显式固定LF，避免三台电脑因换行不同生成不同摘要；JSON内容未因换行整理而变化。

`previews/`七张工作台画面和 `render-check/`七张局部都是实际导出渲染，无图片后处理。两次内置imagegen成功，选用两张原始RGBA图集，生成记录见 [prompts.md](prompts.md)，来源／哈希见 [manifest.json](manifest.json)。新图集未使用的基础内衣和亚麻破损区域不冒充新已接入资产。

范围限制：视觉状态可独立选择；战役没有因此增加多层装备槽或独立耐久规则。仍为一体型与配套衣甲，新领型／体型不能据此自动放行。领口厚度和嵌套美观仍需要用户复评。

重现：`tools/build_paperdoll.ps1`；导出后 `--paperdoll-nesting-test --paperdoll-dir=绝对输出目录` 进行渲染检查，`--paperdoll-smoke` 进行实机输入检查，`--paperdoll-capture` 生成窗口截图。索引脚本只读源图并写目录元数据，不修改图片。
