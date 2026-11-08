# 01 星系与探索 (Galaxy & Exploration) — 模块边界与 AI 协作契约

## 1. 模块职责
负责五大星团生成、星球属性、三级勘探信息（遥感/轨道详勘/地面扫描）、10日发现者排他期与采矿权许可/竞拍。

## 2. 目录结构规范
- `domain/`：纯业务逻辑、规则计算与只读查询服务（严禁引用 Control/Node2D 等 UI 节点）
- `presentation/`：专属界面、HUD 面板与独立可启动场景（只读状态，操作通过 `GameKernel.dispatch` 发送命令）
- `effects/`：专属粒子、Shader 与声光反馈演出（仅响应 `GameKernel.visual_effect_requested` 事件）
- `tests/`：本模块独立的 Headless 单元测试

## 3. 关联现有核心脚本
- `v40_galaxy_map.gd`
- `auction_hall.gd`
