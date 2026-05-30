# ws63-rt 架构

本仓库是 [ws63-rs](https://github.com/sanchuanhehe/ws63-rs) monorepo 的子模块。

`ws63-rt` 是 WS63 的运行时：复位/trap 向量（`asm/startup.S`）、BSS/data 重定位、PMP 配置、
链接脚本（`memory.x`/`layout.ld`/`device.x`），基于 `riscv-rt`。它也为整机注册单 hart 的
critical-section 实现（`riscv/critical-section-single-hart`）。

完整架构与评审（集中维护于主仓库）：
- 组件文档：<https://github.com/sanchuanhehe/ws63-rs/blob/main/docs/architecture/ws63-rt.md>
- 总体架构：<https://github.com/sanchuanhehe/ws63-rs/blob/main/docs/architecture/overview.md>
- 整改排期：<https://github.com/sanchuanhehe/ws63-rs/blob/main/ROADMAP.md>

> 已知问题：链接脚本目前不会传播到下游二进制（导致示例链接失败），中断向量配置与 mtvec 模式不一致。
> 见 ROADMAP 阶段 1。
