# 06 科研与科技 (Research & Tech Tree) — 模块边界与 AI 协作契约

## 1. 模块职责
负责 E/M/L/C 四大分支 20 项研究节点 DAG、研究港矿物样本交付校验与唯一研究槽位暂停/恢复。

## 2. 目录结构规范
- `domain/`：纯业务逻辑、规则计算与只读查询服务（严禁引用 Control/Node2D 等 UI 节点）
- `presentation/`：专属界面、HUD 面板与独立可启动场景（只读状态，操作通过 `GameKernel.dispatch` 发送命令）
- `effects/`：专属粒子、Shader 与声光反馈演出（仅响应 `GameKernel.visual_effect_requested` 事件）
- `tests/`：本模块独立的 Headless 单元测试

## 3. 关联现有核心脚本
- `tech_tree.gd`
