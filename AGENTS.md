# AGENTS.md — Rocket Prospectors Frontier UX V1.0

**所有 AI 开发之前必读**：`README.md` → `docs/gdd/Rocket_Prospectors_GDD_V1.0.md`（产品）→ `docs/ux/UX_V1.0.md`（交互）→ `docs/architecture/ARCHITECTURE_V1.0.md`（架构）→ `docs/production/TASK_BOARD.md`（本阶段任务）。

## 本轮目标，不许扩大
- 先让六屏 UX 交互原型在本地 Godot 中正确运行、无遮挡，并通过真实玩家可理解性测试。
- **不要**在 UX 阶段加入长期经营、多人、真实轨道计算、20 科技树、完整 AI 财团经济模拟或 3A 级视觉资源。
- 真实经营规则以 GDD 为依据；`scripts/core/ux_session.gd` 中的所有数值是 UX Mock，严禁当作平衡数据。
- 不得改写、覆盖旧仓库 `ZJfans/xk` 的 `main` 或 V4 存档。

## 修改权归属
- **Integration AI（唯一可改 Shell）**：`scripts/app/**`, `scripts/contracts/**`, `scripts/core/**`, `scenes/main.tscn`, `project.godot`。
- **UX / Design System AI**：`scripts/ui/**`, `assets/ux/**`, `docs/ux/**`, `tools/generate_wireframes.py`。
- **Auction / HQ AI**：`scripts/features/hq/**`, `scripts/features/auction/**` 和相关 `scenes/screens/**` / `scenes/demos/**`。
- **Mining / Galaxy AI**：`scripts/features/expedition/**` 和相关场景。
- **Rocket AI**：`scripts/features/assembly/**` 和相关场景。
- **Market / Settlement AI**：`scripts/features/market/**`, `scripts/features/settlement/**` 和相关场景。
- **QA AI**：`scripts/tests/**`, `docs/production/UX_TEST_SCRIPT.md`；没有契约评审不得更改演示账本。

## 事件与数据边界
1. 页面只发 `action_requested` 或 `route_requested`，不能直接改 `session.cash`、`session.mined_t` 或 `session.sold_t`。
2. 合同命令 ID 由 `scripts/contracts/frontier_contracts.gd` 统一定义；需要新命令先提交契约 PR。
3. 现阶段 `UXSession` 唯一修改 Mock 的地方；正式阶段改为 `FrontierCommandService` 与领域服务。
4. 动画只观察操作结果；不能多次触发交易/扣款。
5. 为每个新按钮补充正常、资金不足、非法状态和重复点击测试。

## PR、测试和分支
- 分支 `feat/ux-<screen>-<task>`；禁止直接推 main 或强制推送。
- 尽量只改一屏的可验证行为，提交前列出文件和截图。
- 先跑 `godot --headless --path . --editor --quit`，再跑 `godot --headless --path . --script res://scripts/tests/test_ux_flow.gd`。**没运行就注明“未运行”。**
- 单屏通过 `scenes/demos/<screen>_demo.tscn` 打开，六屏联动通过 `scenes/main.tscn` 打开。
- 分辨率至少测试 1280×720 与 1920×1080；UI 不允许遮挡主 CTA。
- 动效要考虑“减少动态效果”及可跳过；美术与音效不得擅自使用第三方版权资产。

## 输出格式

```text
目标及关联 UX 编号：
修改文件：
新增/修改 command IDs：
可观察的玩家操作和结果：
测试命令与结果：
场景 Demo 截图：
设计/性能/可访问性风险：
待集成者操作：
```
