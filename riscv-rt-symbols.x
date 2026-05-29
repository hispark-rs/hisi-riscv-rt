/* riscv-rt v0.14 compatibility symbols for ws63-rt.
   Loaded LAST. Uses direct assignment (=) not PROVIDE because
   riscv-rt's rlib already references these as weak extern. */

/* Stack symbols */
_stack_start = ORIGIN(SRAM) + LENGTH(SRAM);
_max_hart_id = 0;
_hart_stack_size = DEFINED(__stack_size) ? __stack_size : 0x2000;

/* Data/bss symbols */
__sidata = LOADADDR(.data);
__sdata   = ADDR(.data);
__edata   = ADDR(.data) + SIZEOF(.data);
__sbss    = ADDR(.bss);
__ebss    = ADDR(.bss) + SIZEOF(.bss);

/* Exception handler symbols — exported by startup.S */
SupervisorSoft = default_handler;
MachineSoft = default_handler;
SupervisorTimer = default_handler;
MachineTimer = default_handler;
SupervisorExternal = default_handler;
MachineExternal = default_handler;
InstructionMisaligned = default_handler;
InstructionFault = default_handler;
IllegalInstruction = default_handler;
Breakpoint = default_handler;
LoadMisaligned = default_handler;
LoadFault = default_handler;
StoreMisaligned = default_handler;
StoreFault = default_handler;
UserEnvCall = default_handler;
SupervisorEnvCall = default_handler;
MachineEnvCall = default_handler;
InstructionPageFault = default_handler;
LoadPageFault = default_handler;
StorePageFault = default_handler;
