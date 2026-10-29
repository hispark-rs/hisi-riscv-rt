# WS53 应用核 RAM 函数（实验）

`ws53-ram-functions` 同时要求 `chip-ws53,unstable,ws53-flash-start`。
它补齐 Flash 镜像中的代码/常量向应用 ITCM 复制，不接管 SFC，不允许据此直接擦写
正在执行的 Flash。未启用时 `.ws53.ramtext*` / `.ws53.ramrodata*` 的存活输入段
会在链接时拒绝，避免悄悄变成没有初始化的孤立段。

当前只适用于已有实验 FlashBoot / MCU_MODE_1 交接。按固定 SDK
`163d9150ab94a02d09a05f623351f9facee3025e` 的 `acore_memory_config.h` 及
`dyn_mem.c`，在已有应用 ITCM 中使用 `[0x28000, 0x2f000)`，最大28 KiB；
`[0x2f000, 0x30000)` 继续独占为启动栈。DTCM、控制核、共享缓冲区分配不改变。
运行时仍仅接受控制核保持复位的既有交接，不能与厂商控制核并行运行声明混用。

## 放置及构建

```rust,ignore
#[inline(never)]
#[unsafe(link_section = ".ws53.ramtext.my_operation")]
unsafe extern "C" fn operation(arg: u32) -> u32 {
    // 所有需要在 Flash 不可访问期间执行的子调用也必须显式放在 RAM。
    arg.wrapping_add(1)
}

#[used]
#[unsafe(link_section = ".ws53.ramrodata.my_table")]
static TABLE: [u32; 2] = [1, 2];
```

代码和只读常量合入 `.ws53.ramtext`，VMA 在 ITCM，LMA 在应用 Flash 分区中，
位于 `.data` 的 Flash 源字节之前。`runtime_init` 初始化 data/bss 后做逐字节
volatile 复制，然后执行已有 `fence.i`，最后安装正常陷阱向量并进入 main。
复制不依赖 memcpy；未使用未初始化的全局状态。早期失败仍使用 Flash 中的
无栈停止向量。只启用该 feature 但没有注解时不需要额外文件数据。

链接必须保留 `--no-relax`，资格检查还需要 `--emit-relocs` 和未剥离的 ELF。
例如应用 build.rs 输出：

```rust,ignore
println!("cargo:rustc-link-arg=-Thisi-riscv-link.x");
println!("cargo:rustc-link-arg=--emit-relocs");
```

运行离线检查（此独立仓库内）：

```sh
uv run --script scripts/check-ws53-ram-functions.py path/to/application.elf
```

它检查真实 PT_LOAD、Flash LMA、ITCM 边界、代码段只读属性、函数内非 A 指令、
保留的重定位目标以及直接跳转。已解析 AUIPC/JALR 的编码必须与目标重定位相同；
其他间接调用/跳转拒绝。当前合同只接受同一个已审核 RAM 段中的重定位引用，
不默认放行 ROM、其他 RAM 函数、Flash 常量、编译器辅助函数或 vtable。

## 仍需人工及硬件证明的条件

该检查无法证明任意裸数值地址、传入指针、栈溢出、所有间接别名、异常/NMI 路径、
其他总线主机、控制核及缓存维护/排空。注解不是 Rust 安全边界，调用者必须保证
目标内存和数据引用有效。panic、格式化、越界检查、软算术/编译器辅助函数可能
从 RAM 跳回 Flash，必须在最终产物中审核，不能只看源码属性。

默认向量、异常和 NMI 处理仍在 Flash。即使普通 IRQ 已屏蔽，也不能据此宣称
Flash 关闭期间安全；需要另行实现所有可到达路径的 RAM 闭包及 WDT、DMA、
缓存/预取、SFC 时钟/路由、其他 master 的资源交接。`fence.i` 只提供本次指令
同步，不证明厂商缓存维护或 Flash 排空协议。

独立消费者和 QEMU 测试由父工程 `examples/ws53-ram-functions` 及对应脚本管理。
新路径实板、Flash 烧录、冷启动均需独立验收，旧候选18借用停用启动栈的结果
不能转移给此布局。当前 API 继续实验门控。
