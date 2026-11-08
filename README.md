# 《星矿大亨》Rocket Prospectors — Frontier UX V1.0 项目底座

> **交付内容**：Godot 4 可独立打开的六屏交互原型 + 六张可编辑 UX 线框图 + 完整 GDD V1.0 + 多 AI 开发架构与任务规范。  
> **当前阶段**：Pre-production / UX V1.0；**不是完整可发布经营游戏**。  
> **代码边界**：这是独立新项目，不依赖旧版 V4 游戏代码或素材；不覆盖用户旧仓库、旧存档。旧版已经备份，过时的长线架构文档不随新项目交付。  
> **技术**：Godot 4.2+ / GDScript，GL Compatibility，无需外部美术资产或插件。

## 1. 立即开始

1. 解压本 ZIP，使用 Godot 4.2+ 项目管理器“导入”，选择 `project.godot`。
2. 按 **F5** 启动 `scenes/main.tscn`，在上方切换六大界面，或按建议路线完成一次模拟经营。
3. 按 **F6** 可以单独运行 `scenes/demos/expedition_demo.tscn`、`scenes/demos/assembly_demo.tscn` 等六个页面 Demo。
4. 打开 `assets/ux/wireframes/` 查看 SVG 线框图；`assets/ux/previews/` 有对应 PNG。
5. 设计与任务文档从 `docs/ux/UX_V1.0.md` 与 `docs/production/TASK_BOARD.md` 开始阅读。

可选命令行测试（需要本地安装 Godot，且可在终端调用）：

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/tests/test_ux_flow.gd
```

**验证声明**：此包在生成环境中已进行文件依赖、SVG 生成、资产打包等静态检查，但该环境**没有 Godot 可执行程序**，因此**未完成 Godot Parser/运行时/分辨率实测**。首次用 Godot 打开后以实际报错为准，修正后再把它作为下一阶段的稳定基线。

## 2. 六大界面

| 页面 | 操作 | 可编辑图 | 独立 Demo |
|---|---|---|---|
| 总部 | 主 CTA 进入竞拍、次级装配入口 | `01_总部.svg` | `hq_demo.tscn` |
| 矿区竞拍 | 选地、查看价格、模拟获得经营权 | `02_矿区竞拍.svg` | `auction_demo.tscn` |
| 太空采矿 | 点击天体、拖动探测器、部署、运输 | `03_太空采矿.svg` | `expedition_demo.tscn` |
| 火箭装配 | 拖拽组件至同类插槽、切换火箭类型 | `04_火箭装配.svg` | `assembly_demo.tscn` |
| 市场交易 | 比较两家报价、卖出港口矿石 | `05_市场交易.svg` | `market_demo.tscn` |
| 本轮结算 | 查看收入、成本、利润、进入下一轮 | `06_本轮结算.svg` | `settlement_demo.tscn` |

入口场景在 `scenes/screens/`，全部交互逻辑在对应 `scripts/features/<screen>/presentation/`，集成层仅在 `scripts/app/`。

## 3. 推荐的首次完整操作

总部点击**开始矿区竞拍** → 选择 F-01 → 确认 → 在太空采矿画布**拖动左下角探测器发射坞到 A-03**（或点击扫描按钮）→ 部署采矿舱 → 发射运输火箭 → 在市场选择赤曜工业联盟出售 → 查看结算 → 返回总部。

若选择初始可回收火箭与 240 Cr/t 买家，示例 Mock 账本：开始 40,000 Cr、竞拍 7,600、扫描 500、部署 3,200、运输 800、售出 80t × 240＝19,200，演示现金结果为 **47,100 Cr**、本轮 Mock 净利润 **7,100 Cr**。这些数值是为验证交互与账本转移而固定的演示数据，**不是正式游戏经济设计**。

## 4. 项目文档优先级

1. **当前产品规则**：`docs/gdd/Rocket_Prospectors_GDD_V1.0.md`。
2. **当前交互规则**：`docs/ux/UX_V1.0.md`（包含六屏画像、状态与鼠标交互）。
3. **当前工程契约**：`docs/architecture/ARCHITECTURE_V1.0.md`。
4. **AI 协作规则**：根目录 `AGENTS.md`，任务板 `docs/production/TASK_BOARD.md`。
5. **代码接口与后续实现**：`docs/architecture/INTERFACE_CONTRACTS.md`（现有 Mock 与未来真实规则接口）。

## 5. 下一步怎么继续

先在 Godot 里实际启动，解决任何编译或布局问题，安排小规模无引导试玩，完成 M0.5 UX 验收。之后，才进入 M1“真实竞拍 → 勘探 → 采矿 → 运输 → 市场 → 结算”的经济闭环，并让 `FrontierCommandService` 取代 `UXSession` 的演示账本。

当前交付已经是一个独立工程；后续的真实经营规则应直接在新项目的领域模块中实现。需要复用旧算法时，可从已备份的旧仓库**有选择地移植并测试**，不要整包覆盖或恢复旧 UI。

## 6. 原创与许可

界面 SVG、原型 GDScript 和本文档为本项目的原创工作稿；没有附带《石油大亨》或其他商业游戏的版权素材。旧 V4 代码和过时文件**未纳入本包**。

## 7. 已清理的旧内容

- 删除了不再适用的 `docs/archive/` 长线集团架构归档。
- 删除了旧版 Codex 任务交接及“把新工程直接并回 V4”迁移说明。
- 不包含历史 Stage1–5 补丁、V4 主界面、长期经济模型、旧素材与旧存档。
- 保留**现行新游戏**的 GDD、待决策台账、六屏 UX、Godot 交互原型、架构契约、测试与开发计划。

不要因为旧版已经备份，就把当前项目的 GDD 或六屏设计删掉——它们是后续 AI 协作的唯一需求基线。

### 静态检查

无需安装 Godot 即可运行 `python tools/check_project.py`，检查资源引用、六屏场景、模块划分和文档结构。**此项不能代替 Godot 引擎解析和人工交互测试**。
