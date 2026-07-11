//! WS63 startup adapter.
//!
//! Default path (`chip-ws63` without `riscv-rt-start-experiment`):
//!   asm/ws63/startup.S → runtime_init() (Rust) → main()
//!
//! Experimental path (`chip-ws63` + `riscv-rt-start-experiment`):
//!   riscv-rt _start → __pre_init (stack canary) → .data/.bss/FPU →
//!   _setup_interrupts → runtime_init_riscvrt (ROM/TCM/SRAM reloc, MIE) →
//!   mtvec set → j main

mod cache;
mod memory;
mod rom_patch;

#[cfg(not(feature = "riscv-rt-start-experiment"))]
mod startup;
#[cfg(feature = "riscv-rt-start-experiment")]
mod startup_riscvrt;
