# 05 合同与商业 (Contracts & Commercial Projects) — 模块边界与 AI 协作契约

## 1. 模块职责
负责 10% 保证金供货合同、保守交付可行性预测、违约 30 日发行方冷却、单步精炼（合金锭/高纯晶片）与星港 3 期扩建。

## 2. 目录结构规范
- `domain/`：纯业务逻辑、规则计算与只读查询服务（严禁引用 Control/Node2D 等 UI 节点）
- `presentation/`：专属界面、HUD 面板与独立可启动场景（只读状态，操作通过 `GameKernel.dispatch` 发送命令）
- `effects/`：专属粒子、Shader 与声光反馈演出（仅响应 `GameKernel.visual_effect_requested` 事件）
- `tests/`：本模块独立的 Headless 单元测试

## 3. 关联现有核心脚本
- `v40_corporate_renderer.gd`
