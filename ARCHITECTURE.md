# hisi-riscv-rt 架构

本仓库是 ws63-rs / hisi-riscv-rs monorepo 的 runtime 子模块。

`hisi-riscv-rt` 的外部 Interface 是芯片中立的：`entry` / `pre_init` 来自
`riscv-rt`，中断枚举来自当前 PAC，critical-section 实现由本 crate 统一注册。
复位汇编、链接脚本、镜像头等芯片事实放在 startup adapter 后面；中断符号
`device.x` 由当前 PAC 的 `rt` feature 负责。

## 当前 adapter

- `chip-ws63`：使用 `asm/ws63/startup.S`、`linker/ws63/{memory.x,layout.ld}`，
  `ws63-pac/rt` 提供 `device.x`，可选 `linker/ws63/boot-header.x`。
- `chip-bs21` + `unstable`：BS2X 兼容路径。`linker/bs2x/{memory.x,layout.ld}`
  提供 BS21/BS2X 默认内存图与布局，`bs2x-pac/rt` 提供 `device.x`，本 crate
  暂时复用 legacy M-core startup。BS20/自定义板卡通过关闭 `bundled-memory-x`
  提供自己的 `memory.x` 覆盖默认。
- Hi3322：仅有预研文档，不暴露启动 feature。TES/TEE reset、CLIC、内存分区和镜像格式
  都需要独立 adapter。

## Stable / unstable

稳定 surface 只包括薄 `riscv-rt` facade、WS63 默认启动/链接路径、WS63
`boot-header`。BS2X adapter 和 `riscv-rt-start-experiment` 都要求 `unstable`：
前者缺少 BS2X 板级 HIL，后者还未把默认 reset path 切到 `riscv-rt` `_start`。

## Linker contract

`build.rs` 向下游二进制导出 `hisi-riscv-link.x`，按顺序 `INCLUDE memory.x`、
`layout.ld`、`device.x`、`riscv-rt-symbols.x`，WS63 `boot-header` feature 额外
`INCLUDE boot-header.x`。其中 `device.x` 来自当前 PAC 的 `rt` feature；旧的
`ws63-link.x` 仍生成，但只是兼容别名。

完整架构与评审集中维护在父仓 mdBook：

- `docs/src/explanation/components/05-hisi-riscv-rt.md`
- `docs/src/explanation/components/hi3322-runtime-porting.md`
- `docs/adr/0001-runtime-adapter-seams.md`
