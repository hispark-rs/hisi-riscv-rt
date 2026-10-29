# WS53 指令缓存实验接口

`chip-ws53,unstable` 提供 `hisi_riscv_rt::ws53_cache`。默认启动不调用此接口，
不改变已经实板验证的 Flash/RAM 启动行为。此处只实现指令缓存配置；数据缓存、
PMP/MEMATTR、DMA 一致性、其他主设备交接和维护完成协议仍未实现。

## 来源和配置

来源是 WS53 SDK `163d9150ab94a02d09a05f623351f9facee3025e` 的
`Huawei_LiteOS/arch/riscv/include/arch/cache.h` 和
`ws53_liteos_app/libriscv.a` 中的 `cache.c.obj`。实现代码来自预编译库，
不能把头文件注释当成已审查的 C 实现或芯片复位值。

`InstructionSize` 只接受实际库允许的 4/8/16/32 KiB。头文件中的 64 KiB
会被该库拒绝，不对外提供。`InstructionConfig::new(size, lines)` 的 `lines`
为 1–8；`sdk_application()` 对应应用 `main.c` 的 32 KiB、4 行预取配置。

操作顺序为 SDK 指令部分的 `ICMAINT=4`、`fence iorw,iorw`、
`ICCTL=size|1`、`APREFI=((lines-1)<<1)|1`，再增加 `fence.i` 和数值读回。
增加的指令同步/读回是本接口的检查，并非 SDK 库中存在的完成状态轮询。
不读取只写维护命令，不添加未经证实的 busy 位或等待逻辑。

## 调用边界

`unsafe configure_instruction_cache` 必须由启动资源所有者显式调用。完整调用链、
常量和异常路径须位于有效且独立的 RAM；仅把外层函数放到 RAM 并不足够。
调用期间普通中断关闭，且不能有 NMI、调试器或其他所有者修改缓存配置。
调用方还须建立有效映射、物理尺寸、指令维护/完成语义，排除 Flash 写入、DMA
和控制核等指令写入者，并处理必要的数据到指令同步。函数不建立这些前提。

开启普通中断、已开启指令缓存或读到未知 control/prefetch 位时，操作在写入前拒绝。
初始预取值的允许掩码来自 SDK 使用范围，不宣称是完整硬件读写掩码。
若写入后的数值读回失败，可能已经改变硬件状态；没有自动回滚，调用方必须独立恢复。
即使成功，返回的 `InstructionObservation` 也只是数值，**不是维护完成、无脏行、
DMA coherent 缓冲区或总线排空的能力凭证**。

Flash 默认布局的代码仍在 XIP，不能直接调用本接口。后续 Flash 实验必须先实现并
检查完整的 RAM 调用闭包；当前不自动开启指令缓存，也不启用数据缓存。

## 离线检查

在父工程目录运行，沿用已固定的 Rust 工具链和锁文件：

```bash
rustc +nightly-2026-07-09 --edition=2024 --test --target x86_64-unknown-linux-gnu \
  crates/hisi-riscv-rt/src/chips/ws53/cache.rs -o /tmp/ws53-icache-tests
/tmp/ws53-icache-tests
cargo +nightly-2026-07-09 build -p hisi-riscv-rt --lib --locked --offline \
  --no-default-features --features chip-ws53,unstable \
  --target riscv32imfc-unknown-none-elf -Zbuild-std=core,alloc \
  --target-dir target/ws53-icache-audit
uv run --script crates/hisi-riscv-rt/scripts/check-ws53-icache.py \
  --sdk /path/to/fbb_ws53 \
  --runtime-archive target/ws53-icache-audit/riscv32imfc-unknown-none-elf/debug/libhisi_riscv_rt.rlib \
  --output target/ws53-icache-audit/report.json
uv run --script crates/hisi-riscv-rt/scripts/test-ws53-icache-audit.py \
  --runtime-archive target/ws53-icache-audit/riscv32imfc-unknown-none-elf/debug/libhisi_riscv_rt.rlib \
  --output target/ws53-icache-audit/refusals.json
```

7 项主机测试覆盖 32 种合法配置、非法配置、前置拒绝、写入顺序和部分写入后的
错误行为。独立脚本固定 SDK 提交、库及对象校验值，用有限 RV32IC 解释器检查
两个函数各 260 个参数及一次整体失效操作，保留 4 项非法代码拒绝。
只允许固定的 4 个同节局部分支重定位；未知指令、外部调用或变化的 SDK 被拒绝。
解释器不执行本机厂商代码，不访问设备，不模拟缓存硬件。
编译产物审计另有 1 个正例和 6 个拒绝回归：错误 CSR、缺少屏障、未知 CSR 操作、
长指令截断、缺少目标函数及重复目标函数均不能通过。

脚本还检查实际 Rust rlib 中 `configure<Cpu>` 的 CSR/屏障线性序列，确保没有
意外的数据缓存/PMP/MEMATTR 操作。它不独立证明所有分支和指令数值，也不能从
手工提供的 rlib 证明其构建来源；保留构建命令、日志、源码和产物校验值才能追溯。

## 尚未验收

本接口没有实板启用记录；默认和历史 QEMU 状态模型仍拒绝维护、预取及缓存启用，
不会因为读零或忽略写入而判为通过。独立 QEMU 分支提供显式 instruction-experiment，
以合成初态和已公开的几何/预取假设执行指令可见性测试；父工程的
`examples/ws53/cache_contract` 在完整 RAM 闭包中调用此接口，准入、复位和结果另行记录。
这些模型结果不能替代实板 RAM、Flash 启动或冷启动验收。约 1.58 ms 的既有调度延后
尚未归因，不把该接口视为修复。
