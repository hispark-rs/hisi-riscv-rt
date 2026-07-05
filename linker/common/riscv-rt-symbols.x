/* riscv-rt v0.14 compatibility symbols for hisi-riscv-rt.
   Loaded LAST. Uses direct assignment (=) not PROVIDE because
   riscv-rt's rlib already references these as weak extern. */

/* Stack symbols */
_stack_start = DEFINED(__stack_top__) ? __stack_top__ : ORIGIN(SRAM) + LENGTH(SRAM);
_max_hart_id = 0;
_hart_stack_size = DEFINED(__stack_size) ? __stack_size : 0x2000;

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
