/* riscv-rt v0.14 compatibility symbols for hisi-riscv-rt.
   Loaded LAST. Required riscv-rt symbols use direct assignment because its
   rlib already references them as weak extern; optional hooks use PROVIDE. */

/* Stack symbols */
_stack_start = DEFINED(__stack_top__) ? __stack_top__ : ORIGIN(SRAM) + LENGTH(SRAM);
_max_hart_id = 0;
_hart_stack_size = DEFINED(__stack_size) ? __stack_size : 0x2000;

/* Optional deferred scheduling hook. The startup assembly owns the no-op
   implementation under a distinct name so a Rust RTOS can define the public
   symbol without colliding with global_asm during LTO. */
PROVIDE(__hisi_irq_epilogue = __hisi_irq_epilogue_default);

/* Data/bss symbols */
__sidata = LOADADDR(.data);
__sdata   = ADDR(.data);
__edata   = ADDR(.data) + SIZEOF(.data);
__sbss    = ADDR(.bss);
__ebss    = ADDR(.bss) + SIZEOF(.bss);

/* Exception handler symbols — resolved through the public DefaultHandler symbol
   provided by the active device.x / riscv-rt path. Do not point these at the
   WS63-local `default_handler`; release LTO may not materialize that archive
   member before this compatibility fragment is evaluated. */
SupervisorSoft = DefaultHandler;
MachineSoft = DefaultHandler;
SupervisorTimer = DefaultHandler;
MachineTimer = DefaultHandler;
SupervisorExternal = DefaultHandler;
MachineExternal = DefaultHandler;
InstructionMisaligned = DefaultHandler;
InstructionFault = DefaultHandler;
IllegalInstruction = DefaultHandler;
Breakpoint = DefaultHandler;
LoadMisaligned = DefaultHandler;
LoadFault = DefaultHandler;
StoreMisaligned = DefaultHandler;
StoreFault = DefaultHandler;
UserEnvCall = DefaultHandler;
SupervisorEnvCall = DefaultHandler;
MachineEnvCall = DefaultHandler;
InstructionPageFault = DefaultHandler;
LoadPageFault = DefaultHandler;
StorePageFault = DefaultHandler;
