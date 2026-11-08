# 03 航天与物流 (Aerospace & Fleet Logistics) — 模块边界与 AI 协作契约

## 1. 模块职责
负责三类运矿船（隼式/游隼/巨鲸）、真实阶段状态机、节点边界安全改派、共享船池四级优先级、助推器检修与发射窗口气象。

## 2. 目录结构规范
- `domain/`：纯业务逻辑、规则计算与只读查询服务（严禁引用 Control/Node2D 等 UI 节点）
- `presentation/`：专属界面、HUD 面板与独立可启动场景（只读状态，操作通过 `GameKernel.dispatch` 发送命令）
- `effects/`：专属粒子、Shader 与声光反馈演出（仅响应 `GameKernel.visual_effect_requested` 事件）
- `tests/`：本模块独立的 Headless 单元测试

## 3. 关联现有核心脚本
- `launch_recovery_view.gd`
- `launch_cinematic.gd`
