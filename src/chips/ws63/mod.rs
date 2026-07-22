//! WS63 startup adapter.
//!
//! # Startup paths
//!
//! Default path (`chip-ws63` without `riscv-rt-start-experiment`):
//!   asm/ws63/startup.S → runtime_init() (Rust) → main()
//!
//! Experimental path (`chip-ws63` + `riscv-rt-start-experiment`):
//!   riscv-rt _start → __pre_init (stack canary) → .data/.bss/FPU →
//!   _setup_interrupts → runtime_init_riscvrt (ROM/TCM/SRAM reloc, MIE) →
//!   mtvec set → j main
//!
//! # WS63 memory map
//!
//! | Region | Start | Size | Purpose |
//! |---|---|---|---|
//! | BOOTROM | `0x100000` | 36 KiB | Mask ROM boot |
//! | ROM | `0x109000` | 268 KiB | Application ROM (SFC, pinmux, WDT, timer, TCXO, BT, WiFi) |
//! | ITCM | `0x14C000` | 16–64 KiB | Instruction TCM (patch tables, ROM veneers, hot code) |
//! | DTCM | `0x180000` | 16–64 KiB | Data TCM (ROM data, TCM data/BSS) |
//! | FLASH | `0x200000` | 8 MiB | External SPI NOR flash (XIP) |
//! | PROGRAM | `0x230300` | ~2.75 MiB | Application code in flash |
//! | SRAM | `0xA00000` | 512–576 KiB | Main system RAM (code, data, stacks, heap) |
//!
//! The ITCM contains:
//! - `.patch` — ROM function patch redirection table
//! - `.rom_ram_cb` — ROM→RAM callback veneers
//! - `.text_tcm` / `.rodata.tcm` — user hot code/data
//!
//! The DTCM contains:
//! - `.rom_data` / `.rom_bss` — ROM runtime state
//! - `.data_tcm` / `.bss_tcm` — user hot data
//!
//! # WS63 interrupt map
//!
//! | IRQ | Name | Tier | Mechanism |
//! |---|---|---|---|
//! | 26 | TIMER_INT0 | MIE | Standard `mie` bit 26 |
//! | 27 | TIMER_INT1 | MIE | Standard `mie` bit 27 |
//! | 28 | TIMER_INT2 | MIE | Standard `mie` bit 28 |
//! | 29 | RTC_IRQ | MIE | Standard `mie` bit 29 |
//! | 30 | (gap) | — | — |
//! | 31 | I2C0_INT | MIE | Standard `mie` bit 31 |
//! | 32 | I2C1_INT | LOCAL | Custom `LOCIEN0` |
//! | 33 | GPIO_INT0 | LOCAL | Custom `LOCIEN0` |
//! | 34 | GPIO_INT1 | LOCAL | Custom `LOCIEN0` |
//! | 35 | GPIO_INT2 | LOCAL | Custom `LOCIEN0` |
//! | 36 | SOFT_INT0 | LOCAL | Custom `LOCIEN0` |
//! | 37 | SOFT_INT1 | LOCAL | Custom `LOCIEN0` |
//! | 38 | SOFT_INT2 | LOCAL | Custom `LOCIEN0` |
//! | 39 | SOFT_INT3 | LOCAL | Custom `LOCIEN0` |
//! | 40 | COEX_WL_INT | LOCAL | Custom `LOCIEN0` |
//! | 41 | COEX_BT_INT | LOCAL | Custom `LOCIEN0` |
//! | 42-91 | … | LOCAL | Custom `LOCIEN0-2` |
//!
//! MIE interrupts (26–31) are gated by the standard RISC-V `mie` CSR.
//! Local interrupts (32+) are gated by HiSilicon custom `LOCIEN0-2` CSRs
//! (`0xBE0-0xBE2`) with priority fields in `LOCIPRI0-15` (`0xBC0-0xBCF`).
//!
//! # Feature flags
//!
//! | Feature | Effect |
//! |---|---|
//! | `boot-header` | Embed 0x300-byte HiSilicon image header at `0x230000`; run `hisi-fwpkg patch-hash` post-link to fill the body SHA-256 |
//! | `ws63-bgle-32k` | Use 32 KiB BGLE exchange memory (RAM9); required for Wi-Fi/BLE combo images built from `ws63-liteos-app` blob |
//! | `startup-uart-trace` | Emit 4-character markers (e.g. `RT2!`, `RD0!`) on UART0 during startup |
//!
//! # `runtime_init` sequence
//!
//! The default startup adapter (`asm/ws63/startup.S`) calls `runtime_init()`
//! (in [`startup`]) before jumping to the user's `#[entry] fn main()`.
//! The sequence is:
//!
//! 1. `__hisi_ws63_shared_ram_init()` — configure ITCM/DTCM bank assignment
//! 2. `__hisi_ws63_cache_init()` — invalidate and enable L1 caches
//! 3. `relocate_data()` — copy initialized sections from flash to
//!    ITCM/DTCM/SRAM. Regions: ROM patch, ROM data, WiFi ROM data,
//!    TCM text, TCM data, SRAM text, `.data`.
//! 4. `zero_bss()` — clear ROM BSS, TCM BSS, and SRAM BSS
//! 5. `__hisi_ws63_rom_patch_enable()` — enable the ROM patch controller
//!    (only if the patch table in ITCM is non-empty)
//! 6. Re-enable machine interrupts (`csrs mie, 0x888` — TIMER0-2, RTC,
//!    I2C0, I2C1)
//! 7. `call main()`

mod cache;
#[cfg(feature = "chip-ws63")]
mod memory;
#[cfg(feature = "chip-ws63")]
mod rom_patch;

#[cfg(not(feature = "riscv-rt-start-experiment"))]
mod startup;
#[cfg(feature = "riscv-rt-start-experiment")]
mod startup_riscvrt;
