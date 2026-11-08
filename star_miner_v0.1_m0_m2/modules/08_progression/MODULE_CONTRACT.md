# 08 进度与终局 (Progression, Events & Endgame) — 模块边界与 AI 协作契约

## 1. 模块职责
负责一小时四阶段渐进式目标引导、特殊遗迹单次兑现保护、负面事件提前预告期以及三大终局路线（商业霸主/深空先驱/星际工业巨头）。

## 2. 目录结构规范
- `domain/`：纯业务逻辑、规则计算与只读查询服务（严禁引用 Control/Node2D 等 UI 节点）
- `presentation/`：专属界面、HUD 面板与独立可启动场景（只读状态，操作通过 `GameKernel.dispatch` 发送命令）
- `effects/`：专属粒子、Shader 与声光反馈演出（仅响应 `GameKernel.visual_effect_requested` 事件）
- `tests/`：本模块独立的 Headless 单元测试

## 3. 关联现有核心脚本
- `campaign.gd`
- `event_system.gd`
