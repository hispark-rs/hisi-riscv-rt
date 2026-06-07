//! # ws63-rt — Runtime for HiSilicon WS63 (RISC-V RV32IMFC_Zicsr)
//!
//! Provides:
//! - Assembly startup (reset vector, trap vector, interrupt dispatchers)
//! - BSS zeroing and data copy from flash to RAM
//! - Physical Memory Protection (PMP) configuration
//! - Custom interrupt controller (SYS_CTL1) support
//! - Exception handlers with debug output
//! - Stack setup (user, IRQ, exception, NMI stacks)
//!
//! ## Usage
//!
//! ```ignore
//! #![no_std]
//! #![no_main]
//!
//! use ws63_rt::entry;
//!
//! #[entry]
//! fn main() -> ! {
//!     loop { /* your code */ }
//! }
//! ```
//!
//! ## Memory Layout
//!
//! | Region | Start | Size | Purpose |
//! |--------|-------|------|---------|
//! | BOOTROM | 0x100000 | 36K | Mask ROM boot |
//! | ROM | 0x109000 | 268K | Application ROM (patch table, ROM-ram-cb) |
//! | ITCM | 0x14C000 | 16K-64K | Instruction TCM |
//! | DTCM | 0x180000 | 16K-64K | Data TCM |
//! | PROGRAM | 0x230300 | ~2MB | Application code in flash |
//! | SRAM | 0xA00000 | 512K-576K | Main system RAM |
//! | FLASH | 0x200000 | 8MB | External SPI NOR flash |

#![no_std]

// Include assembly startup code via global_asm!
core::arch::global_asm!(include_str!("../asm/startup.S"));

pub mod startup;

#[cfg(feature = "chip-bs21")]
pub use bs21_pac::interrupt;
/// Re-export the active PAC's interrupt types for user convenience.
#[cfg(feature = "chip-ws63")]
pub use ws63_pac::interrupt;

/// Entry point attribute.
///
/// Place on the user's `fn main() -> !` to mark it as the program entry.
/// The function will be called after runtime initialization completes.
///
/// ```ignore
/// #[ws63_rt::entry]
/// fn main() -> ! {
///     loop {}
/// }
/// ```
pub use riscv_rt::entry;

/// Prelude: commonly used runtime types.
pub mod prelude {
    pub use crate::entry;
    #[cfg(feature = "chip-bs21")]
    pub use bs21_pac::interrupt::ExternalInterrupt as Interrupt;
    #[cfg(feature = "chip-ws63")]
    pub use ws63_pac::interrupt::ExternalInterrupt as Interrupt;
}
