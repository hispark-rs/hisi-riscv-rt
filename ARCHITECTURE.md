# hisi-riscv-rt 架构

本仓库是 ws63-rs / hisi-riscv-rs monorepo 的 runtime 子模块。

`hisi-riscv-rt` 的外部 Interface 是芯片中立的：`entry` / `pre_init` 来自
`riscv-rt`，中断枚举来自当前 PAC，critical-section 实现由本 crate 统一注册。
复位汇编、链接脚本、镜像头等芯片事实放在 startup adapter 后面；中断符号
`device.x` 由当前 PAC 的 `rt` feature 负责。

## 当前 adapter

- `chip-ws63`：使用 `asm/ws63/startup.S`、`linker/ws63/{memory.x,layout.ld}`，
  `ws63-pac/rt` 提供 `device.x`，可选 `linker/ws63/boot-header.x`。
- `chip-bs21`：BS2X 兼容路径。示例自带 BS20/BS21 `memory.x`，`bs2x-pac/rt` 提供
  `device.x`，本 crate 暂时复用 legacy WS63/M-core startup 和 layout。
- Hi3322：仅有预研文档，不暴露启动 feature。TES/TEE reset、CLIC、内存分区和镜像格式
  都需要独立 adapter。

## Linker contract

`build.rs` 向下游二进制导出 `hisi-riscv-link.x`，按顺序 `INCLUDE memory.x`、
`layout.ld`、`device.x`、`riscv-rt-symbols.x`，WS63 `boot-header` feature 额外
`INCLUDE boot-header.x`。其中 `device.x` 来自当前 PAC 的 `rt` feature；旧的
`ws63-link.x` 仍生成，但只是兼容别名。

完整架构与评审集中维护在父仓 mdBook：

- `docs/src/explanation/components/05-hisi-riscv-rt.md`
- `docs/src/explanation/components/hi3322-runtime-porting.md`
- `docs/adr/0001-runtime-adapter-seams.md`
