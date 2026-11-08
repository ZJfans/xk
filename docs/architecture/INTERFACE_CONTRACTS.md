# Frontier 工程接口与模块契约（以代码现状为准）

> 当前阶段 M0/UX V1.0。本文严格区分**已实现**与**M1 目标**。不依赖旧版 V4 的内核、界面或存档。

## 1. 已实现：单向交互通路

```
Screen.tscn  ─── action_requested(id, payload) ───▶ AppShell
     │                                              │
     └──────────── route_requested(screen_id) ───────┤
                                                    ▼
                                      UXSession.apply(id, payload)
                                                    │
                                  {ok, message, route} / Mock 账本
                                                    │
                                                    ▼
                                     Screen.render() / Navigation
```

- 六屏 UI 只能通过 `UXScreen.do()` 请求修改状态，不能直接修改 `session.cash` 或库存。
- `AppShell` 独占页面切换；每个页面场景可通过 `scenes/demos/*_demo.tscn` 单独调试。
- `FrontierContracts` 提供命令归属信息。动作名和字段一旦冻结，必须先评审契约再改 UI。
- `UXSession` 是**仅供交互测试的模拟数据**，不是目标游戏生产模拟或可靠存档实现。

## 2. 当前命令协议

| ID | 参数 | 状态影响（仅 Mock） | 负责人 |
|---|---|---|---|
| `win_lot` | `lot: String, price: int` | 校验单轮仅获一块矿权，演示扣竞拍价 | Auction |
| `scan` | `body: String` | 有矿权后扣 500 Cr，记录扫描天体 | Expedition |
| `deploy` | `body: String` | 对已扫描天体部署，扣 3,200 Cr、一次性生成 80t 演示库存 | Expedition |
| `dispatch` | `body: String` | 对已部署天体运送 80t，扣演示运费 | Aerospace |
| `sell` | `buyer: String` | 港口库存原子扣减并增加现金 | Market |
| `change_craft` | `craft: String` | 切换两种演示火箭方案及匹配尾舱 | Assembly |
| `mount_part` | `slot: String, part: String` | 按零件目录验证类别及火箭类型、替换部件 | Assembly |
| `reset_round` | 无 | 清空本轮数据，保留当前现金及火箭配置 | Progression |

**重要**：本 Mock 只支持本轮对**一颗天体**完成扫描、部署及运输。选择另一颗天体只改变选中状态，不得误显示另一颗已经扫描或部署。

## 3. 数据归属与禁止事项

| 归属 | 现在 | M1 计划 |
|---|---|---|
| 竞拍/矿权 | `UXSession.chosen_lot` | `AuctionService` / `LicenseState` |
| 资源与矿场 | `UXSession.surveyed_body`、`mined_t` | `ExplorationService` / `MiningService` |
| 舰队/蓝图 | `UXSession.craft`、`rocket_parts` | `FleetService` / `RocketBlueprint` |
| 交易/资金 | `UXSession.cash`、`delivered_t`、`revenue` | `CashLedger` / `InventoryLedger` / `MarketService` |
| 战役/回合 | `UXSession` 的本轮重置 | `CampaignState` / `RoundService` |

表现层不允许直接写游戏经济状态。后续任何跨模块资产移动，必须在同一个真实领域事务里操作，不能先动画搬运、再扣库存。

## 4. M1 建议的真实命令结果（尚未实现）

```gdscript
{
    "ok": true,
    "request_id": "uuid-or-monotonic-id",
    "state_revision": 17,
    "message": "80 t 已完成卸货",
    "events": [{"type": "CargoDelivered", "payload": {"tons": 80}}],
    "snapshot": {"cash_cr": 27100, "port_stock_t": 80}
}
```

必须同时满足：
1. `request_id` 重试幂等；同一笔交易不会扣两遍款、产两遍矿。
2. 预览报价只读，确认动作重新验证金额、许可、货物及产能。
3. 现金、库存、运货、竞拍保证金、股权分别有单一权威记录。
4. 保存加载有 schema 版本，正式档放在新工程 `user://frontier/` 下。
5. DomainEvent 只能**通知**视觉和 UI，不能触发第二次经济结算。

## 5. 任务代码所有权

- Integration：`scripts/app/`、`scripts/contracts/`、`scripts/core/`、`scenes/main.tscn`、`project.godot`
- UX：`scripts/ui/`、`assets/ux/`、`docs/ux/`、`tools/generate_wireframes.py`
- HQ/Auction：`scripts/features/hq/`、`scripts/features/auction/`
- Expedition：`scripts/features/expedition/`
- Assembly：`scripts/features/assembly/`
- Market/Settlement：`scripts/features/market/`、`scripts/features/settlement/`
- QA：`scripts/tests/`、`tools/check_project.py`、`docs/production/UX_TEST_SCRIPT.md`

共享目录的变更先由 Integration 审核，避免多个 AI 同时修改主场景和经济协议。建议每个 PR 仅实现一个清晰可测试的玩家行为。
