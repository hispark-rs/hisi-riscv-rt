//! # hisi-riscv-rt
//!
//! Runtime entry support for HiSilicon RISC-V firmware.
//!
//! The public crate interface is intentionally small: it re-exports the
//! `riscv-rt` entry attributes, the selected chip PAC's interrupt enum, and the
//! single-hart critical-section implementation configured through the `riscv`
//! crate. Chip-specific reset code, linker fragments, interrupt symbols, and
//! image headers live behind startup adapters.
//!
//! Current adapters:
//! - `chip-ws63`: WS63 startup, linker layout, interrupt `device.x`, and optional
//!   link-time boot header.
//! - `chip-bs21`: BS2X compatibility path. BS20/BS21 examples supply their own
//!   `memory.x` while this crate provides the shared legacy layout/startup and
//!   `bs2x-pac/rt` provides `device.x`.
//!
//! Downstream binaries should link with `-Thisi-riscv-link.x`. The old
//! `-Tws63-link.x` name remains as a temporary compatibility alias.

#![no_std]

#[cfg(all(feature = "boot-header", not(feature = "chip-ws63")))]
compile_error!("hisi-riscv-rt `boot-header` is WS63-only; enable `chip-ws63`");

#[cfg(all(feature = "riscv-rt-start-experiment", not(feature = "chip-ws63")))]
compile_error!("hisi-riscv-rt `riscv-rt-start-experiment` is currently WS63-only");

#[cfg(feature = "chip-ws63")]
core::arch::global_asm!(concat!(
    ".set __hisi_chip_ws63, 1\n",
    include_str!("../asm/ws63/startup.S")
));

#[cfg(feature = "chip-bs21")]
core::arch::global_asm!(concat!(
    ".set __hisi_chip_bs2x, 1\n",
    include_str!("../asm/ws63/startup.S")
));

pub mod rt_core;

pub(crate) mod chips;

#[cfg(feature = "boot-header")]
pub mod boot_header;

#[cfg(feature = "chip-bs21")]
pub use bs2x_pac::interrupt;
#[cfg(feature = "chip-ws63")]
pub use ws63_pac::interrupt;

pub use rt_core::{entry, pre_init};

/// Prelude: commonly used runtime types.
pub mod prelude {
    pub use crate::{entry, pre_init};
    #[cfg(feature = "chip-bs21")]
    pub use bs2x_pac::interrupt::ExternalInterrupt as Interrupt;
    #[cfg(feature = "chip-ws63")]
    pub use ws63_pac::interrupt::ExternalInterrupt as Interrupt;
}
