# UX V1.0 交付清单与接手说明

**项目**：Rocket Prospectors / 《星矿大亨》  
**交付阶段**：M0 · 核心交互与六大界面设计 UX V1.0  
**项目类型**：Godot 4.2+ 独立原型（非正式游戏）

## 交付资产

| 类别 | 文件 / 路径 | 用途 |
|---|---|---|
| 产品规则 | `docs/gdd/Rocket_Prospectors_GDD_V1.0.md` | 当前短局经营策划基准（非旧 V4 长线版） |
| 待验证决策 | `docs/gdd/DECISION_REGISTER.csv` | 避免未经验证的数值和规则成为定稿 |
| 交互 UX | `docs/ux/UX_V1.0.md` | 六大页面的信息架构、鼠标动作和异常态 |
| 六屏展示 | `assets/ux/UX_SIX_SCREENS_OVERVIEW.png` | 六页面设计总览 |
| 可编辑线框 | `assets/ux/wireframes/01_总部.svg` ～ `06_本轮结算.svg` | 各页面 1440×900 线框 SVG |
| PNG 预览 | `assets/ux/previews/` | 六张设计截图，便于反馈 |
| Godot 项目 | `project.godot`, `scenes/main.tscn` | 六屏联动交互原型入口 |
| 独立测试场景 | `scenes/demos/` | 6 个开发用独立测试场景 |
| 协作规范 | `AGENTS.md` | 每个 AI 的代码所有权、PR 纪律 |
| 架构 | `docs/architecture/ARCHITECTURE_V1.0.md` | 新项目分层和依赖方向 |
| 接口规范 | `docs/architecture/INTERFACE_CONTRACTS.md` | 目前 Mock 的动作契约以及未来真实领域接口 |
| 任务与测试 | `docs/production/TASK_BOARD.md`、`UX_TEST_SCRIPT.md` | M0.5～M1 工作与人工 UX 验收 |
| 自动检查 | `tools/check_project.py` | 资源引用和结构检查；不代替引擎测试 |
| 可复现打包 | `tools/build_release.py` | 重建不包含历史归档的整包 ZIP |

## 已移除/未带入

- 过期的 `docs/archive/` 长线集团架构和旧版跨项目迁移计划。
- 旧 `CODEX_HANDOFF_ORIGINAL.md`（针对旧 V4 工程的说明）。
- 旧 V4 的场景、脚本、资源与 Stage1–5 增量补丁。
- 不会对用户原 GitHub 仓库执行删除、覆盖或强制推送。

## 验证结论

- 静态检查：目前 `tools/check_project.py` 完成 99 项检查，0 项失败。
- ZIP：由 `tools/build_release.py` 对源文件与归档清单进行一一比对，并验证 CRC。
- **未执行** Godot 解析、headless 自动化、窗口尺寸实测或人工试玩；这是下一里程碑 M0.5 的必需工作。
- 界面 UI 上的报价与火箭性能是 **Mock 数据**，不能据此判断游戏经济平衡完成。

## Codex 接手第一条任务（不许扩大范围）

1. 打开 `AGENTS.md` 和 `docs/ux/UX_V1.0.md`。
2. 以 Godot 4.2+ 导入 `project.godot`；运行主场景和 6 个 Demo。
3. 执行 `godot --headless --path . --editor --quit` 和 `godot --headless --path . --script res://scripts/tests/test_ux_flow.gd`，记录真实结果。
4. 解决 ParserError、缺失字体和两个指定分辨率下的遮挡，不改游戏经济规则。
5. 提交一份附场景截图和 UX 验收记录的 PR；通过后再进入 M1。
