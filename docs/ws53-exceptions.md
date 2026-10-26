# WS53 同步异常与可覆盖默认符号

`chip-ws53,unstable` 使用独立的同步异常入口；WS63/BS2X 默认汇编路径保持原样。
例外仍是早期 Flash 初始化：在应用 RAM/栈就绪前继续使用既有无栈停止入口。
同步异常不能被当作硬件 NMI 投递、坏栈或原子断电恢复的证明。

## 类型化处理函数

```rust,ignore
#[unsafe(no_mangle)]
unsafe extern "C" fn WS53_EXCEPTION(ctx: &mut hisi_riscv_rt::ExceptionContext) {
    // 检查 cause / PC / mtval 并真正解决异常。
    // 仅在已知有效的继续点使用 unsafe set_program_counter。
}
```

288字节帧包含全部整数寄存器、post-trap mstatus、mepc/mcause/mtval、旧mscratch、
fcsr与全部32个浮点寄存器。字段私有；数值观察不授予代码/内存所有权。
`set_program_counter` 为unsafe：必须建立有效映射、指令边界和正确Rust/ABI继续状态。
不能对未知的变长指令盲目加4；不解决来源便返回通常会再次触发异常。

进入时必须仍有有效、可写且能容纳288字节帧的中断前栈。处理函数在16字节对齐的
专用异常栈运行；异常栈中的嵌套同步异常继续向低地址生长，不重置到栈顶覆盖外层
局部变量/返回地址。处理函数负责预算；坏栈、保存帧期间再次出错及无界递归未恢复。
处理期间普通IRQ保持屏蔽；不能获取被中断代码持有的锁、改变mscratch或让帧引用逃逸。

入口不借用mscratch作帧指针，因它可能正属于被中断的IRQ。返回恢复旧mscratch和
浮点状态，最后恢复FS，再由MRET消费MPIE恢复先前中断使能。mstatus观察的是硬件
post-trap状态，不能直接称为中断前状态；FS为Off/Clean也不丢弃浮点位模式。

## 原有零参数处理函数

不提供WS53_EXCEPTION时，默认Rust分发器调用原有零参数`extern "C" fn do_*()`，
例如`do_ecall_m`、`do_insn_illegal`和`default_exc_handler`。M-mode ECALL固定为32位，
默认分发器保留其PC自动加4的原约定；类型化覆盖则自行决定继续点。

这些默认名称通过WS53专用`exceptions.x`中的PROVIDE绑定，不在global_asm中定义
同名weak函数，因此Rust强定义可在release/LTO中覆盖。未覆盖时最终进入
`__ws53_default_exc_halt`，不静默跳过故障。不向零参数hook提供未文档化的帧指针。

`examples/ws53/exception_context`在模型中执行真实16/32位非法指令、ECALL及同步
嵌套，并另测在TIMER0 IRQ中发生同步异常后恢复IRQ/主程序的路径。
这不是软件改写mcause伪造的异常进入；仍须另行完成实板RAM/Flash及NMI相关验收。
