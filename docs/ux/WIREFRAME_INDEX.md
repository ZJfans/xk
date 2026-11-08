# 六大核心界面：可编辑线框图与对应文件

所有画稿采用 **1440×900** 逻辑画布、SVG 矢量格式，可用 Figma、Inkscape 等编辑；PNG 放在 `assets/ux/previews/`，供快速浏览、任务截图和评审。

| 编号 | 画稿 | 实现入口 | 主要鼠标动作 |
|---|---|---|---|
| U01 | `assets/ux/wireframes/01_总部.svg` | `features/hq/presentation/hq_screen.gd` | 点击竞拍入口 |
| U02 | `02_矿区竞拍.svg` | `features/auction/presentation/auction_screen.gd` | 选择地块、确认模拟竞拍 |
| U03 | `03_太空采矿.svg` | `features/expedition/presentation/expedition_screen.gd` | 点击天体、拖动探测器 |
| U04 | `04_火箭装配.svg` | `features/assembly/presentation/assembly_screen.gd` | 从仓库拖动部件至同类插槽 |
| U05 | `05_市场交易.svg` | `features/market/presentation/market_screen.gd` | 比价、确认出售 |
| U06 | `06_本轮结算.svg` | `features/settlement/presentation/settlement_screen.gd` | 查看经营结果、返回总部 |

## 说明
- SVG 是经过设计的 UX 线框图；不是游戏的商业级最终美术。
- 画稿与 Godot 原型的空间结构一致，具体位置和像素尺寸并不严格一一对应。
- 所有示例金额均为**演示**，没有进入已确认的正式平衡数值。
- 原型中的导航在测试期全部开放；正式战役应随流程适度限制。
- 再生成：运行项目根目录 `tools/generate_wireframes.py`（需要 `cairosvg`）。
